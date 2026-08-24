import 'package:flutter_dotenv/flutter_dotenv.dart';

class TavilyConfig {
  static const String searchUrl = 'https://api.tavily.com/search';

  static String resolveApiKey() {
    final raw = dotenv.env['TAVILY_API_KEY'];
    if (raw == null) return '';
    return raw.trim().replaceAll(RegExp(r'''^['"]|['"]$'''), '');
  }

  static bool get isConfigured => resolveApiKey().isNotEmpty;
}
