import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/turkish_city.dart';
import '../models/prayer_times.dart';

/// Service for fetching Ramadan prayer times
/// Uses ezanvakti.imsakiyem.com API (Diyanet) - supports full Ramadan range including past days
class RamadanApiService {
  static const String _abdusBaseUrl = 'https://prayertimes.api.abdus.dev/api/diyanet';
  static const String _ezanvaktiBaseUrl = 'https://ezanvakti.imsakiyem.com/api';
  static const Duration timeoutDuration = Duration(seconds: 10);

  /// Cache: stateId -> districtId (il merkezi)
  final Map<String, String> _districtIdCache = {};
  
  // Cache keys for SharedPreferences
  static const String _keyCachedPrayerTimes = 'cached_prayer_times';
  static const String _keyCacheDate = 'prayer_times_cache_date';
  static const String _keyCachedCityId = 'cached_city_id';

  /// Search for Turkish cities
  /// Returns a list of cities matching the query
  /// Uses ASCII-friendly query for API compatibility (e.g. elazig for Elazığ)
  Future<List<TurkishCity>> searchCities(String query) async {
    try {
      final apiQuery = _toAsciiSearchQuery(query);
      final uri = Uri.parse('$_abdusBaseUrl/search').replace(queryParameters: {
        'q': apiQuery,
      });

      print('🔍 Searching cities: $uri');
      
      final response = await http.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final cities = jsonList
            .map((json) => TurkishCity.fromJson(json))
            .toList();
        
        print('✅ Found ${cities.length} cities for query: $query');
        return cities;
      } else {
        print('❌ City search failed with status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error searching cities: $e');
      return [];
    }
  }

