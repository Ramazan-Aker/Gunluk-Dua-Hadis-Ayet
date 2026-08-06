import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/turkish_city.dart';
import '../models/prayer_times.dart';
import '../services/ramadan_api_service.dart';
import '../services/firebase_service.dart'
    show FirebaseService, AnalyticsEvents, AnalyticsParams;
import '../services/notification_service.dart';
import '../services/prayer_notification_service.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';

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
  final List<TurkishCity> _savedCities = [];
  int _activeCityIndex = 0;
  List<PrayerTimes> _prayerTimesList = [];
  PrayerTimes? _todaysPrayerTimes;
  bool _isShowingRamadan = false;
  int? _displayRamadanYear;
  bool _showCalendar = false;

  bool _isLoading = true;
  String? _errorMessage;
  final PrayerNotificationService _prayerNotifications =
      PrayerNotificationService();
  bool _prayerNotificationsEnabled = false;
  int _notificationLeadMinutes = 10;

  // SharedPreferences keys
  static const String _keySelectedCityId = 'ramadan_selected_city_id';
  static const String _keySelectedCityName = 'ramadan_selected_city_name';
  static const String _keySavedCities = 'ramadan_saved_cities_v2';
  static const String _keyActiveCityIndex = 'ramadan_active_city_index_v2';

  /// Valid ezanvakti state ID range (500-580)
  static bool _isValidStateId(String id) {
    final n = int.tryParse(id);
    return n != null && n >= 500 && n <= 580;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedCity();
    _loadNotificationPreference();

    // Log screen view
    FirebaseService.logScreenView(screenName: AnalyticsEvents.screenRamadan);
    FirebaseService.logEvent(name: AnalyticsEvents.ramadanScreenViewed);
  }

  Future<void> _loadNotificationPreference() async {
    final enabled = await _prayerNotifications.isEnabled();
    final lead = await _prayerNotifications.leadMinutes();
    if (mounted) {
      setState(() {
        _prayerNotificationsEnabled = enabled;
        _notificationLeadMinutes = lead;
      });
    }
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
      final savedJson = prefs.getString(_keySavedCities);
      if (savedJson != null) {
        final decoded = jsonDecode(savedJson) as List<dynamic>;
        _savedCities.addAll(
          decoded
              .map((item) => TurkishCity.fromJson(item as Map<String, dynamic>))
              .where((city) => _isValidStateId(city.id))
              .take(3),
        );
      }

      // Tek şehir kullanan eski sürümden geçiş.
      if (_savedCities.isEmpty) {
        final cityId = prefs.getString(_keySelectedCityId);
        final cityName = prefs.getString(_keySelectedCityName);
        if (cityId != null && cityName != null && _isValidStateId(cityId)) {
          _savedCities
              .add(TurkishCity(id: cityId, name: cityName, country: 'Türkiye'));
        }
      }

      if (_savedCities.isNotEmpty) {
        _activeCityIndex = (prefs.getInt(_keyActiveCityIndex) ?? 0)
            .clamp(0, _savedCities.length - 1);
        setState(() => _selectedCity = _savedCities[_activeCityIndex]);
        await _persistCities();
        await _loadPrayerTimes();
      } else {
        setState(() => _isLoading = false);
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
      await _persistCities();

      // Log city selection
      FirebaseService.logEvent(
        name: AnalyticsEvents.ramadanCitySelected,
        parameters: {AnalyticsParams.cityName: city.name},
      );
    } catch (e) {}
  }

  Future<void> _persistCities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keySavedCities,
      jsonEncode(_savedCities.map((city) => city.toJson()).toList()),
    );
    await prefs.setInt(_keyActiveCityIndex, _activeCityIndex);
    if (_selectedCity != null) {
      await prefs.setString(_keySelectedCityId, _selectedCity!.id);
      await prefs.setString(_keySelectedCityName, _selectedCity!.name);
    } else {
      await prefs.remove(_keySelectedCityId);
      await prefs.remove(_keySelectedCityName);
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

      if (_prayerNotificationsEnabled) {
        unawaited(_reschedulePrayerNotifications());
      }

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
  String _normalizeCitySearch(String value) => value
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  Future<void> _showCitySelectionDialog() async {
    final allCities = _apiService.getAllTurkishCities();
    String searchQuery = '';

    await showDialog(
      context: context,
      barrierDismissible: _savedCities.isNotEmpty,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final normalizedQuery = _normalizeCitySearch(searchQuery);
          final filteredCities = searchQuery.isEmpty
              ? allCities
              : allCities
                  .where((city) => _normalizeCitySearch(city['name']!)
                      .contains(normalizedQuery))
                  .toList();

          return Dialog(
            backgroundColor: AppTheme.ivory,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: MediaQuery.sizeOf(context).height * .82,
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                    color: AppTheme.navy,
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppTheme.mint.withValues(alpha: .16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppTheme.mint,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Şehir Seçin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _savedCities.length < 3
                                    ? 'En fazla 3 şehir ekleyebilirsiniz'
                                    : 'Yeni seçim aktif şehrin yerini alır',
                                style: const TextStyle(
                                  color: Color(0xFFD6E3EA),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_savedCities.isNotEmpty)
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            tooltip: 'Kapat',
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Şehir ara...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppTheme.emerald,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppTheme.outline.withValues(alpha: .45),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppTheme.emerald,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (value) =>
                          setDialogState(() => searchQuery = value),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Row(
                      children: [
                        Text(
                          '${filteredCities.length} şehir',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_savedCities.length}/3 kayıtlı',
                          style: const TextStyle(
                            color: AppTheme.emerald,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filteredCities.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_off_outlined,
                                    color: AppTheme.gold, size: 42),
                                SizedBox(height: 10),
                                Text('Şehir bulunamadı',
                                    style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                            itemCount: filteredCities.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 7),
                            itemBuilder: (context, index) {
                              final city = filteredCities[index];
                              final saved = _savedCities
                                  .any((item) => item.id == city['id']);
                              final active = _selectedCity?.id == city['id'];
                              return Material(
                                color: active ? AppTheme.mint : Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                child: InkWell(
                                  onTap: () => _onCitySelected(
                                    dialogContext,
                                    city['name']!,
                                    city['id']!,
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: active
                                            ? AppTheme.emerald
                                            : AppTheme.outline
                                                .withValues(alpha: .34),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: active
                                                ? Colors.white
                                                    .withValues(alpha: .72)
                                                : AppTheme.mint
                                                    .withValues(alpha: .56),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.location_city_rounded,
                                            color: AppTheme.emerald,
                                            size: 21,
                                          ),
                                        ),
                                        const SizedBox(width: 13),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                city['name']!,
                                                style: const TextStyle(
                                                  color: AppTheme.navy,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const Text(
                                                'Türkiye',
                                                style: TextStyle(
                                                  color: AppTheme.textMuted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (saved)
                                          Icon(
                                            active
                                                ? Icons.check_circle_rounded
                                                : Icons.bookmark_rounded,
                                            color: active
                                                ? AppTheme.emerald
                                                : AppTheme.gold,
                                            size: 22,
                                          )
                                        else
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: AppTheme.textMuted,
                                          ),
                                      ],
                                    ),
                                  ),
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

    final existingIndex = _savedCities.indexWhere((city) => city.id == stateId);
    setState(() {
      if (existingIndex >= 0) {
        _activeCityIndex = existingIndex;
      } else if (_savedCities.length < 3) {
        _savedCities.add(cityToUse);
        _activeCityIndex = _savedCities.length - 1;
      } else {
        _savedCities[_activeCityIndex] = cityToUse;
      }
      _selectedCity = _savedCities[_activeCityIndex];
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

  Future<void> _selectCity(int index) async {
    if (index < 0 ||
        index >= _savedCities.length ||
        index == _activeCityIndex) {
      return;
    }
    setState(() {
      _activeCityIndex = index;
      _selectedCity = _savedCities[index];
    });
    await _persistCities();
    await _loadPrayerTimes();
  }

  Future<void> _removeCity(int index) async {
    if (index < 0 || index >= _savedCities.length) {
      return;
    }
    final selectedCityId = _selectedCity?.id;
    setState(() {
      _savedCities.removeAt(index);
      if (_savedCities.isEmpty) {
        _activeCityIndex = 0;
        _selectedCity = null;
        _prayerTimesList = [];
        _todaysPrayerTimes = null;
        _isLoading = false;
      } else {
        final retainedIndex = _savedCities
            .indexWhere((savedCity) => savedCity.id == selectedCityId);
        _activeCityIndex = retainedIndex >= 0
            ? retainedIndex
            : index.clamp(0, _savedCities.length - 1);
        _selectedCity = _savedCities[_activeCityIndex];
      }
    });
    await _persistCities();
    if (_selectedCity == null) {
      if (_prayerNotificationsEnabled) {
        await _prayerNotifications.disable();
        if (mounted) setState(() => _prayerNotificationsEnabled = false);
      }
      if (mounted) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _showCitySelectionDialog());
      }
    } else {
      await _loadPrayerTimes();
    }
  }

  Future<void> _confirmRemoveCity(int index) async {
    if (index < 0 || index >= _savedCities.length) return;
    final city = _savedCities[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şehri kaldır'),
        content: Text('${city.name} kayıtlı şehirlerden kaldırılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _removeCity(index);
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

  Future<void> _reschedulePrayerNotifications() async {
    final city = _selectedCity;
    if (!_prayerNotificationsEnabled ||
        city == null ||
        _prayerTimesList.isEmpty) {
      return;
    }
    await _prayerNotifications.schedule(
      city: city,
      prayerTimes: _prayerTimesList,
      leadMinutes: _notificationLeadMinutes,
    );
  }

  Future<void> _configurePrayerNotifications() async {
    if (_prayerNotificationsEnabled) {
      await _prayerNotifications.disable();
      if (mounted) setState(() => _prayerNotificationsEnabled = false);
      return;
    }

    var selectedLead = _notificationLeadMinutes;
    final lead = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Namaz vakti bildirimi',
                  style: TextStyle(
                      color: AppTheme.navy,
                      fontSize: 21,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('${_selectedCity?.name ?? ''} için ne zaman haber verilsin?',
                  style: const TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setSheetState) => Column(
                  children: [0, 10, 15, 30].map((minutes) {
                    return RadioListTile<int>(
                      value: minutes,
                      groupValue: selectedLead,
                      activeColor: AppTheme.emerald,
                      title: Text(minutes == 0
                          ? 'Namaz vakti geldiğinde'
                          : '$minutes dakika önce'),
                      onChanged: (value) =>
                          setSheetState(() => selectedLead = value ?? 10),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedLead),
                  child: const Text('Bildirimleri Aç'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (lead == null || _selectedCity == null) return;
    final permission = await NotificationService().requestPermission();
    if (!permission || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bildirim izni verilmedi.')));
      }
      return;
    }
    await _prayerNotifications.enableAndSchedule(
      city: _selectedCity!,
      prayerTimes: _prayerTimesList,
      leadMinutes: lead,
    );
    if (!mounted) return;
    setState(() {
      _prayerNotificationsEnabled = true;
      _notificationLeadMinutes = lead;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Namaz bildirimleri açıldı.')),
    );
  }

  Widget _buildCityTabs() {
    if (_savedCities.isEmpty) return const SizedBox.shrink();
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ..._savedCities.asMap().entries.map((entry) {
              final selected = entry.key == _activeCityIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InputChip(
                  selected: selected,
                  onSelected: (_) => _selectCity(entry.key),
                  onDeleted: () => _confirmRemoveCity(entry.key),
                  deleteButtonTooltipMessage:
                      '${entry.value.name} şehrini kaldır',
                  deleteIcon: Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: selected ? Colors.white70 : AppTheme.textMuted,
                  ),
                  avatar: Icon(Icons.location_on_outlined,
                      size: 18,
                      color: selected ? Colors.white : AppTheme.emerald),
                  label: Text(entry.value.name),
                  selectedColor: AppTheme.navy,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                      color: selected ? Colors.white : AppTheme.navy,
                      fontWeight: FontWeight.w600),
                  side: BorderSide(
                      color: selected
                          ? AppTheme.navy
                          : AppTheme.outline.withValues(alpha: .45)),
                  shape: const StadiumBorder(),
                ),
              );
            }),
            if (_savedCities.length < 3)
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Şehir ekle'),
                onPressed: _showCitySelectionDialog,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.menu_rounded),
        title: const Text('Her Gün İslam', style: TextStyle(fontSize: 24)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _prayerNotificationsEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: _prayerNotificationsEnabled
                  ? AppTheme.emerald
                  : AppTheme.navy,
            ),
            onPressed:
                _selectedCity == null ? null : _configurePrayerNotifications,
            tooltip: _prayerNotificationsEnabled
                ? 'Namaz bildirimlerini kapat'
                : 'Namaz bildirimlerini aç',
          ),
          if (_selectedCity != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refreshPrayerTimes,
              tooltip: 'Yenile',
            ),
        ],
      ),
      body: Container(
        color: AppTheme.ivory,
        child: Column(
          children: [
            _buildCityTabs(),
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
          _buildCalendarLauncher(),
        ],
      ),
    );
  }

  Widget _buildCalendarLauncher() {
    return Column(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _showCalendar = !_showCalendar),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.ambientShadow,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined,
                      color: AppTheme.navy, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Aylık İmsakiye',
                            style: TextStyle(
                                color: AppTheme.navy,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(_scheduleTitle,
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showCalendar ? .25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showCalendar) ...[
          const SizedBox(height: 12),
          _buildImsakiyeCalendar(),
        ],
      ],
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

    final cardPadding = isSmallScreen ? 10.0 : 14.0;
    final activePrayer = _nextPrayerLabelFor(pt);

    return Container(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                      child: _buildPrayerTimeItem(
                          context, 'İmsak', pt.imsak, Icons.bedtime,
                          isActive: activePrayer == 'İmsak')),
                  SizedBox(width: isSmallScreen ? 8 : 10),
                  Expanded(
                      child: _buildPrayerTimeItem(
                          context, 'Güneş', pt.gunes, Icons.wb_sunny,
                          isActive: activePrayer == 'Güneş')),
                ],
              ),
              SizedBox(height: isSmallScreen ? 8 : 10),
              Row(
                children: [
                  Expanded(
                      child: _buildPrayerTimeItem(
                          context, 'Öğle', pt.ogle, Icons.light_mode,
                          isActive: activePrayer == 'Öğle')),
                  SizedBox(width: isSmallScreen ? 8 : 10),
                  Expanded(
                      child: _buildPrayerTimeItem(
                          context, 'İkindi', pt.ikindi, Icons.brightness_6,
                          isActive: activePrayer == 'İkindi')),
                ],
              ),
              SizedBox(height: isSmallScreen ? 8 : 10),
              Row(
                children: [
                  Expanded(
                      child: _buildPrayerTimeItem(
                          context, 'Akşam', pt.aksam, Icons.nightlight,
                          isActive: activePrayer == 'Akşam')),
                  SizedBox(width: isSmallScreen ? 8 : 10),
                  Expanded(
                      child: _buildPrayerTimeItem(
                          context, 'Yatsı', pt.yatsi, Icons.dark_mode,
                          isActive: activePrayer == 'Yatsı')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _nextPrayerLabelFor(PrayerTimes pt) {
    final now = DateTime.now();
    final entries = <(String, String)>[
      ('İmsak', pt.imsak),
      ('Güneş', pt.gunes),
      ('Öğle', pt.ogle),
      ('İkindi', pt.ikindi),
      ('Akşam', pt.aksam),
      ('Yatsı', pt.yatsi),
    ];
    for (final entry in entries) {
      final parts = entry.$2.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;
      final at = DateTime(now.year, now.month, now.day, hour, minute);
      if (now.isBefore(at)) return entry.$1;
    }
    return 'İmsak';
  }

  Widget _buildPrayerTimeItem(
      BuildContext context, String name, String time, IconData icon,
      {bool isActive = false}) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    final iconSize = isSmallScreen ? 16.0 : 18.0;
    final nameFontSize = isSmallScreen ? 10.0 : 11.0;
    final timeFontSize = isSmallScreen ? 13.0 : 14.0;
    final padding = isSmallScreen ? 4.0 : 6.0;

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: padding),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.mint : AppTheme.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? const Border(left: BorderSide(color: AppTheme.emerald, width: 4))
            : null,
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
              color: isActive ? AppTheme.emerald : AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(name,
                style: TextStyle(
                    fontSize: nameFontSize,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppTheme.emerald : AppTheme.text)),
            const SizedBox(width: 6),
            Text(
              time,
              style: TextStyle(
                fontSize: timeFontSize,
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
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
  String _nextPrayerClock = '';

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
    var clock = '';

    final todayPt = widget.todaysPrayerTimes;
    if (todayPt != null) {
      final cal =
          DateTime(todayPt.date.year, todayPt.date.month, todayPt.date.day);
      for (final entry in _vakitSirasi) {
        final t = _timeOnCalendarDay(entry.$2(todayPt), cal);
        if (t != null && now.isBefore(t)) {
          name = entry.$1;
          clock = entry.$2(todayPt);
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
            clock = pt.imsak;
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
        clock = todayPt.imsak;
        until = t.difference(now);
        has = true;
      }
    }

    setState(() {
      _nextPrayerName = name;
      _timeUntilNext = until;
      _hasCountdown = has;
      _nextPrayerClock = clock;
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
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Column(
        children: [
          const Icon(Icons.nightlight_round, color: AppTheme.mint, size: 32),
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
              fontSize: 46,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          if (_hasCountdown && _nextPrayerClock.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Sıradaki: $_nextPrayerName ($_nextPrayerClock)',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
