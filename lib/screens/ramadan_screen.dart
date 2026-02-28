import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/turkish_city.dart';
import '../models/prayer_times.dart';
import '../services/ramadan_api_service.dart';
import '../services/firebase_service.dart' show FirebaseService, AnalyticsEvents, AnalyticsParams;

/// Ramadan Prayer Times Screen
/// Shows countdown to sahur, today's prayer times, and full month schedule
class RamadanScreen extends StatefulWidget {
  const RamadanScreen({Key? key}) : super(key: key);

  @override
  State<RamadanScreen> createState() => _RamadanScreenState();
}

class _RamadanScreenState extends State<RamadanScreen> {
  final RamadanApiService _apiService = RamadanApiService();
  final ScrollController _scrollController = ScrollController();
  
  TurkishCity? _selectedCity;
  List<PrayerTimes> _prayerTimesList = [];
  PrayerTimes? _todaysPrayerTimes;
  
  bool _isLoading = true;
  bool _isLoadingCities = false;
  String? _errorMessage;
  
  Timer? _countdownTimer;
  Duration _timeUntilSahur = Duration.zero;
  Duration _timeUntilIftar = Duration.zero;
  bool _isSahurTime = false;
  bool _isIftarTime = false;

  /// Countdown display mode: sahur (before sahur), iftar (between sahur-iftar), iftarVakti (after iftar)
  String _countdownMode = 'sahur';
  
  // SharedPreferences keys
  static const String _keySelectedCityId = 'ramadan_selected_city_id';
  static const String _keySelectedCityName = 'ramadan_selected_city_name';