  /// Fetch prayer times for a specific city and date range
  /// Uses ezanvakti API - supports full range including past days
  Future<List<PrayerTimes>> fetchPrayerTimes({
    required String locationId,
    required DateTime startDate,
    required DateTime endDate,
    bool useCache = true,
  }) async {
    // locationId is ezanvakti state ID; resolve to district ID for vakit API
    final districtId = await _getDistrictIdForState(locationId);
    if (districtId == null) {
      print('❌ Could not resolve district ID for state: $locationId');
      return [];
    }

    // Check cache first (use districtId for cache key to match ezanvakti data)
    if (useCache) {
      final cachedData = await _loadCachedPrayerTimes(districtId);
      if (cachedData != null && cachedData.isNotEmpty) {
        final filtered = cachedData.where((pt) =>
            _isDateInRange(pt.date, startDate, endDate)).toList();
        final cachedStart = cachedData.map((p) => p.date).reduce((a, b) => a.isBefore(b) ? a : b);
        final cachedEnd = cachedData.map((p) => p.date).reduce((a, b) => a.isAfter(b) ? a : b);
        if (!startDate.isBefore(cachedStart) && !endDate.isAfter(cachedEnd)) {
          print('✅ Loaded prayer times from cache');
          return filtered;
        }
      }
    }

    try {
      final startStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final endStr = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
      final uri = Uri.parse('$_ezanvaktiBaseUrl/prayer-times/$districtId/range')
          .replace(queryParameters: {'startDate': startStr, 'endDate': endStr});

      print('🕌 Fetching prayer times (ezanvakti): $uri');

      final response = await http.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);
        final List<PrayerTimes> prayerTimesList = [];

        if (jsonData is Map && jsonData['data'] is List) {
          for (var item in jsonData['data'] as List) {
            if (item is Map<String, dynamic>) {
              final dateStr = item['date'] as String?;
              if (dateStr != null) {
                final date = DateTime.parse(dateStr);
                if (_isDateInRange(date, startDate, endDate)) {
                  final times = item['times'] as Map<String, dynamic>? ?? item;
                  prayerTimesList.add(PrayerTimes.fromJson(times, date));
                }
              }
            }
          }
        }

        if (prayerTimesList.isNotEmpty) {
          prayerTimesList.sort((a, b) => a.date.compareTo(b.date));
          await _cachePrayerTimes(districtId, prayerTimesList);
          print('✅ Fetched ${prayerTimesList.length} prayer times (incl. past days)');
          return prayerTimesList;
        } else {
          print('⚠️ No prayer times found in response');
          return [];
        }
      } else {
        print('❌ Prayer times fetch failed with status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching prayer times: $e');
      return [];
    }
  }

  /// Resolve ezanvakti state ID to district ID (il merkezi)
  Future<String?> _getDistrictIdForState(String stateId) async {
    if (_districtIdCache.containsKey(stateId)) {
      return _districtIdCache[stateId];
    }
    try {
      final uri = Uri.parse('$_ezanvaktiBaseUrl/locations/districts')
          .replace(queryParameters: {'stateId': stateId});
      final response = await http.get(uri).timeout(timeoutDuration);
      if (response.statusCode != 200) return null;

      final jsonData = json.decode(response.body);
      final data = jsonData['data'] as List?;
      if (data == null) return null;

      // Find il merkezi: district with same name as state (from state list)
      final stateName = _stateIdToName[stateId];
      if (stateName != null) {
        final stateNorm = _normalizeName(stateName);
        for (var d in data) {
          if (d is Map) {
            final name = (d['name'] as String?) ?? '';
            if (_normalizeName(name) == stateNorm) {
              final id = d['_id']?.toString();
              if (id != null) {
                _districtIdCache[stateId] = id;
                return id;
              }
            }
          }
        }
      }
      // Fallback: first district
      final first = data.isNotEmpty && data.first is Map
          ? (data.first as Map)['_id']?.toString()
          : null;
      if (first != null) _districtIdCache[stateId] = first;
      return first;
    } catch (e) {
      print('⚠️ Error resolving district for state $stateId: $e');
      return null;
    }
  }

  static String _normalizeName(String s) =>
      _toAsciiSearchQuery(s).toUpperCase();

  static const Map<String, String> _stateIdToName = {
    '500': 'ADANA', '501': 'ADIYAMAN', '502': 'AFYONKARAHISAR', '503': 'AGRI',
    '504': 'AKSARAY', '505': 'AMASYA', '506': 'ANKARA', '507': 'ANTALYA',
    '508': 'ARDAHAN', '509': 'ARTVIN', '510': 'AYDIN', '511': 'BALIKESIR',
    '512': 'BARTIN', '513': 'BATMAN', '514': 'BAYBURT', '515': 'BILECIK',
    '516': 'BINGOL', '517': 'BITLIS', '518': 'BOLU', '519': 'BURDUR',
    '520': 'BURSA', '521': 'CANAKKALE', '522': 'CANKIRI', '523': 'CORUM',
    '524': 'DENIZLI', '525': 'DIYARBAKIR', '526': 'DUZCE', '527': 'EDIRNE',
    '528': 'ELAZIG', '529': 'ERZINCAN', '530': 'ERZURUM', '531': 'ESKISEHIR',
    '532': 'GAZIANTEP', '533': 'GIRESUN', '534': 'GUMUSHANE', '535': 'HAKKARI',
    '536': 'HATAY', '537': 'IGDIR', '538': 'ISPARTA', '539': 'ISTANBUL',
    '540': 'IZMIR', '541': 'KAHRAMANMARAS', '542': 'KARABUK', '543': 'KARAMAN',
    '544': 'KARS', '545': 'KASTAMONU', '546': 'KAYSERI', '547': 'KILIS',
    '548': 'KIRIKKALE', '549': 'KIRKLARELI', '550': 'KIRSEHIR', '551': 'KOCAELI',
    '552': 'KONYA', '553': 'KUTAHYA', '554': 'MALATYA', '555': 'MANISA',
    '556': 'MARDIN', '557': 'MERSIN', '558': 'MUGLA', '559': 'MUS',
    '560': 'NEVSEHIR', '561': 'NIGDE', '562': 'ORDU', '563': 'OSMANIYE',
    '564': 'RIZE', '565': 'SAKARYA', '566': 'SAMSUN', '567': 'SANLIURFA',
    '568': 'SIIRT', '569': 'SINOP', '570': 'SIRNAK', '571': 'SIVAS',
    '572': 'TEKIRDAG', '573': 'TOKAT', '574': 'TRABZON', '575': 'TUNCELI',
    '576': 'USAK', '577': 'VAN', '578': 'YALOVA', '579': 'YOZGAT', '580': 'ZONGULDAK',
  };

  /// Convert Turkish characters to ASCII for API search
  static String _toAsciiSearchQuery(String query) {
    const Map<String, String> trToAscii = {
      'ı': 'i', 'İ': 'I', 'ğ': 'g', 'Ğ': 'G', 'ü': 'u', 'Ü': 'U',
      'ş': 's', 'Ş': 'S', 'ö': 'o', 'Ö': 'O', 'ç': 'c', 'Ç': 'C',
    };
    String result = query;
    trToAscii.forEach((tr, ascii) {
      result = result.replaceAll(tr, ascii);
    });
    return result;
  }

  /// Check if a date is within the specified range
  bool _isDateInRange(DateTime date, DateTime startDate, DateTime endDate) {
    return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
           date.isBefore(endDate.add(const Duration(days: 1)));
  }

  /// Get Ramadan dates for a specific year
  /// Returns start and end dates of Ramadan
  /// Note: These are approximate dates, actual dates may vary
  Map<String, DateTime> getRamadanDates(int year) {
    // Ramadan 2026: February 19 - March 19 (29 days)
    // Ramadan 2027: February 8 - March 8 (29 days)
    // Note: In production, use a proper Islamic calendar library
    
    if (year == 2026) {
      return {
        'start': DateTime(2026, 2, 19),
        'end': DateTime(2026, 3, 19),
      };
    } else if (year == 2027) {
      return {
        'start': DateTime(2027, 2, 8),
        'end': DateTime(2027, 3, 8),
      };
    } else {
      // Default fallback (shouldn't happen with dynamic year detection)
      return {
        'start': DateTime(year, 3, 1),
        'end': DateTime(year, 3, 29),
      };
    }
  }

  /// Determine which Ramadan year to show
  /// If current date is during Ramadan, show current year
  /// Otherwise, show next year's Ramadan
  int getCurrentRamadanYear() {
    final now = DateTime.now();
    final currentYear = now.year;
    
    // Check if we're currently in Ramadan
    final currentRamadan = getRamadanDates(currentYear);
    if (now.isAfter(currentRamadan['start']!) && 
        now.isBefore(currentRamadan['end']!.add(const Duration(days: 1)))) {
      return currentYear;
    }
    
    // Check if Ramadan is coming this year
    if (now.isBefore(currentRamadan['start']!)) {
      return currentYear;
    }
    
    // Ramadan has passed, show next year
    return currentYear + 1;
  }

  /// Cache prayer times to SharedPreferences
  Future<void> _cachePrayerTimes(String locationId, List<PrayerTimes> prayerTimes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prayerTimes.map((pt) => pt.toJson()).toList();
      final jsonString = json.encode(jsonList);
      
      await prefs.setString(_keyCachedPrayerTimes, jsonString);
      await prefs.setString(_keyCacheDate, DateTime.now().toIso8601String());
      await prefs.setString(_keyCachedCityId, locationId);
    } catch (e) {
      print('⚠️ Error caching prayer times: $e');
    }
  }

  /// Load cached prayer times from SharedPreferences
  Future<List<PrayerTimes>?> _loadCachedPrayerTimes(String locationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_keyCachedPrayerTimes);
      final cacheDate = prefs.getString(_keyCacheDate);
      final cachedCityId = prefs.getString(_keyCachedCityId);
      
      if (cachedJson != null && cacheDate != null && cachedCityId == locationId) {
        // Check if cache is less than 24 hours old
        final cacheTime = DateTime.parse(cacheDate);
        final now = DateTime.now();
        final difference = now.difference(cacheTime);
        
        if (difference.inHours < 24) {
          final List<dynamic> jsonList = json.decode(cachedJson);
          return jsonList.map((json) {
            final date = DateTime.parse(json['date']);
            return PrayerTimes.fromJson(json, date);
          }).toList();
        } else {
          // Cache expired
          await clearCache();
        }
      }
    } catch (e) {
      print('⚠️ Error loading cached prayer times: $e');
    }
    return null;
  }

  /// Clear cached prayer times
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCachedPrayerTimes);
      await prefs.remove(_keyCacheDate);
      await prefs.remove(_keyCachedCityId);
    } catch (e) {
      print('⚠️ Error clearing cache: $e');
    }
  }

  /// Get popular Turkish cities (legacy - use getAllTurkishCities)
  List<Map<String, String>> getPopularCities() {
    return getAllTurkishCities();
  }

  /// Get all 81 Turkish cities (il) with ezanvakti state IDs
  /// Used for Ramadan imsakiye - supports full range including past days
  List<Map<String, String>> getAllTurkishCities() {
    return [
      {'name': 'Adana', 'id': '500'}, {'name': 'Adıyaman', 'id': '501'},
      {'name': 'Afyonkarahisar', 'id': '502'}, {'name': 'Ağrı', 'id': '503'},
      {'name': 'Aksaray', 'id': '504'}, {'name': 'Amasya', 'id': '505'},
      {'name': 'Ankara', 'id': '506'}, {'name': 'Antalya', 'id': '507'},
      {'name': 'Ardahan', 'id': '508'}, {'name': 'Artvin', 'id': '509'},
      {'name': 'Aydın', 'id': '510'}, {'name': 'Balıkesir', 'id': '511'},
      {'name': 'Bartın', 'id': '512'}, {'name': 'Batman', 'id': '513'},
      {'name': 'Bayburt', 'id': '514'}, {'name': 'Bilecik', 'id': '515'},
      {'name': 'Bingöl', 'id': '516'}, {'name': 'Bitlis', 'id': '517'},
      {'name': 'Bolu', 'id': '518'}, {'name': 'Burdur', 'id': '519'},
      {'name': 'Bursa', 'id': '520'}, {'name': 'Çanakkale', 'id': '521'},
      {'name': 'Çankırı', 'id': '522'}, {'name': 'Çorum', 'id': '523'},
      {'name': 'Denizli', 'id': '524'}, {'name': 'Diyarbakır', 'id': '525'},
      {'name': 'Düzce', 'id': '526'}, {'name': 'Edirne', 'id': '527'},
      {'name': 'Elazığ', 'id': '528'}, {'name': 'Erzincan', 'id': '529'},
      {'name': 'Erzurum', 'id': '530'}, {'name': 'Eskişehir', 'id': '531'},
      {'name': 'Gaziantep', 'id': '532'}, {'name': 'Giresun', 'id': '533'},
      {'name': 'Gümüşhane', 'id': '534'}, {'name': 'Hakkari', 'id': '535'},
      {'name': 'Hatay', 'id': '536'}, {'name': 'Iğdır', 'id': '537'},
      {'name': 'Isparta', 'id': '538'}, {'name': 'İstanbul', 'id': '539'},
      {'name': 'İzmir', 'id': '540'}, {'name': 'Kahramanmaraş', 'id': '541'},
      {'name': 'Karabük', 'id': '542'}, {'name': 'Karaman', 'id': '543'},
      {'name': 'Kars', 'id': '544'}, {'name': 'Kastamonu', 'id': '545'},
      {'name': 'Kayseri', 'id': '546'}, {'name': 'Kırıkkale', 'id': '548'},
      {'name': 'Kırklareli', 'id': '549'}, {'name': 'Kırşehir', 'id': '550'},
      {'name': 'Kilis', 'id': '547'}, {'name': 'Kocaeli', 'id': '551'},
      {'name': 'Konya', 'id': '552'}, {'name': 'Kütahya', 'id': '553'},
      {'name': 'Malatya', 'id': '554'}, {'name': 'Manisa', 'id': '555'},
      {'name': 'Mardin', 'id': '556'}, {'name': 'Mersin', 'id': '557'},
      {'name': 'Muğla', 'id': '558'}, {'name': 'Muş', 'id': '559'},
      {'name': 'Nevşehir', 'id': '560'}, {'name': 'Niğde', 'id': '561'},
      {'name': 'Ordu', 'id': '562'}, {'name': 'Osmaniye', 'id': '563'},
      {'name': 'Rize', 'id': '564'}, {'name': 'Sakarya', 'id': '565'},
      {'name': 'Samsun', 'id': '566'}, {'name': 'Şanlıurfa', 'id': '567'},
      {'name': 'Siirt', 'id': '568'}, {'name': 'Sinop', 'id': '569'},
      {'name': 'Sivas', 'id': '571'}, {'name': 'Şırnak', 'id': '570'},
      {'name': 'Tekirdağ', 'id': '572'}, {'name': 'Tokat', 'id': '573'},
      {'name': 'Trabzon', 'id': '574'}, {'name': 'Tunceli', 'id': '575'},
      {'name': 'Uşak', 'id': '576'}, {'name': 'Van', 'id': '577'},
      {'name': 'Yalova', 'id': '578'}, {'name': 'Yozgat', 'id': '579'},
      {'name': 'Zonguldak', 'id': '580'},
    ];
  }

  /// Fetch prayer times for Ramadan - handles multi-month span (e.g. Feb-Mar 2026)
  /// If Ramadan spans two months, makes two API calls and merges results
  Future<List<PrayerTimes>> fetchPrayerTimesForRamadan({
    required String locationId,
    required DateTime startDate,
    required DateTime endDate,
    bool useCache = true,
  }) async {
    if (startDate.month == endDate.month) {
      return fetchPrayerTimes(
        locationId: locationId,
        startDate: startDate,
        endDate: endDate,
        useCache: useCache,
      );
    }

    final List<PrayerTimes> allTimes = [];
    DateTime current = DateTime(startDate.year, startDate.month, 1);

    while (current.isBefore(endDate) || current.isAtSameMomentAs(DateTime(endDate.year, endDate.month, 1))) {
      final monthEnd = DateTime(current.year, current.month + 1, 0);
      final monthStart = current.isBefore(startDate) ? startDate : current;
      final monthEndDate = monthEnd.isAfter(endDate) ? endDate : monthEnd;

      final times = await fetchPrayerTimes(
        locationId: locationId,
        startDate: monthStart,
        endDate: monthEndDate,
        useCache: false,
      );
      allTimes.addAll(times);

      if (current.month == 12) {
        current = DateTime(current.year + 1, 1, 1);
      } else {
        current = DateTime(current.year, current.month + 1, 1);
      }
    }

    allTimes.sort((a, b) => a.date.compareTo(b.date));
    if (allTimes.isNotEmpty) {
      await _cachePrayerTimes(locationId, allTimes);
    }
    return allTimes;
  }
}
