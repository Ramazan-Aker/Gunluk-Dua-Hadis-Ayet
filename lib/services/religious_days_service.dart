import '../models/religious_day.dart';

/// Diyanet takvimine göre dini günler (2026 ve 2027)
/// Kaynak: Diyanet İşleri Başkanlığı resmi takvim
class ReligiousDaysService {
  static final ReligiousDaysService _instance = ReligiousDaysService._internal();
  factory ReligiousDaysService() => _instance;
  ReligiousDaysService._internal();

  static List<ReligiousDay> get _allDays => [
    // 2025 (Aralık - 2026 dönemine ait)
    ReligiousDay(
      id: 'regaib_2025',
      name: 'Regaib Kandili',
      date: DateTime(2025, 12, 25),
      iconType: IconType.moon,
      hijriDay: 7,
      hijriMonth: 'Receb',
    ),
    // 2026
    ReligiousDay(
      id: 'uc_aylar_2026',
      name: 'Üç Aylar Başlangıcı',
      date: DateTime(2025, 12, 21),
      iconType: IconType.calendar,
      hijriDay: 1,
      hijriMonth: 'Receb',
    ),
    ReligiousDay(
      id: 'mirac_2026',
      name: 'Mirac Kandili',
      date: DateTime(2026, 1, 15),
      iconType: IconType.moon,
      hijriDay: 27,
      hijriMonth: 'Receb',
    ),
    ReligiousDay(
      id: 'berat_2026',
      name: 'Berat Kandili',
      date: DateTime(2026, 2, 2),
      iconType: IconType.moon,
      hijriDay: 15,
      hijriMonth: 'Şaban',
    ),
    ReligiousDay(
      id: 'ramazan_2026',
      name: 'Ramazan Başlangıcı',
      date: DateTime(2026, 2, 19),
      iconType: IconType.mosque,
      hijriDay: 1,
      hijriMonth: 'Ramazan',
    ),
    ReligiousDay(
      id: 'kadir_2026',
      name: 'Kadir Gecesi',
      date: DateTime(2026, 3, 16),
      iconType: IconType.star,
      hijriDay: 27,
      hijriMonth: 'Ramazan',
    ),
    ReligiousDay(
      id: 'ramazan_bayrami_2026',
      name: 'Ramazan Bayramı',
      date: DateTime(2026, 3, 20),
      iconType: IconType.mosque,
      hijriDay: 1,
      hijriMonth: 'Şevval',
    ),
    ReligiousDay(
      id: 'kurban_bayrami_2026',
      name: 'Kurban Bayramı',
      date: DateTime(2026, 5, 27),
      iconType: IconType.mosque,
      hijriDay: 10,
      hijriMonth: 'Zilhicce',
    ),
    ReligiousDay(
      id: 'hicri_yilbasi_2026',
      name: 'Hicri Yılbaşı',
      date: DateTime(2026, 6, 16),
      iconType: IconType.calendar,
      hijriDay: 1,
      hijriMonth: 'Muharrem',
    ),
    ReligiousDay(
      id: 'asure_2026',
      name: 'Aşure Günü',
      date: DateTime(2026, 6, 25),
      iconType: IconType.calendar,
      hijriDay: 10,
      hijriMonth: 'Muharrem',
    ),
    ReligiousDay(
      id: 'mevlid_2026',
      name: 'Mevlid Kandili',
      date: DateTime(2026, 8, 24),
      iconType: IconType.moon,
      hijriDay: 12,
      hijriMonth: 'Rebiülevvel',
    ),
    // 2027
    ReligiousDay(
      id: 'regaib_2027',
      name: 'Regaib Kandili',
      date: DateTime(2026, 12, 2),
      iconType: IconType.moon,
    ),
    ReligiousDay(
      id: 'mirac_2027',
      name: 'Mirac Kandili',
      date: DateTime(2027, 1, 4),
      iconType: IconType.moon,
    ),
    ReligiousDay(
      id: 'berat_2027',
      name: 'Berat Kandili',
      date: DateTime(2027, 1, 22),
      iconType: IconType.moon,
    ),
    ReligiousDay(
      id: 'ramazan_2027',
      name: 'Ramazan Başlangıcı',
      date: DateTime(2027, 2, 8),
      iconType: IconType.mosque,
    ),
    ReligiousDay(
      id: 'kadir_2027',
      name: 'Kadir Gecesi',
      date: DateTime(2027, 3, 5),
      iconType: IconType.star,
    ),
    ReligiousDay(
      id: 'ramazan_bayrami_2027',
      name: 'Ramazan Bayramı',
      date: DateTime(2027, 3, 8),
      iconType: IconType.mosque,
    ),
    ReligiousDay(
      id: 'kurban_bayrami_2027',
      name: 'Kurban Bayramı',
      date: DateTime(2027, 5, 17),
      iconType: IconType.mosque,
    ),
    ReligiousDay(
      id: 'mevlid_2027',
      name: 'Mevlid Kandili',
      date: DateTime(2027, 8, 13),
      iconType: IconType.moon,
    ),
  ];

  /// Tüm dini günleri tarihe göre sıralı getir (geçmiş + gelecek)
  List<ReligiousDay> getAllDays() {
    final list = List<ReligiousDay>.from(_allDays);
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  /// Gelecek günleri getir (bugün dahil)
  List<ReligiousDay> getUpcomingDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _allDays
        .where((d) {
          final dDate = DateTime(d.date.year, d.date.month, d.date.day);
          return !dDate.isBefore(today);
        })
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}
