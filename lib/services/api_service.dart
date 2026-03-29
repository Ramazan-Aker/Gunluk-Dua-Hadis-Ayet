import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/daily_item.dart';

/// API Service for fetching Dua, Hadith, and Ayah data
class ApiService {
  // Example: https://api.example.com/v1
  static const String baseUrl = 'https://api.islamic-api.com/v1';

  // Alternative free APIs you can use:
  // - https://api.alquran.cloud/v1 (Quran API)
  // - https://api.hadith.gading.dev (Hadith API - Indonesian)
  // - https://islamic-api-indonesia.vercel.app/api (Islamic API Indonesia)

  static const Duration timeoutDuration = Duration(seconds: 10);

  /// Fetch all items (Dua, Hadith, Ayah) from API
  /// Returns null if API is not available or error occurs
  Future<List<DailyItem>?> fetchAllItems() async {
    try {
      // Since we don't have a specific API endpoint, we'll create a mock structure
      // Replace this with your actual API endpoint
      final uri = Uri.parse('$baseUrl/items');

      final response = await http.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final items = jsonList.map((json) => DailyItem.fromJson(json)).toList();

        return items;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Fetch daily item from API
  /// Some APIs might have a specific endpoint for daily items
  Future<DailyItem?> fetchDailyItem() async {
    try {
      // Replace with your actual daily item endpoint
      final uri = Uri.parse('$baseUrl/daily');

      final response = await http.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return DailyItem.fromJson(jsonData);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Fetch items by type (dua, hadith, ayah)
  Future<List<DailyItem>?> fetchItemsByType(String type) async {
    try {
      final uri = Uri.parse('$baseUrl/items?type=$type');

      final response = await http.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => DailyItem.fromJson(json)).toList();
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Check if API is available
  Future<bool> checkApiAvailability() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
