import 'dart:math' as math;

/// Geohash utilities (compatible with geofire-common query bounds).
class GeohashUtils {
  GeohashUtils._();

  static const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encode [lat], [lng] to geohash with [precision] characters (default 9).
  static String encode(double lat, double lng, {int precision = 9}) {
    var minLat = -90.0;
    var maxLat = 90.0;
    var minLng = -180.0;
    var maxLng = 180.0;
    var hash = StringBuffer();
    var bit = 0;
    var ch = 0;
    var even = true;

    while (hash.length < precision) {
      if (even) {
        final mid = (minLng + maxLng) / 2;
        if (lng >= mid) {
          ch = ch * 2 + 1;
          minLng = mid;
        } else {
          ch = ch * 2;
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (lat >= mid) {
          ch = ch * 2 + 1;
          minLat = mid;
        } else {
          ch = ch * 2;
          maxLat = mid;
        }
      }
      even = !even;
      bit++;
      if (bit == 5) {
        hash.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }
    return hash.toString();
  }

  /// Returns Firestore query bound pairs `[startHash, endHash]`.
  static List<List<String>> queryBounds(
    double lat,
    double lng,
    double radiusInKm,
  ) {
    final radiusM = radiusInKm * 1000;
    final latDelta = radiusM / 110574.0;
    final lngDelta = radiusM / (111320.0 * math.cos(lat * math.pi / 180));

    final corners = [
      [lat + latDelta, lng - lngDelta],
      [lat + latDelta, lng + lngDelta],
      [lat - latDelta, lng - lngDelta],
      [lat - latDelta, lng + lngDelta],
    ];

    final hashes = <String>{};
    for (final corner in corners) {
      hashes.add(encode(corner[0], corner[1], precision: _precision(radiusM)));
    }

    final sorted = hashes.toList()..sort();
    return sorted.map((h) => [h, '$h~']).toList();
  }

  static int _precision(double radiusM) {
    if (radiusM <= 1500) return 6;
    if (radiusM <= 5000) return 5;
    if (radiusM <= 20000) return 4;
    return 3;
  }

  /// Haversine distance in kilometers.
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);
}
