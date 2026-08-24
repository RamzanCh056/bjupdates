import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', jsonEncode(userData));
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('userData');
    return data != null ? jsonDecode(data) : null;
  }

  static Future<void> saveUserRewards(Map<String, dynamic> rewards) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRewards', jsonEncode(rewards));
  }

  static Future<Map<String, dynamic>?> getUserRewards() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('userRewards');
    return data != null ? jsonDecode(data) : null;
  }

  static Future<void> saveLeaderboard(List<Map<String, dynamic>> leaderboard) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('leaderboard', jsonEncode(leaderboard));
  }

  static Future<List<Map<String, dynamic>>?> getLeaderboard() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('leaderboard');
    if (data == null) return null;
    final decoded = jsonDecode(data) as List;
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    await prefs.remove('userRewards');
    await prefs.remove('leaderboard');
  }
}