  /// Valid ezanvakti state ID range (500-580)
  static bool _isValidStateId(String id) {
    final n = int.tryParse(id);
    return n != null && n >= 500 && n <= 580;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedCity();
    
    // Log screen view
    FirebaseService.logScreenView(screenName: AnalyticsEvents.screenRamadan);
    FirebaseService.logEvent(name: AnalyticsEvents.ramadanScreenViewed);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Load saved city from SharedPreferences
  Future<void> _loadSavedCity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? cityId = prefs.getString(_keySelectedCityId);
      final String? cityName = prefs.getString(_keySelectedCityName);

      // Migrate: old abdus IDs are invalid for ezanvakti - re-prompt city selection
      if (cityId != null && !_isValidStateId(cityId)) {
        await prefs.remove(_keySelectedCityId);
        await prefs.remove(_keySelectedCityName);
        await _apiService.clearCache();
        cityId = null;
      }

      final id = cityId;
      if (id != null && cityName != null) {
        setState(() {
          _selectedCity = TurkishCity(
            id: id,
            name: cityName,
            country: 'Türkiye',
          );
        });
        await _loadPrayerTimes();
      } else {
        // No saved city, show selection dialog
        setState(() {
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCitySelectionDialog();
        });
      }
    } catch (e) {
      print('❌ Error loading saved city: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Şehir bilgisi yüklenemedi';
      });
    }
  }

  /// Save selected city to SharedPreferences
  Future<void> _saveSelectedCity(TurkishCity city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySelectedCityId, city.id);
      await prefs.setString(_keySelectedCityName, city.name);
      
      // Log city selection
      FirebaseService.logEvent(
        name: AnalyticsEvents.ramadanCitySelected,
        parameters: {AnalyticsParams.cityName: city.name},
      );
    } catch (e) {
      print('❌ Error saving city: $e');
    }
  }

  /// Load prayer times for selected city
  Future<void> _loadPrayerTimes({bool forceRefresh = false}) async {
    if (_selectedCity == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get Ramadan dates for current/next year
      final ramadanYear = _apiService.getCurrentRamadanYear();
      final ramadanDates = _apiService.getRamadanDates(ramadanYear);
      final startDate = ramadanDates['start']!;
      final endDate = ramadanDates['end']!;
      
      // Fetch prayer times (handles multi-month Ramadan e.g. Feb-Mar 2026)
      final prayerTimes = await _apiService.fetchPrayerTimesForRamadan(
        locationId: _selectedCity!.id,
        startDate: startDate,
        endDate: endDate,
        useCache: !forceRefresh,
      );

      if (prayerTimes.isEmpty) {
        setState(() {
          _errorMessage = 'Namaz vakitleri yüklenemedi. Lütfen tekrar deneyin.';
          _isLoading = false;
        });
        return;
      }

      // Find today's prayer times
      final now = DateTime.now();
      PrayerTimes? todaysTimes;
      
      for (var pt in prayerTimes) {
        if (pt.date.year == now.year &&
            pt.date.month == now.month &&
            pt.date.day == now.day) {
          todaysTimes = pt;
          break;
        }
      }

      setState(() {
        _prayerTimesList = prayerTimes;
        _todaysPrayerTimes = todaysTimes;
        _isLoading = false;
      });

      // Start countdown timer
      _startCountdownTimer();

      // Scroll to today's row in table after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTodayRow();
      });

      // Log successful load
      FirebaseService.logEvent(
        name: AnalyticsEvents.ramadanTimesLoaded,
        parameters: {
          AnalyticsParams.cityName: _selectedCity!.name,
          AnalyticsParams.year: ramadanYear,
        },
      );
    } catch (e) {
      print('❌ Error loading prayer times: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Namaz vakitleri yüklenirken hata oluştu: ${e.toString()}';
      });
      
      FirebaseService.logError(
        exception: e,
        reason: 'Error loading prayer times',
      );
    }
  }

  /// Start countdown timer - switches between Sahur and Iftar based on time of day
  void _startCountdownTimer() {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      DateTime? sahurTime;
      DateTime? iftarTime;

      if (_todaysPrayerTimes != null) {
        final imsakParts = _todaysPrayerTimes!.imsak.split(':');
        final aksamParts = _todaysPrayerTimes!.aksam.split(':');
        if (imsakParts.length == 2) {
          sahurTime = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(imsakParts[0]),
            int.parse(imsakParts[1]),
          );
        }
        if (aksamParts.length == 2) {
          iftarTime = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(aksamParts[0]),
            int.parse(aksamParts[1]),
          );
        }
      }

      String mode = 'sahur';
      Duration timeUntilSahur = Duration.zero;
      Duration timeUntilIftar = Duration.zero;
      bool isSahurTime = false;
      bool isIftarTime = false;

      if (sahurTime != null && iftarTime != null) {
        if (now.isBefore(sahurTime)) {
          mode = 'sahur';
          timeUntilSahur = sahurTime.difference(now);
        } else if (now.isBefore(iftarTime)) {
          mode = 'iftar';
          timeUntilIftar = iftarTime.difference(now);
        } else {
          mode = 'iftarVakti';
          isIftarTime = true;
          final tomorrow = now.add(const Duration(days: 1));
          for (var pt in _prayerTimesList) {
            if (pt.date.year == tomorrow.year &&
                pt.date.month == tomorrow.month &&
                pt.date.day == tomorrow.day) {
              final imsakParts = pt.imsak.split(':');
              if (imsakParts.length == 2) {
                final nextSahur = DateTime(
                  tomorrow.year,
                  tomorrow.month,
                  tomorrow.day,
                  int.parse(imsakParts[0]),
                  int.parse(imsakParts[1]),
                );
                timeUntilSahur = nextSahur.difference(now);
                mode = 'yarinSahur';
                isIftarTime = false;
              }
              break;
            }
          }
        }
      }

      setState(() {
        _countdownMode = mode;
        _timeUntilSahur = timeUntilSahur;
        _timeUntilIftar = timeUntilIftar;
        _isSahurTime = isSahurTime;
        _isIftarTime = isIftarTime;
      });
    });
  }

  /// Show city selection dialog with search - 81 cities
  /// Fetches correct location ID from API for accurate Diyanet prayer times
  Future<void> _showCitySelectionDialog() async {
    final allCities = _apiService.getAllTurkishCities();
    String searchQuery = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredCities = searchQuery.isEmpty
              ? allCities
              : allCities
                  .where((c) =>
                      c['name']!.toLowerCase().contains(searchQuery.toLowerCase()))
                  .toList();

          return AlertDialog(
            title: const Text(
              'Şehir Seçin (81 İl)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D5016),
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Şehir ara...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF6B8E23)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() => searchQuery = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredCities.length,
                      itemBuilder: (context, index) {
                        final city = filteredCities[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.location_city,
                            color: Color(0xFF6B8E23),
                          ),
                          title: Text(city['name']!),
                          onTap: () => _onCitySelected(
                            dialogContext,
                            city['name']!,
                            city['id']!,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Handle city selection - uses ezanvakti state ID from 81-il list
  Future<void> _onCitySelected(
      BuildContext dialogContext, String cityName, String stateId) async {
    Navigator.of(dialogContext).pop();

    setState(() {
      _isLoading = true;
    });

    final cityToUse = TurkishCity(
      id: stateId,
      name: cityName,
      country: 'Türkiye',
    );

    setState(() {
      _selectedCity = cityToUse;
    });

    await _saveSelectedCity(cityToUse);
    await _loadPrayerTimes();
  }

  /// Scroll to today's row in the imsakiye table
  void _scrollToTodayRow() {
    if (!mounted || _prayerTimesList.isEmpty) return;

    final now = DateTime.now();
    int todayIndex = -1;
    for (int i = 0; i < _prayerTimesList.length; i++) {
      final pt = _prayerTimesList[i];
      if (pt.date.year == now.year &&
          pt.date.month == now.month &&
          pt.date.day == now.day) {
        todayIndex = i;
        break;
      }
    }
    if (todayIndex < 0) return;

    const countdownHeight = 180.0;
    final todayCardHeight = _todaysPrayerTimes != null ? 280.0 : 0.0;
    const tableHeaderHeight = 60.0;
    const rowHeight = 48.0;
    final targetOffset = countdownHeight +
        todayCardHeight +
        tableHeaderHeight +
        (todayIndex * rowHeight) -
        100;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Change selected city
  void _changeCity() {
    _showCitySelectionDialog();
  }

  /// Refresh prayer times
  Future<void> _refreshPrayerTimes() async {
    await _loadPrayerTimes(forceRefresh: true);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Namaz vakitleri güncellendi'),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    FirebaseService.logEvent(name: AnalyticsEvents.ramadanTimesRefreshed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedCity != null ? '${_selectedCity!.name} İmsakiyesi' : 'Ramazan İmsakiyesi',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6B8E23), Color(0xFF8FBC8F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (_selectedCity != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshPrayerTimes,
              tooltip: 'Yenile',
            ),
          IconButton(
            icon: const Icon(Icons.location_city),
            onPressed: _changeCity,
            tooltip: 'Şehir Değiştir',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F5DC), Color(0xFFE8F5E9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorWidget()
                : _selectedCity == null
                    ? _buildNoCityWidget()
                    : _buildContent(),
      ),
    );
  }

  /// Build main content
  Widget _buildContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        children: [
          _buildCountdownCard(),
          const SizedBox(height: 16),
          if (_todaysPrayerTimes != null)
            _buildTodaysPrayerTimesCard(),
          const SizedBox(height: 16),
          _buildFullScheduleSection(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Build countdown card - Sahur or Iftar based on time of day
  Widget _buildCountdownCard() {
    String title;
    IconData icon;
    String displayText;

    switch (_countdownMode) {
      case 'sahur':
        title = 'Sahura Ne Kadar Kaldı?';
        icon = Icons.nightlight_round;
        final h = _timeUntilSahur.inHours;
        final m = _timeUntilSahur.inMinutes.remainder(60);
        final s = _timeUntilSahur.inSeconds.remainder(60);
        displayText = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
        break;
      case 'iftar':
        title = 'İftara Ne Kadar Kaldı?';
        icon = Icons.restaurant;
        final h = _timeUntilIftar.inHours;
        final m = _timeUntilIftar.inMinutes.remainder(60);
        final s = _timeUntilIftar.inSeconds.remainder(60);
        displayText = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
        break;
      case 'iftarVakti':
        title = 'İftar Vakti';
        icon = Icons.restaurant;
        displayText = 'İftar Vakti!';
        break;
      case 'yarinSahur':
        title = 'Yarınki Sahura Kalan Süre';
        icon = Icons.nightlight_round;
        final h = _timeUntilSahur.inHours;
        final m = _timeUntilSahur.inMinutes.remainder(60);
        final s = _timeUntilSahur.inSeconds.remainder(60);
        displayText = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
        break;
      default:
        title = 'Sahura Ne Kadar Kaldı?';
        icon = Icons.nightlight_round;
        displayText = '--:--:--';
    }

    final isMessage = displayText == 'İftar Vakti!';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B8E23), Color(0xFF8FBC8F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            displayText,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMessage ? 32 : 48,
              fontWeight: FontWeight.bold,
              fontFamily: isMessage ? null : 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  /// Build today's prayer times card
  Widget _buildTodaysPrayerTimesCard() {
    if (_todaysPrayerTimes == null) return const SizedBox.shrink();
    
    final pt = _todaysPrayerTimes!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Bugünkü Vakitler - ${pt.dateLabel}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D5016),
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildPrayerTimeItem('İmsak', pt.imsak, Icons.bedtime, isSpecial: true),
              _buildPrayerTimeItem('Güneş', pt.gunes, Icons.wb_sunny),
              _buildPrayerTimeItem('Öğle', pt.ogle, Icons.light_mode),
              _buildPrayerTimeItem('İkindi', pt.ikindi, Icons.brightness_6),
              _buildPrayerTimeItem('Akşam', pt.aksam, Icons.nightlight, isIftar: true),
              _buildPrayerTimeItem('Yatsı', pt.yatsi, Icons.dark_mode),
            ],
          ),
        ],
      ),
    );
  }

  /// Build individual prayer time item
  Widget _buildPrayerTimeItem(String name, String time, IconData icon, {bool isSpecial = false, bool isIftar = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSpecial 
            ? const Color(0xFFE8F5E9) 
            : isIftar 
                ? const Color(0xFFFFF3E0)
                : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSpecial 
              ? const Color(0xFF6B8E23)
              : isIftar
                  ? const Color(0xFFFF9800)
                  : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSpecial 
                ? const Color(0xFF6B8E23)
                : isIftar
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF757575),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D5016),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build full schedule section (placeholder)
  Widget _buildFullScheduleSection() {
    if (_prayerTimesList.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'İmsakiye verisi yüklenemedi',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF757575),
            ),
          ),
        ),
      );
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedCity?.name ?? ''} İmsakiye ${_apiService.getCurrentRamadanYear()}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D5016),
            ),
          ),
          const SizedBox(height: 16),
          
          // Table header
          _buildTableHeader(),
          
          const Divider(height: 1, thickness: 1),
          
          // Table rows
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _prayerTimesList.length,
            itemBuilder: (context, index) {
              final prayerTime = _prayerTimesList[index];
              return _buildTableRow(prayerTime, index);
            },
          ),
        ],
      ),
    );
  }

  /// Build table header
  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6B8E23).withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          _buildHeaderCell('Tarih', flex: 2),
          _buildHeaderCell('İmsak', flex: 2),
          _buildHeaderCell('Güneş', flex: 2),
          _buildHeaderCell('Öğle', flex: 2),
          _buildHeaderCell('İkindi', flex: 2),
          _buildHeaderCell('Akşam', flex: 2),
          _buildHeaderCell('Yatsı', flex: 2),
        ],
      ),
    );
  }

  /// Build header cell
  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D5016),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Build table row - shows "X. Gün" and date, past days included, today highlighted
  Widget _buildTableRow(PrayerTimes prayerTime, int index) {
    final isToday = prayerTime.isToday;
    final isOddRow = index % 2 == 1;
    final ramadanDayNum = index + 1;
    final dateColumnText = '${ramadanDayNum}. Gün\n${prayerTime.fullDateLabel}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isToday
            ? const Color(0xFFE0F2E0)
            : isOddRow
                ? const Color(0xFFF5F5F5)
                : Colors.white,
        border: Border(
          left: isToday
              ? const BorderSide(color: Color(0xFF6B8E23), width: 4)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          _buildDataCell(
            dateColumnText,
            flex: 2,
            isBold: isToday,
            isMultiline: true,
          ),
          _buildDataCell(prayerTime.imsak, flex: 2, isBold: isToday),
          _buildDataCell(prayerTime.gunes, flex: 2, isBold: isToday),
          _buildDataCell(prayerTime.ogle, flex: 2, isBold: isToday),
          _buildDataCell(prayerTime.ikindi, flex: 2, isBold: isToday),
          _buildDataCell(prayerTime.aksam, flex: 2, isBold: isToday),
          _buildDataCell(prayerTime.yatsi, flex: 2, isBold: isToday),
        ],
      ),
    );
  }

  /// Build data cell
  Widget _buildDataCell(String text,
      {int flex = 1, bool isBold = false, bool isMultiline = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: isMultiline ? 10 : 11,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: isBold ? const Color(0xFF2D5016) : const Color(0xFF2C3E50),
        ),
        textAlign: TextAlign.center,
        maxLines: isMultiline ? 2 : 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Build error widget
  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Bir hata oluştu',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF2C3E50),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPrayerTimes,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E23),
              ),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build no city widget
  Widget _buildNoCityWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_city,
              color: Color(0xFF6B8E23),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Şehir Seçin',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D5016),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ramazan imsakiyesini görmek için şehrinizi seçin',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF757575),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCitySelectionDialog,
              icon: const Icon(Icons.add_location),
              label: const Text('Şehir Seç'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E23),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
