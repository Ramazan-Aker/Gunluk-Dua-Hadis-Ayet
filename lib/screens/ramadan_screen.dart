import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/turkish_city.dart';
import '../models/prayer_times.dart';
import '../services/ramadan_api_service.dart';
import '../services/firebase_service.dart' show FirebaseService, AnalyticsEvents, AnalyticsParams;
import '../services/ad_service.dart';

/// Ramadan Prayer Times Screen
/// Shows countdown to sahur, today's prayer times, and full month schedule
class RamadanScreen extends StatefulWidget {
  const RamadanScreen({Key? key}) : super(key: key);

  @override
  State<RamadanScreen> createState() => _RamadanScreenState();
}

class _RamadanScreenState extends State<RamadanScreen> {
  final RamadanApiService _apiService = RamadanApiService();
  final ScrollController _imsakiyeScrollController = ScrollController(); // İmsakiye listesi için iç scroll
  
  TurkishCity? _selectedCity;
  List<PrayerTimes> _prayerTimesList = [];
  PrayerTimes? _todaysPrayerTimes;
  
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
    } catch (e) {
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
                color: Color(0xFF0F766E),
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
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF0D9488)),
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
                            color: Color(0xFF0D9488),
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
        targetOffset.clamp(0.0, _imsakiyeScrollController.position.maxScrollExtent),
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
          backgroundColor: Color(0xFF14B8A6),
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
              colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
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
            colors: [Color(0xFFF0FDFA), Color(0xFFCCFBF1)],
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
  /// 1) Sayfa scroll: Üst kısım (countdown + bugünkü vakitler) kayar - imsakiye üstü ekran ortasına gelebilir
  /// 2) İmsakiye scroll: Liste kendi içinde kaydırılarak en alta ulaşılır
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
            const SizedBox(height: 16),
            if (_todaysPrayerTimes != null) _buildTodaysPrayerTimesCard(),
            const SizedBox(height: 16),
            _buildEmptyImsakiyeCard(),
          ],
        ),
      );
    }

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverPersistentHeader(
          pinned: true,
          delegate: _ImsakiyeHeaderDelegate(
            minExtent: 180,
            maxExtent: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ImsakiyeCountdownCard(
                  todaysPrayerTimes: _todaysPrayerTimes,
                  prayerTimesList: _prayerTimesList,
                ),
                const SizedBox(height: 16),
                if (_todaysPrayerTimes != null) _buildTodaysPrayerTimesCard(),
                if (_todaysPrayerTimes != null) const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
      body: Builder(
        builder: (context) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildImsakiyeHeaderPart(),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final horizontalPadding = MediaQuery.of(context).size.width < 360 ? 12.0 : 20.0;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: Colors.white,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        child: _buildTableRow(_prayerTimesList[index], index),
                      ),
                    );
                  },
                  childCount: _prayerTimesList.length,
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImsakiyeHeaderPart() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.of(context).size.width < 360 ? 12 : 20,
              20,
              MediaQuery.of(context).size.width < 360 ? 12 : 20,
              16,
            ),
            child: Text(
              '${_selectedCity?.name ?? ''} İmsakiye ${_apiService.getCurrentRamadanYear()}',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 360 ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F766E),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width < 360 ? 12 : 20,
            ),
            child: _buildTableHeader(),
          ),
          const Divider(height: 1, thickness: 1),
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
          'İmsakiye verisi yüklenemedi',
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
    
    final cardPadding = isSmallScreen ? 10.0 : 16.0;
    final titleFontSize = isSmallScreen ? 15.0 : 17.0;
    final spacing = isSmallScreen ? 10.0 : 16.0;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
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
              color: const Color(0xFF0F766E),
            ),
          ),
          SizedBox(height: spacing),
          // Column+Row - overflow önlemek için GridView yerine (sabit aspect ratio sorun çıkarıyordu)
          Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildPrayerTimeItem(context, 'İmsak', pt.imsak, Icons.bedtime, isSpecial: true)),
                    SizedBox(width: isSmallScreen ? 8 : 10),
                    Expanded(child: _buildPrayerTimeItem(context, 'Güneş', pt.gunes, Icons.wb_sunny)),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 8 : 10),
                Row(
                  children: [
                    Expanded(child: _buildPrayerTimeItem(context, 'Öğle', pt.ogle, Icons.light_mode)),
                    SizedBox(width: isSmallScreen ? 8 : 10),
                    Expanded(child: _buildPrayerTimeItem(context, 'İkindi', pt.ikindi, Icons.brightness_6)),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 8 : 10),
                Row(
                  children: [
                    Expanded(child: _buildPrayerTimeItem(context, 'Akşam', pt.aksam, Icons.nightlight, isIftar: true)),
                    SizedBox(width: isSmallScreen ? 8 : 10),
                    Expanded(child: _buildPrayerTimeItem(context, 'Yatsı', pt.yatsi, Icons.dark_mode)),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Build individual prayer time item - responsive, overflow-safe
  Widget _buildPrayerTimeItem(BuildContext context, String name, String time, IconData icon, {bool isSpecial = false, bool isIftar = false}) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    final iconSize = isSmallScreen ? 16.0 : 18.0;
    final nameFontSize = isSmallScreen ? 10.0 : 11.0;
    final timeFontSize = isSmallScreen ? 13.0 : 14.0;
    final padding = isSmallScreen ? 4.0 : 6.0;
    
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: padding),
        decoration: BoxDecoration(
          color: isSpecial 
              ? const Color(0xFFCCFBF1) 
              : isIftar 
                  ? const Color(0xFFFFF3E0)
                  : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSpecial 
                ? const Color(0xFF0D9488)
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
                    ? const Color(0xFF0D9488)
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
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  }

  /// Build table header - responsive padding
  Widget _buildTableHeader() {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 6 : 8,
        horizontal: isSmallScreen ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D9488).withValues(alpha: 0.1),
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

  /// Build header cell - responsive font size
  Widget _buildHeaderCell(String text, {int flex = 1}) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: isSmallScreen ? 9 : 11,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F766E),
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Build table row - shows "X. Gün" and date, past days included, today highlighted
  Widget _buildTableRow(PrayerTimes prayerTime, int index) {
    final isToday = prayerTime.isToday;
    final isOddRow = index % 2 == 1;
    final ramadanDayNum = index + 1;
    final dateColumnText = '${ramadanDayNum}. Gün\n${prayerTime.fullDateLabel}';

    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 6 : 8,
        horizontal: isSmallScreen ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isToday
            ? const Color(0xFFCCFBF1)
            : isOddRow
                ? const Color(0xFFF5F5F5)
                : Colors.white,
        border: Border(
          left: isToday
              ? const BorderSide(color: Color(0xFF0D9488), width: 4)
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

  /// Build data cell - responsive font size
  Widget _buildDataCell(String text,
      {int flex = 1, bool isBold = false, bool isMultiline = false}) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    final fontSize = isSmallScreen 
        ? (isMultiline ? 9.0 : 10.0) 
        : (isMultiline ? 10.0 : 11.0);
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: isBold ? const Color(0xFF0F766E) : const Color(0xFF2C3E50),
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
                backgroundColor: const Color(0xFF0D9488),
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
              color: Color(0xFF0D9488),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Şehir Seçin',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
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
                backgroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Countdown kartı - kendi timer'ı ile sadece kendi içeriğini günceller.
/// Ana ekran her saniye setState yapmadığı için imsakiye scroll kasması ortadan kalkar.
class ImsakiyeCountdownCard extends StatefulWidget {
  final PrayerTimes? todaysPrayerTimes;
  final List<PrayerTimes> prayerTimesList;

  const ImsakiyeCountdownCard({
    Key? key,
    required this.todaysPrayerTimes,
    required this.prayerTimesList,
  }) : super(key: key);

  @override
  State<ImsakiyeCountdownCard> createState() => _ImsakiyeCountdownCardState();
}

class _ImsakiyeCountdownCardState extends State<ImsakiyeCountdownCard> {
  Timer? _timer;
  String _mode = 'sahur';
  Duration _timeUntilSahur = Duration.zero;
  Duration _timeUntilIftar = Duration.zero;

  void _updateCountdown() {
    if (!mounted) return;

    final now = DateTime.now();
    DateTime? sahurTime;
    DateTime? iftarTime;

    if (widget.todaysPrayerTimes != null) {
      final imsakParts = widget.todaysPrayerTimes!.imsak.split(':');
      final aksamParts = widget.todaysPrayerTimes!.aksam.split(':');
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

    if (sahurTime != null && iftarTime != null) {
      if (now.isBefore(sahurTime)) {
        mode = 'sahur';
        timeUntilSahur = sahurTime.difference(now);
      } else if (now.isBefore(iftarTime)) {
        mode = 'iftar';
        timeUntilIftar = iftarTime.difference(now);
      } else {
        mode = 'iftarVakti';
        final tomorrow = now.add(const Duration(days: 1));
        for (var pt in widget.prayerTimesList) {
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
            }
            break;
          }
        }
      }
    }

    setState(() {
      _mode = mode;
      _timeUntilSahur = timeUntilSahur;
      _timeUntilIftar = timeUntilIftar;
    });
  }

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
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
    String title;
    IconData icon;
    String displayText;

    switch (_mode) {
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
          colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
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
}

/// SliverPersistentHeader delegate - countdown ve bugünkü vakitler alanı
/// maxExtent'tan minExtent'a küçülür; imsakiye üstü ekran ortasına gelebilir
class _ImsakiyeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double _minExtent;
  final double _maxExtent;
  final Widget child;

  _ImsakiyeHeaderDelegate({
    required double minExtent,
    required double maxExtent,
    required this.child,
  })  : _minExtent = minExtent,
        _maxExtent = maxExtent;

  @override
  double get minExtent => _minExtent;

  @override
  double get maxExtent => _maxExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final currentExtent = (_maxExtent - shrinkOffset).clamp(_minExtent, _maxExtent);
    return SizedBox(
      height: currentExtent,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: _maxExtent,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ImsakiyeHeaderDelegate oldDelegate) =>
      _minExtent != oldDelegate._minExtent ||
      _maxExtent != oldDelegate._maxExtent;
}
