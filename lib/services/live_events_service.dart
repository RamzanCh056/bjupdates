import 'dart:convert';
import 'dart:developer';

import 'package:beatjerky/config/google_config.dart';
import 'package:beatjerky/config/tavily_config.dart';
import 'package:beatjerky/models/live_event.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LiveEventsService {
  static const _cacheKey = 'live_events_cache_v7';
  static const _cacheDuration = Duration(minutes: 30);
  static const _userAgent = 'BeatJerky/1.0 (live-events)';

  Future<LiveEventsResult> fetchEvents({bool forceRefresh = false}) async {
    final placesOk = GoogleConfig.isPlacesConfigured;
    final tavilyOk = TavilyConfig.isConfigured;
    log(
      'LiveEventsService: fetch start '
      '(places=$placesOk, tavily=$tavilyOk)',
    );

    if (!placesOk && !tavilyOk) {
      log('LiveEventsService: no API keys configured in dotenv');
      return const LiveEventsResult(state: LiveEventsLoadState.error);
    }

    if (!forceRefresh) {
      final cached = await _loadCache();
      if (cached != null) {
        log('LiveEventsService: returning ${cached.events.length} cached events');
        return cached;
      }
    }

    try {
      final permission = await Geolocator.checkPermission();
      final permissionDenied = permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever;

      final locationResult = permissionDenied
          ? (city: null, lat: null, lng: null)
          : await _resolveLocationQuick();

      log(
        'LiveEventsService: permissionDenied=$permissionDenied '
        'city=${locationResult.city} lat=${locationResult.lat}',
      );

      List<LiveEvent> events = [];

      if (placesOk) {
        events = await _searchGooglePlaces(
          lat: locationResult.lat,
          lng: locationResult.lng,
          city: locationResult.city,
          nearbyOnly: !permissionDenied,
        );
        log('LiveEventsService: Google Places returned ${events.length} events');
      }

      if (events.isEmpty && tavilyOk) {
        final query = locationResult.city != null
            ? 'live music concerts festivals near ${locationResult.city} 2026'
            : 'live music concerts festivals 2026';
        events = await _searchTavily(query);
        log('LiveEventsService: Tavily returned ${events.length} events');
      }

      if (events.isEmpty) {
        log('LiveEventsService: no events found');
        return LiveEventsResult(
          state: permissionDenied
              ? LiveEventsLoadState.locationDenied
              : LiveEventsLoadState.empty,
          cityName: locationResult.city,
        );
      }

      final result = LiveEventsResult(
        state: permissionDenied
            ? LiveEventsLoadState.locationDenied
            : LiveEventsLoadState.loaded,
        events: events,
        cityName: locationResult.city,
        usedFallbackLocation: !permissionDenied && locationResult.city == null,
      );

      await _saveCache(result);
      return result;
    } catch (e, st) {
      log('LiveEventsService.fetchEvents failed: $e', stackTrace: st);
      return const LiveEventsResult(state: LiveEventsLoadState.error);
    }
  }

  Future<LiveEventsResult?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(
        data['cachedAt'] as int? ?? 0,
      );
      if (DateTime.now().difference(cachedAt) > _cacheDuration) return null;

      final eventsJson = data['events'] as List? ?? [];
      final events = eventsJson
          .map((e) => LiveEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (events.isEmpty) return null;

      final stateName = data['state'] as String? ?? 'loaded';
      final state = LiveEventsLoadState.values.firstWhere(
        (s) => s.name == stateName,
        orElse: () => LiveEventsLoadState.loaded,
      );

      return LiveEventsResult(
        state: state,
        events: events,
        cityName: data['cityName'] as String?,
        usedFallbackLocation: data['usedFallbackLocation'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(LiveEventsResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'cachedAt': DateTime.now().millisecondsSinceEpoch,
          'state': result.state.name,
          'cityName': result.cityName,
          'usedFallbackLocation': result.usedFallbackLocation,
          'events': result.events.map((e) => e.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }

  Future<
      ({
        String? city,
        double? lat,
        double? lng,
      })> _resolveLocationQuick() async {
    try {
      return await _resolveLocation().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          log('LiveEventsService: location timed out');
          return (city: null, lat: null, lng: null);
        },
      );
    } catch (e) {
      log('LiveEventsService: location error ($e)');
      return (city: null, lat: null, lng: null);
    }
  }

  Future<
      ({
        String? city,
        double? lat,
        double? lng,
      })> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (city: null, lat: null, lng: null);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        return (city: null, lat: null, lng: null);
      }

      if (permission == LocationPermission.deniedForever) {
        return (city: null, lat: null, lng: null);
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 3),
      );

      final city = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );

      return (
        city: city,
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (e) {
      log('LiveEventsService: Geolocator failed: $e');
      return (city: null, lat: null, lng: null);
    }
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    if (GoogleConfig.isPlacesConfigured) {
      final city = await _reverseGeocodeGoogle(lat, lon);
      if (city != null) return city;
    }
    return _reverseGeocodeNominatim(lat, lon);
  }

  Future<String?> _reverseGeocodeGoogle(double lat, double lon) async {
    try {
      final key = GoogleConfig.placesApiKey;
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lon&key=$key',
      );

      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final results = data['results'] as List? ?? [];
      for (final result in results) {
        final components = (result as Map)['address_components'] as List? ?? [];
        for (final component in components) {
          final types = (component as Map)['types'] as List? ?? [];
          if (types.contains('locality') ||
              types.contains('administrative_area_level_2')) {
            return component['long_name']?.toString();
          }
        }
      }
    } catch (e) {
      log('LiveEventsService: Google geocode failed: $e');
    }
    return null;
  }

  Future<String?> _reverseGeocodeNominatim(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lon&format=json',
      );

      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      if (address == null) return null;

      return (address['city'] ??
              address['town'] ??
              address['village'] ??
              address['municipality'] ??
              address['county'] ??
              address['state'])
          ?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<LiveEvent>> _searchGooglePlaces({
    double? lat,
    double? lng,
    String? city,
    required bool nearbyOnly,
  }) async {
    final key = GoogleConfig.placesApiKey;
    if (key.isEmpty) return [];

    final places = <dynamic>[];
    final seenIds = <String>{};

    void addPlaces(List<dynamic> batch) {
      for (final place in batch) {
        if (!_isMusicEventPlace(place as Map<String, dynamic>)) continue;
        final id = place['place_id']?.toString();
        if (id != null && seenIds.add(id)) {
          places.add(place);
        }
      }
    }

    final queries = nearbyOnly && city != null
        ? [
            'live music concerts festivals $city',
            'upcoming music concerts gigs $city',
            'music festival tickets $city',
          ]
        : [
            'live music concerts festivals',
            'upcoming music concerts gigs',
            'music festival tickets',
          ];

    for (final query in queries) {
      addPlaces(await _googleTextSearch(
        query,
        key,
        lat: nearbyOnly ? lat : null,
        lng: nearbyOnly ? lng : null,
      ));
      if (places.length >= 5) break;
    }

    if (nearbyOnly && places.length < 5 && lat != null && lng != null) {
      addPlaces(await _googleNearbySearch(lat, lng, key));
    }

    return places
        .take(5)
        .map((p) => _mapGooglePlace(p as Map<String, dynamic>, key))
        .whereType<LiveEvent>()
        .toList();
  }

  /// Keep concerts/festivals/live music venues; drop studios, stores, schools.
  bool _isMusicEventPlace(Map<String, dynamic> place) {
    final name = (place['name'] as String?)?.toLowerCase() ?? '';
    final types = (place['types'] as List?)
            ?.map((t) => t.toString().toLowerCase())
            .toList() ??
        [];
    final address =
        ((place['formatted_address'] ?? place['vicinity']) as String?)
                ?.toLowerCase() ??
            '';
    final combined = '$name $address';

    const excludeKeywords = [
      'rehearsal',
      'recording studio',
      'music school',
      'music academy',
      'music store',
      'instrument shop',
      'guitar shop',
      'piano lesson',
      'music lesson',
      'tutor',
      'the floor below',
      'drum room',
      'practice room',
      'rental studio',
    ];
    for (final kw in excludeKeywords) {
      if (combined.contains(kw)) return false;
    }

    const excludeTypes = {
      'school',
      'university',
      'primary_school',
      'secondary_school',
      'store',
      'shopping_mall',
      'home_goods_store',
      'electronics_store',
      'gym',
      'spa',
      'beauty_salon',
      'real_estate_agency',
      'lawyer',
      'doctor',
    };
    if (types.any(excludeTypes.contains)) return false;

    const eventKeywords = [
      'concert',
      'festival',
      'live music',
      'live show',
      'gig',
      'arena',
      'amphitheater',
      'amphitheatre',
      'music hall',
      'opera house',
      'jazz club',
      'rock club',
      'dj night',
      'tour date',
      'performance',
    ];
    if (eventKeywords.any(combined.contains)) return true;

    const venueTypes = {
      'stadium',
      'night_club',
      'performing_arts_theater',
      'movie_theater',
    };
    if (types.any(venueTypes.contains)) {
      const musicHints = [
        'music',
        'live',
        'concert',
        'jazz',
        'rock',
        'club',
        'arena',
        'hall',
        'festival',
        'gig',
      ];
      return musicHints.any(name.contains);
    }

    return false;
  }

  Future<List<dynamic>> _googleNearbySearch(
    double lat,
    double lng,
    String key,
  ) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$lat,$lng&radius=50000'
        '&type=night_club'
        '&keyword=live+music+concert+festival'
        '&key=$key',
      );

      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status']?.toString() ?? '';
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        log('LiveEventsService: Nearby status=$status msg=${data['error_message']}');
        return [];
      }

      return data['results'] as List? ?? [];
    } catch (e) {
      log('LiveEventsService: Nearby search error: $e');
      return [];
    }
  }

  Future<List<dynamic>> _googleTextSearch(
    String query,
    String key, {
    double? lat,
    double? lng,
  }) async {
    try {
      var uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json'
        '?query=${Uri.encodeComponent(query)}&key=$key',
      );

      if (lat != null && lng != null) {
        uri = uri.replace(
          queryParameters: {
            ...uri.queryParameters,
            'location': '$lat,$lng',
            'radius': '50000',
          },
        );
      }

      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        log('LiveEventsService: Text search HTTP ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status']?.toString() ?? '';
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        log('LiveEventsService: Text status=$status msg=${data['error_message']}');
        return [];
      }

      return data['results'] as List? ?? [];
    } catch (e) {
      log('LiveEventsService: Text search error: $e');
      return [];
    }
  }

  LiveEvent? _mapGooglePlace(Map<String, dynamic> place, String key) {
    final name = (place['name'] as String?)?.trim();
    final placeId = (place['place_id'] as String?)?.trim();
    if (name == null || name.isEmpty || placeId == null) return null;

    final address = (place['formatted_address'] as String?)?.trim() ??
        (place['vicinity'] as String?)?.trim() ??
        'Live music & entertainment venue';

    final photos = place['photos'] as List?;
    String? imageUrl;
    if (photos != null && photos.isNotEmpty) {
      final photoRef = (photos.first as Map)['photo_reference']?.toString();
      if (photoRef != null && photoRef.isNotEmpty) {
        imageUrl =
            'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=$key';
      }
    }

    final url =
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(name)}&query_place_id=$placeId';

    return LiveEvent(
      title: name,
      description: _buildEventDescription(place, address),
      url: url,
      imageUrl: imageUrl,
    );
  }

  String _buildEventDescription(Map<String, dynamic> place, String address) {
    final types = (place['types'] as List?)
            ?.map((t) => t.toString().replaceAll('_', ' '))
            .where((t) =>
                t.contains('club') ||
                t.contains('stadium') ||
                t.contains('theater') ||
                t.contains('concert'))
            .toList() ??
        [];

    if (types.isNotEmpty) {
      final label = types.first;
      final shortAddr = address.length > 60
          ? '${address.substring(0, 57)}...'
          : address;
      return '$label · $shortAddr';
    }

    return address.length > 100 ? '${address.substring(0, 97)}...' : address;
  }

  Future<List<LiveEvent>> _searchTavily(String query) async {
    final apiKey = TavilyConfig.resolveApiKey();
    if (apiKey.isEmpty) return [];

    try {
      final response = await http
          .post(
            Uri.parse(TavilyConfig.searchUrl),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': _userAgent,
            },
            body: jsonEncode({
              'query': query,
              'api_key': apiKey,
              'search_depth': 'basic',
              'max_results': 5,
              'include_images': true,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.containsKey('detail')) return [];

      final results = data['results'] as List? ?? [];
      final images = (data['images'] as List?)
              ?.map((e) => e.toString())
              .where((url) => url.isNotEmpty)
              .toList() ??
          [];

      final events = <LiveEvent>[];
      for (var i = 0; i < results.length && i < 8; i++) {
        final item = results[i] as Map<String, dynamic>;
        final title = (item['title'] as String?)?.trim();
        final url = (item['url'] as String?)?.trim();
        if (title == null || title.isEmpty || url == null || url.isEmpty) {
          continue;
        }

        final rawContent = (item['content'] as String?)?.trim() ?? '';
        if (!_isMusicEventText('$title $rawContent')) continue;

        final description = rawContent.length > 100
            ? '${rawContent.substring(0, 97)}...'
            : rawContent;

        String? imageUrl;
        if (i < images.length) {
          imageUrl = images[i];
        } else if (images.isNotEmpty) {
          imageUrl = images[i % images.length];
        }

        events.add(
          LiveEvent(
            title: title,
            description: description.isNotEmpty
                ? description
                : 'Discover live music and entertainment.',
            url: url,
            imageUrl: imageUrl,
          ),
        );

        if (events.length >= 5) break;
      }

      return events;
    } catch (e) {
      log('LiveEventsService: Tavily failed: $e');
      return [];
    }
  }

  bool _isMusicEventText(String text) {
    final lower = text.toLowerCase();
    const keywords = [
      'concert',
      'festival',
      'live music',
      'gig',
      'tour',
      'dj',
      'band',
      'symphony',
      'opera',
      'jazz',
      'rock',
      'pop',
      'hip hop',
      'edm',
      'arena',
      'amphitheater',
      'amphitheatre',
      'music hall',
      'nightclub',
      'night club',
    ];
    return keywords.any(lower.contains);
  }
}
