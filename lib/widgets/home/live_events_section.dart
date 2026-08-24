import 'dart:developer';

import 'package:beatjerky/config/google_config.dart';
import 'package:beatjerky/models/live_event.dart';
import 'package:beatjerky/services/live_events_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

const _cardWidth = 200.0;
const _cardHeight = 220.0;

class LiveEventsSection extends StatefulWidget {
  const LiveEventsSection({super.key});

  @override
  State<LiveEventsSection> createState() => _LiveEventsSectionState();
}

class _LiveEventsSectionState extends State<LiveEventsSection> {
  final LiveEventsService _service = LiveEventsService();
  LiveEventsResult? _result;
  bool _loading = true;
  LocationPermission _permission = LocationPermission.denied;

  @override
  void initState() {
    super.initState();
    _refreshPermission();
    _loadEvents();
  }

  Future<void> _refreshPermission() async {
    final permission = await Geolocator.checkPermission();
    if (mounted) setState(() => _permission = permission);
  }

  bool get _hasLocationAccess =>
      _permission == LocationPermission.whileInUse ||
      _permission == LocationPermission.always;

  Future<void> _loadEvents({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);

    final result = await _service.fetchEvents(forceRefresh: forceRefresh);

    log(
      'LiveEventsSection: loaded state=${result.state.name} '
      'events=${result.events.length}',
    );

    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  Future<void> _requestLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }
    await _refreshPermission();
    await _loadEvents(forceRefresh: true);
  }

  String get _sectionTitle {
    if (_hasLocationAccess) {
      final city = _result?.cityName;
      if (city != null && city.isNotEmpty) {
        return 'Live Events Near You';
      }
    }
    return 'Live Events';
  }

  Widget _buildHeaderTrailing(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    if (!_hasLocationAccess) {
      return TextButton(
        onPressed: _requestLocation,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: const Color(0xFFBB86FC).withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Enable location',
          style: TextStyle(
            color: Color(0xFFBB86FC),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final city = _result?.cityName?.trim();
    final label = (city != null && city.isNotEmpty) ? 'Near $city' : 'Nearby';

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.42,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_rounded,
            size: 14,
            color: const Color(0xFFBB86FC).withValues(alpha: 0.9),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading &&
        _result != null &&
        _result!.state == LiveEventsLoadState.empty) {
      return const SizedBox.shrink();
    }

    if (!_loading &&
        (_result == null || _result!.state == LiveEventsLoadState.error)) {
      return _buildErrorState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _loading ? 'Live Events' : _sectionTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              _buildHeaderTrailing(context),
            ],
          ),
        ),
        if (_loading)
          _buildSkeletonRow()
        else
          SizedBox(
            height: _cardHeight + 4,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              itemCount: _result!.events.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _LiveEventCard(event: _result!.events[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Events Near You',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            GoogleConfig.isPlacesConfigured
                ? 'Could not load events. Tap to retry.'
                : 'API keys missing. Add GOOGLE_PLACE_API_KEY to .env and restart.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => _loadEvents(forceRefresh: true),
            child: const Text(
              'Retry',
              style: TextStyle(color: Color(0xFFBB86FC)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonRow() {
    return SizedBox(
      height: _cardHeight + 4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: Colors.grey[850]!,
          highlightColor: Colors.grey[700]!,
          child: Container(
            width: _cardWidth,
            height: _cardHeight,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveEventCard extends StatelessWidget {
  final LiveEvent event;

  const _LiveEventCard({required this.event});

  Future<void> _openEvent() async {
    final uri = Uri.tryParse(event.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openEvent,
      child: SizedBox(
        width: _cardWidth,
        height: _cardHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildBackground(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Text(
                        'Music Event',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _openEvent,
                      child: Text(
                        'View event',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    final imageUrl = event.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholderBackground(),
        errorWidget: (_, __, ___) => _placeholderBackground(),
      );
    }
    return _placeholderBackground();
  }

  Widget _placeholderBackground() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1033),
            const Color(0xFF0D1117),
            const Color(0xFF2D1B4E).withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 40,
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}
