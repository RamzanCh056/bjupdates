import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleConfig {
  static String resolve(String key) {
    final raw = dotenv.env[key];
    if (raw == null) return '';
    return raw.trim().replaceAll(RegExp(r'''^['"]|['"]$'''), '');
  }

  static String get apiKey => resolve('GOOGLE_API_KEY');

  static String get placesApiKey {
    final places = resolve('GOOGLE_PLACE_API_KEY');
    return places.isNotEmpty ? places : apiKey;
  }

  static String get projectId => resolve('GCP_PROJECT_ID');

  static bool get isPlacesConfigured => placesApiKey.isNotEmpty;
}
