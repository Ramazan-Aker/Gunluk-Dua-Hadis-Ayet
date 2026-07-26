import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/turkish_city.dart';
import '../models/prayer_times.dart';
import '../services/ramadan_api_service.dart';
import '../services/firebase_service.dart'
    show FirebaseService, AnalyticsEvents, AnalyticsParams;
import '../services/ad_service.dart';

/// Namaz vakitleri / İmsakiye ekranı — geri sayım, günlük vakitler ve liste
class RamadanScreen extends StatefulWidget {
  const RamadanScreen({super.key});

  @override
  State<RamadanScreen> createState() => _RamadanScreenState();
}

class _RamadanScreenState extends State<RamadanScreen> {
  final RamadanApiService _apiService = RamadanApiService();
  final ScrollController _imsakiyeScrollController =
      ScrollController(); // İmsakiye listesi için iç scroll

  TurkishCity? _selectedCity;
  List<PrayerTimes> _prayerTimesList = [];
  PrayerTimes? _todaysPrayerTimes;
  bool _isShowingRamadan = false;
  int? _displayRamadanYear;

  bool _isLoading = true;
  String? _errorMessage;

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
    _imsakiyeScrollController.dispose();
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
    } catch (e) {}
  }

  /// Load prayer times for selected city
  Future<void> _loadPrayerTimes({bool forceRefresh = false}) async {
    if (_selectedCity == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final isRamadan = _apiService.isRamadanDate(now);
      final dateRange = _apiService.getPrayerTimesDateRange(now);
      final startDate = dateRange['start']!;
      final endDate = dateRange['end']!;

      // Ramazan'da tam imsakiye, diğer günlerde bugünden itibaren 30 günlük
      // normal namaz vakitleri gösterilir.
      final prayerTimes = isRamadan
          ? await _apiService.fetchPrayerTimesForRamadan(
              locationId: _selectedCity!.id,
              startDate: startDate,
              endDate: endDate,
              useCache: !forceRefresh,
            )
          : await _apiService.fetchPrayerTimes(
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
        _isShowingRamadan = isRamadan;
        _displayRamadanYear = isRamadan ? now.year : null;
        _isLoading = false;
      });

      // Scroll to today's row in table after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTodayRow();
      });

      // Log successful load
      FirebaseService.logEvent(
        name: AnalyticsEvents.ramadanTimesLoaded,
        parameters: {
          AnalyticsParams.cityName: _selectedCity!.name,
          AnalyticsParams.year: now.year,
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Namaz vakitleri yüklenirken hata oluştu: ${e.toString()}';
      });

      FirebaseService.logError(
        exception: e,
        reason: 'Error loading prayer times',
      );
    }
  }

  String get _scheduleTitle {
    final cityName = _selectedCity?.name;
    if (_isShowingRamadan) {
      final year = _displayRamadanYear ?? DateTime.now().year;
      return cityName == null
          ? 'Ramazan İmsakiyesi $year'
          : '$cityName İmsakiye $year';
    }
    return cityName == null ? 'Namaz Vakitleri' : '$cityName Namaz Vakitleri';
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
                  .where((c) => c['name']!
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()))
                  .toList();

          return AlertDialog(
            title: const Text(
              'Şehir Seçin (81 İl)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
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
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF1E40AF)),
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
                            color: Color(0xFF1E40AF),
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

  /// İmsakiye listesinde bugünün satırına scroll et
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

    const rowHeight = 48.0;
    final targetOffset = (todayIndex * rowHeight) - 80;
    if (_imsakiyeScrollController.hasClients) {
      _imsakiyeScrollController.animateTo(
        targetOffset.clamp(
            0.0, _imsakiyeScrollController.position.maxScrollExtent),
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
          backgroundColor: Color(0xFFF59E0B),
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
          _scheduleTitle,
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
              colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
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
            colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildErrorWidget()
                      : _selectedCity == null
                          ? _buildNoCityWidget()
                          : _buildContent(),
            ),
            const AdBannerWidget(),
          ],
        ),
      ),
    );
  }

  /// Build main content:
  /// Modern kart tasarımı ile her gün ayrı kart
  Widget _buildContent() {
    if (_prayerTimesList.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ImsakiyeCountdownCard(
              todaysPrayerTimes: _todaysPrayerTimes,
              prayerTimesList: _prayerTimesList,
            ),
            const SizedBox(height: 8),
            if (_todaysPrayerTimes != null) _buildTodaysPrayerTimesCard(),
            const SizedBox(height: 8),
            _buildEmptyImsakiyeCard(),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ImsakiyeCountdownCard(
            todaysPrayerTimes: _todaysPrayerTimes,
            prayerTimesList: _prayerTimesList,
          ),
          const SizedBox(height: 8),
          if (_todaysPrayerTimes != null) _buildTodaysPrayerTimesCard(),
          const SizedBox(height: 8),
          _buildImsakiyeCalendar(),
        ],
      ),
    );
  }

  /// Modern kart tasarımı ile imsakiye takvimi
  Widget _buildImsakiyeCalendar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _scheduleTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const Icon(
                Icons.calendar_month,
                color: Color(0xFF1E40AF),
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Günler listesi (her gün bir kart)
          ..._prayerTimesList.asMap().entries.map((entry) {
            final index = entry.key;
            final prayerTime = entry.value;
            final isToday = prayerTime.isToday;
            final displayedDay =
                _isShowingRamadan ? index + 1 : prayerTime.date.day;
            final dateCaption = _isShowingRamadan
                ? prayerTime.dateLabel
                : prayerTime.dateLabel.replaceFirst(
                    '${prayerTime.date.day} ',
                    '',
                  );

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isToday ? const Color(0xFFDBEAFE) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isToday ? const Color(0xFF1E40AF) : Colors.grey.shade200,
                  width: isToday ? 2 : 1,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Tarih (gün + ay)
                    SizedBox(
                      width: 50,
                      child: Column(
                        children: [
                          Text(
                            '$displayedDay',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isToday
                                  ? const Color(0xFF1E40AF)
                                  : const Color(0xFF1E3A8A),
                            ),
                          ),
                          Text(
                            dateCaption,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Namaz vakitleri (kompakt grid)
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildTimeChip(
                              'İmsak', prayerTime.imsak, Icons.nightlight),
                          _buildTimeChip(
                              'Güneş', prayerTime.gunes, Icons.wb_sunny),
                          _buildTimeChip(
                              'Öğle', prayerTime.ogle, Icons.wb_sunny_outlined),
                          _buildTimeChip(
                              'İkindi', prayerTime.ikindi, Icons.wb_twilight),
                          _buildTimeChip(
                              'Akşam', prayerTime.aksam, Icons.nights_stay),
                          _buildTimeChip(
                              'Yatsı', prayerTime.yatsi, Icons.dark_mode),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, String time, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF1E40AF)),
          const SizedBox(width: 4),
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyImsakiyeCard() {
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
          'Namaz vakitleri yüklenemedi',
          style: TextStyle(fontSize: 14, color: Color(0xFF757575)),
        ),
      ),
    );
  }

  /// Build today's prayer times card - responsive for different screen sizes
  Widget _buildTodaysPrayerTimesCard() {
    if (_todaysPrayerTimes == null) return const SizedBox.shrink();

    final pt = _todaysPrayerTimes!;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 360 || mediaQuery.size.height < 600;

    final cardPadding = isSmallScreen ? 8.0 : 12.0;
    final titleFontSize = isSmallScreen ? 15.0 : 17.0;
    final spacing = isSmallScreen ? 8.0 : 12.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12),
      padding: EdgeInsets.all(cardPadding),
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
          Text(
            'Bugünkü Vakitler - ${pt.dateLabel}',
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E3A8A),
            ),
          ),
          SizedBox(height: spacing),
          // Column+Row - overflow önlemek için GridView yerine (sabit aspect ratio sorun çıkarıyordu)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                      child: _buildPrayerTimeItem(
                          context, 'İmsak', pt.imsak, Icons.bedtime,
                          isSpecial: true)),
                  SizedBox(width: isSmallScreen ? 8 : 10),
                  Expanded(
                      child: _buildPrayerTimeItem(
                          context, 'Güneş', pt.gunes, Icons.wb_sunny)),
                ],
              ),
              SizedBox(height: isSmallScreen ? 8 : 10),
              Row(
                children: [
                  Expanded(
                      child: _buildPrayerTimeItem(
                          context, 'Öğle', pt.ogle, Icons.light_mode)),
                  SizedBox(width: isSmallScreen ? 8 : 10),
                  Expanded(
                      child: _buildPrayerTimeItem(
                          context, 'İkindi', pt.ikindi, Icons.brightness_6)),
                ],
              ),
              SizedBox(height: isSmallScreen ? 8 : 10),
              Row(
                children: [
                  Expanded(
                      child: _buildPrayerTimeItem(
                          context, 'Akşam', pt.aksam, Icons.nightlight,
                          isIftar: true)),
                  SizedBox(width: isSmallScreen ? 8 : 10),
                  Expanded(
                      child: _buildPrayerTimeItem(
                          context, 'Yatsı', pt.yatsi, Icons.dark_mode)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build individual prayer time item - responsive, overflow-safe
  Widget _buildPrayerTimeItem(
      BuildContext context, String name, String time, IconData icon,
      {bool isSpecial = false, bool isIftar = false}) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    final iconSize = isSmallScreen ? 16.0 : 18.0;
    final nameFontSize = isSmallScreen ? 10.0 : 11.0;
    final timeFontSize = isSmallScreen ? 13.0 : 14.0;
    final padding = isSmallScreen ? 4.0 : 6.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: padding),
      decoration: BoxDecoration(
        color: isSpecial
            ? const Color(0xFFDBEAFE)
            : isIftar
                ? const Color(0xFFFFF3E0)
                : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSpecial
              ? const Color(0xFF1E40AF)
              : isIftar
                  ? const Color(0xFFFF9800)
                  : Colors.transparent,
          width: 2,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: isSpecial
                  ? const Color(0xFF1E40AF)
                  : isIftar
                      ? const Color(0xFFFF9800)
                      : const Color(0xFF757575),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: nameFontSize,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: timeFontSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ],
        ),
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
                backgroundColor: const Color(0xFF1E40AF),
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
              color: Color(0xFF1E40AF),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Şehir Seçin',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Namaz vakitlerini görmek için şehrinizi seçin',
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
                backgroundColor: const Color(0xFF1E40AF),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sonraki vakte geri sayım — yalnızca bu widget saniyede bir setState yapar.
class ImsakiyeCountdownCard extends StatefulWidget {
  final PrayerTimes? todaysPrayerTimes;
  final List<PrayerTimes> prayerTimesList;

  const ImsakiyeCountdownCard({
    super.key,
    required this.todaysPrayerTimes,
    required this.prayerTimesList,
  });

  @override
  State<ImsakiyeCountdownCard> createState() => _ImsakiyeCountdownCardState();
}

class _ImsakiyeCountdownCardState extends State<ImsakiyeCountdownCard> {
  Timer? _timer;
  String _nextPrayerName = '';
  Duration _timeUntilNext = Duration.zero;
  bool _hasCountdown = false;

  static final List<(String label, String Function(PrayerTimes pt) timeOf)>
      _vakitSirasi = [
    ('İmsak', (pt) => pt.imsak),
    ('Güneş', (pt) => pt.gunes),
    ('Öğle', (pt) => pt.ogle),
    ('İkindi', (pt) => pt.ikindi),
    ('Akşam', (pt) => pt.aksam),
    ('Yatsı', (pt) => pt.yatsi),
  ];

  DateTime? _timeOnCalendarDay(String hhmm, DateTime day) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim());
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  void _updateCountdown() {
    if (!mounted) return;

    final now = DateTime.now();
    var name = '';
    var until = Duration.zero;
    var has = false;

    final todayPt = widget.todaysPrayerTimes;
    if (todayPt != null) {
      final cal =
          DateTime(todayPt.date.year, todayPt.date.month, todayPt.date.day);
      for (final entry in _vakitSirasi) {
        final t = _timeOnCalendarDay(entry.$2(todayPt), cal);
        if (t != null && now.isBefore(t)) {
          name = entry.$1;
          until = t.difference(now);
          has = true;
          break;
        }
      }
    }

    final tomorrow =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    if (!has) {
      for (final pt in widget.prayerTimesList) {
        final d = DateTime(pt.date.year, pt.date.month, pt.date.day);
        if (d.year == tomorrow.year &&
            d.month == tomorrow.month &&
            d.day == tomorrow.day) {
          final t = _timeOnCalendarDay(pt.imsak, tomorrow);
          if (t != null) {
            name = 'İmsak';
            until = t.difference(now);
            has = true;
          }
          break;
        }
      }
    }

    if (!has && todayPt != null) {
      final t = _timeOnCalendarDay(todayPt.imsak, tomorrow);
      if (t != null && now.isBefore(t)) {
        name = 'İmsak';
        until = t.difference(now);
        has = true;
      }
    }

    setState(() {
      _nextPrayerName = name;
      _timeUntilNext = until;
      _hasCountdown = has;
    });
  }

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ImsakiyeCountdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todaysPrayerTimes != widget.todaysPrayerTimes ||
        oldWidget.prayerTimesList != widget.prayerTimesList) {
      _updateCountdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _timeUntilNext.inHours;
    final m = _timeUntilNext.inMinutes.remainder(60);
    final s = _timeUntilNext.inSeconds.remainder(60);
    final displayText = _hasCountdown
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '--:--:--';

    final subtitle = _hasCountdown && _nextPrayerName.isNotEmpty
        ? '$_nextPrayerName vaktine kalan süre'
        : 'Sonraki vakte kalan süre';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
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
          const Icon(Icons.schedule_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            displayText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
