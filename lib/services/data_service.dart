import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_item.dart';
import 'api_service.dart';
import 'quran_api_service.dart';

/// Service class to handle data loading and daily item selection
/// Now supports both API and local fallback
class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  final QuranApiService _quranApiService = QuranApiService();
  
  List<DailyItem> _items = [];
  DailyItem? _currentItem;
  final Random _random = Random();
  
  // Flag to determine if we should use Quran API for ayahs
  bool _useQuranApi = true;

  // SharedPreferences keys
  static const String _keyLastDate = 'last_date';
  static const String _keyLastItemIndex = 'last_item_index';
  static const String _keyShownItems = 'shown_items';
  static const String _keyCachedItems = 'cached_items';
  static const String _keyCacheDate = 'cache_date';
  static const String _keyUseApi = 'use_api';

  /// Load data from API with local JSON fallback
  /// Note: For now, we load local data. Quran API will be used for random ayahs.
  Future<void> loadData({bool forceRefresh = false}) async {
    // Try to load from API first
    if (!forceRefresh) {
      // Check if we have cached data that's still fresh (less than 24 hours old)
      final cachedItems = await _loadCachedItems();
      if (cachedItems != null && cachedItems.isNotEmpty) {
        _items = cachedItems;
        print('✅ Loaded ${_items.length} items from cache');
        return;
      }
    }

    // Skip custom API for now - we'll use Quran API for ayahs directly
    // Custom API can be enabled later when you have your own API
    // try {
    //   final apiItems = await _apiService.fetchAllItems();
    //   if (apiItems != null && apiItems.isNotEmpty) {
    //     _items = apiItems;
    //     await _saveCachedItems(apiItems);
    //     await SharedPreferences.getInstance().then((prefs) {
    //       prefs.setBool(_keyUseApi, true);
    //     });
    //     print('✅ Loaded ${_items.length} items from API');
    //     return;
    //   }
    // } catch (e) {
    //   print('⚠️ Custom API fetch failed: $e, falling back to local data');
    // }

    // Fallback to local JSON file (contains hadith and dua)
    try {
      final String jsonString = await rootBundle.loadString('assets/data.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      // Filter out ayahs if we're using Quran API
      if (_useQuranApi) {
        _items = jsonList
            .map((json) => DailyItem.fromJson(json))
            .where((item) => item.type != 'ayah') // Remove local ayahs
            .toList();
        print('✅ Loaded ${_items.length} items from local JSON (hadith & dua only, ayahs from Quran API)');
      } else {
        _items = jsonList.map((json) => DailyItem.fromJson(json)).toList();
        print('✅ Loaded ${_items.length} items from local JSON (all types)');
      }
      
      await SharedPreferences.getInstance().then((prefs) {
        prefs.setBool(_keyUseApi, false);
      });
    } catch (e) {
      print('❌ Error loading data from local JSON: $e');
      _items = [];
    }
  }

  /// Load cached items from SharedPreferences
  Future<List<DailyItem>?> _loadCachedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedJson = prefs.getString(_keyCachedItems);
      final String? cacheDate = prefs.getString(_keyCacheDate);
      
      if (cachedJson != null && cacheDate != null) {
        // Check if cache is less than 24 hours old
        final DateTime cacheTime = DateTime.parse(cacheDate);
        final DateTime now = DateTime.now();
        final Duration difference = now.difference(cacheTime);
        
        if (difference.inHours < 24) {
          final List<dynamic> jsonList = json.decode(cachedJson);
          return jsonList.map((json) => DailyItem.fromJson(json)).toList();
        } else {
          // Cache expired, remove it
          await prefs.remove(_keyCachedItems);
          await prefs.remove(_keyCacheDate);
        }
      }
    } catch (e) {
      print('⚠️ Error loading cached items: $e');
    }
    return null;
  }

  /// Get the daily item (changes once per day)
  /// Randomly selects between dua, hadith, and ayah
  Future<DailyItem?> getDailyItem({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().split('T')[0];
    final String? lastDate = prefs.getString(_keyLastDate);
    final String? lastType = prefs.getString('last_type');

    // Check if it's a new day
    if (lastDate != today || forceRefresh) {
      // New day - select a random type (dua, hadith, or ayah)
      final types = ['dua', 'hadith', 'ayah'];
      final selectedType = types[_random.nextInt(types.length)];
      
      // If ayah and Quran API enabled, fetch from API
      if (selectedType == 'ayah' && _useQuranApi) {
        try {
          print('🕌 Fetching daily ayah from Quran API...');
          final ayah = await _quranApiService.fetchRandomAyah();
          if (ayah != null) {
            _currentItem = ayah;
            await prefs.setString(_keyLastDate, today);
            await prefs.setString('last_type', 'ayah');
            await prefs.setString('last_item_api', 'true');
            print('✅ Daily ayah fetched from Quran API: ${ayah.source}');
            return ayah;
          } else {
            print('⚠️ Quran API returned null, falling back to local items');
          }
        } catch (e) {
          print('❌ Failed to fetch ayah from Quran API: $e, falling back to local');
        }
      }

      // Load local items if empty
      if (_items.isEmpty) {
        await loadData(forceRefresh: forceRefresh);
      }

      if (_items.isEmpty) {
        return null;
      }

      // Filter by selected type
      final filteredItems = _items.where((item) => item.type == selectedType).toList();
      final itemsToUse = filteredItems.isNotEmpty ? filteredItems : _items;
      
      final int newIndex = _random.nextInt(itemsToUse.length);
      _currentItem = itemsToUse[newIndex];
      
      // Save to preferences
      await prefs.setString(_keyLastDate, today);
      await prefs.setString('last_type', selectedType);
      await prefs.setInt(_keyLastItemIndex, newIndex);
      await prefs.setStringList(_keyShownItems, [newIndex.toString()]);
      await prefs.setString('last_item_api', 'false');
      
      print('📅 New day! Showing ${selectedType} #$newIndex');
    } else {
      // Same day - load saved item
      final String? lastItemApi = prefs.getString('last_item_api');
      final bool fromApi = lastItemApi == 'true';
      
      if (fromApi && lastType == 'ayah' && _useQuranApi) {
        // If yesterday's item was from API, we should reload it
        // For simplicity, we'll reload from API or use saved cache
        // For now, just use local items
      }
      
      final int? savedIndex = prefs.getInt(_keyLastItemIndex);
      if (_items.isEmpty) {
        await loadData();
      }
      
      if (savedIndex != null && savedIndex < _items.length) {
        _currentItem = _items[savedIndex];
      } else if (_items.isNotEmpty) {
        _currentItem = _items[0];
      }
    }

    return _currentItem;
  }

  /// Get a random item (for "Next" button)
  /// Tries to avoid showing the same item twice in one day
  /// If type is 'ayah' and Quran API is enabled, fetches from API
  Future<DailyItem?> getRandomItem({String? preferredType}) async {
    // If no preferred type, randomly select one (33% chance for each type)
    final actualType = preferredType ?? ['dua', 'hadith', 'ayah'][_random.nextInt(3)];
    
    // If type is 'ayah' and Quran API is enabled, fetch from API
    if (actualType == 'ayah' && _useQuranApi) {
      try {
        print('🕌 Fetching random ayah from Quran API...');
        final ayah = await _quranApiService.fetchRandomAyah();
        if (ayah != null) {
          _currentItem = ayah;
          print('✅ Random ayah fetched from Quran API: ${ayah.source}');
          return ayah;
        } else {
          print('⚠️ Quran API returned null, falling back to local');
        }
      } catch (e) {
        print('❌ Failed to fetch ayah from Quran API: $e, falling back to local');
      }
    }

    // Load local items if empty
    if (_items.isEmpty) {
      await loadData();
    }

    if (_items.isEmpty) {
      return null;
    }

    // Filter items by actual type
    List<DailyItem> availableItems = _items.where((item) => item.type == actualType).toList();
    if (availableItems.isEmpty) {
      availableItems = _items; // Fallback to all items
    }

    final prefs = await SharedPreferences.getInstance();
    final List<String>? shownItemsStr = prefs.getStringList(_keyShownItems);
    final List<int> shownItems = shownItemsStr?.map((s) => int.parse(s)).toList() ?? [];

    // Find available indices
    List<int> availableIndices = [];
    for (int i = 0; i < availableItems.length; i++) {
      if (!shownItems.contains(i)) {
        availableIndices.add(i);
      }
    }

    // If all items shown, reset
    if (availableIndices.isEmpty || shownItems.length >= availableItems.length) {
      shownItems.clear();
      availableIndices = List.generate(availableItems.length, (index) => index);
    }

    // Select random item
    final int randomIndex = availableIndices[_random.nextInt(availableIndices.length)];
    _currentItem = availableItems[randomIndex];

    // Add to shown items
    shownItems.add(randomIndex);
    await prefs.setStringList(_keyShownItems, shownItems.map((i) => i.toString()).toList());

    print('🎲 Random item selected (type: ${_currentItem!.type})');
    return _currentItem;
  }

  /// Get current item
  DailyItem? getCurrentItem() => _currentItem;

  /// Get all items (for future use)
  List<DailyItem> getAllItems() => _items;

  /// Refresh data from API
  Future<bool> refreshData() async {
    try {
      await loadData(forceRefresh: true);
      return _items.isNotEmpty;
    } catch (e) {
      print('❌ Error refreshing data: $e');
      return false;
    }
  }

  /// Check if API is being used
  Future<bool> isUsingApi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUseApi) ?? false;
  }

  /// Clear cache
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCachedItems);
    await prefs.remove(_keyCacheDate);
  }
}
