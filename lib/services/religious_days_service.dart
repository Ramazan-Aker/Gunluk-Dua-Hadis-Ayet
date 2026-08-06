import '../models/religious_day.dart';

/// Diyanet Vakit Hesaplama Başkanlığı'nın yayımladığı 2026-2028 takvimi.
/// Kaynak: https://vakithesaplama.diyanet.gov.tr/
class ReligiousDaysService {
  static final List<ReligiousDay> _allDays = [
    // 2026
    _day('mirac_2026', 'Miraç Kandili', 2026, 1, 15, IconType.moon, 26,
        'Recep 1447'),
    _day('berat_2026', 'Berat Kandili', 2026, 2, 2, IconType.moon, 14,
        'Şaban 1447'),
    _day('ramazan_2026', 'Ramazan Başlangıcı', 2026, 2, 19, IconType.calendar,
        1, 'Ramazan 1447'),
    _day('kadir_2026', 'Kadir Gecesi', 2026, 3, 16, IconType.star, 26,
        'Ramazan 1447'),
    _day('ramazan_arefe_2026', 'Ramazan Bayramı Arefesi', 2026, 3, 19,
        IconType.calendar, 29, 'Ramazan 1447'),
    _day('ramazan_bayrami_2026', 'Ramazan Bayramı', 2026, 3, 20,
        IconType.mosque, 1, 'Şevval 1447'),
    _day('kurban_arefe_2026', 'Kurban Bayramı Arefesi', 2026, 5, 26,
        IconType.calendar, 9, 'Zilhicce 1447'),
    _day('kurban_bayrami_2026', 'Kurban Bayramı', 2026, 5, 27, IconType.mosque,
        10, 'Zilhicce 1447'),
    _day('hicri_yilbasi_2026', 'Hicri Yılbaşı', 2026, 6, 16, IconType.calendar,
        1, 'Muharrem 1448'),
    _day('asure_2026', 'Aşure Günü', 2026, 6, 25, IconType.star, 10,
        'Muharrem 1448'),
    _day('mevlid_2026', 'Mevlid Kandili', 2026, 8, 24, IconType.moon, 11,
        'Rebiülevvel 1448'),
    _day('uc_aylar_2027', 'Üç Ayların Başlangıcı', 2026, 12, 10,
        IconType.calendar, 1, 'Recep 1448'),
    _day('regaib_2027', 'Regaib Kandili', 2026, 12, 10, IconType.moon, 1,
        'Recep 1448'),

    // 2027
    _day('mirac_2027', 'Miraç Kandili', 2027, 1, 4, IconType.moon, 26,
        'Recep 1448'),
    _day('berat_2027', 'Berat Kandili', 2027, 1, 22, IconType.moon, 14,
        'Şaban 1448'),
    _day('ramazan_2027', 'Ramazan Başlangıcı', 2027, 2, 8, IconType.calendar, 1,
        'Ramazan 1448'),
    _day('kadir_2027', 'Kadir Gecesi', 2027, 3, 5, IconType.star, 26,
        'Ramazan 1448'),
    _day('ramazan_arefe_2027', 'Ramazan Bayramı Arefesi', 2027, 3, 8,
        IconType.calendar, 29, 'Ramazan 1448'),
    _day('ramazan_bayrami_2027', 'Ramazan Bayramı', 2027, 3, 9, IconType.mosque,
        1, 'Şevval 1448'),
    _day('kurban_arefe_2027', 'Kurban Bayramı Arefesi', 2027, 5, 15,
        IconType.calendar, 9, 'Zilhicce 1448'),
    _day('kurban_bayrami_2027', 'Kurban Bayramı', 2027, 5, 16, IconType.mosque,
        10, 'Zilhicce 1448'),
    _day('hicri_yilbasi_2027', 'Hicri Yılbaşı', 2027, 6, 6, IconType.calendar,
        1, 'Muharrem 1449'),
    _day('asure_2027', 'Aşure Günü', 2027, 6, 15, IconType.star, 10,
        'Muharrem 1449'),
    _day('mevlid_2027', 'Mevlid Kandili', 2027, 8, 13, IconType.moon, 11,
        'Rebiülevvel 1449'),
    _day('uc_aylar_2028', 'Üç Ayların Başlangıcı', 2027, 11, 29,
        IconType.calendar, 1, 'Recep 1449'),
    _day('regaib_2028', 'Regaib Kandili', 2027, 12, 2, IconType.moon, 4,
        'Recep 1449'),
    _day('mirac_2028', 'Miraç Kandili', 2027, 12, 24, IconType.moon, 26,
        'Recep 1449'),

    // 2028
    _day('berat_2028', 'Berat Kandili', 2028, 1, 11, IconType.moon, 14,
        'Şaban 1449'),
    _day('ramazan_2028', 'Ramazan Başlangıcı', 2028, 1, 28, IconType.calendar,
        1, 'Ramazan 1449'),
    _day('kadir_2028', 'Kadir Gecesi', 2028, 2, 22, IconType.star, 26,
        'Ramazan 1449'),
    _day('ramazan_arefe_2028', 'Ramazan Bayramı Arefesi', 2028, 2, 25,
        IconType.calendar, 29, 'Ramazan 1449'),
    _day('ramazan_bayrami_2028', 'Ramazan Bayramı', 2028, 2, 26,
        IconType.mosque, 1, 'Şevval 1449'),
    _day('kurban_arefe_2028', 'Kurban Bayramı Arefesi', 2028, 5, 4,
        IconType.calendar, 9, 'Zilhicce 1449'),
    _day('kurban_bayrami_2028', 'Kurban Bayramı', 2028, 5, 5, IconType.mosque,
        10, 'Zilhicce 1449'),
    _day('hicri_yilbasi_2028', 'Hicri Yılbaşı', 2028, 5, 25, IconType.calendar,
        1, 'Muharrem 1450'),
    _day('asure_2028', 'Aşure Günü', 2028, 6, 3, IconType.star, 10,
        'Muharrem 1450'),
    _day('mevlid_2028', 'Mevlid Kandili', 2028, 8, 2, IconType.moon, 11,
        'Rebiülevvel 1450'),
    _day('uc_aylar_2029', 'Üç Ayların Başlangıcı', 2028, 11, 18,
        IconType.calendar, 1, 'Recep 1450'),
    _day('regaib_2029', 'Regaib Kandili', 2028, 11, 23, IconType.moon, 6,
        'Recep 1450'),
    _day('mirac_2029', 'Miraç Kandili', 2028, 12, 13, IconType.moon, 26,
        'Recep 1450'),
    _day('berat_2029', 'Berat Kandili', 2028, 12, 30, IconType.moon, 14,
        'Şaban 1450'),
  ];

  static ReligiousDay _day(
    String id,
    String name,
    int year,
    int month,
    int day,
    IconType icon,
    int hijriDay,
    String hijriMonth,
  ) =>
      ReligiousDay(
        id: id,
        name: name,
        date: DateTime(year, month, day),
        iconType: icon,
        hijriDay: hijriDay,
        hijriMonth: hijriMonth,
      );

  List<ReligiousDay> getAllDays() => List<ReligiousDay>.from(_allDays)
    ..sort((a, b) => a.date.compareTo(b.date));

  List<ReligiousDay> getUpcomingDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _allDays.where((day) => !day.date.isBefore(today)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<ReligiousDay> getPassedDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _allDays.where((day) => day.date.isBefore(today)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}
