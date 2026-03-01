/// Model for Islamic religious days (Diyanet takvimi)
class ReligiousDay {
  final String id;
  final String name;
  final DateTime date;
  final IconType iconType;
  final int? hijriDay;
  final String? hijriMonth;

  ReligiousDay({
    required this.id,
    required this.name,
    required this.date,
    this.iconType = IconType.moon,
    this.hijriDay,
    this.hijriMonth,
  });

  /// Gün sayısı: pozitif = kalan, negatif = geçen, 0 = bugün
  int get daysFromNow {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  String get countdownText {
    final days = daysFromNow;
    if (days < 0) return '${-days} gün önce geçti';
    if (days == 0) return 'Bugün';
    if (days == 1) return 'Yarın';
    return '$days gün kaldı';
  }

  String get formattedDate {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

enum IconType {
  moon,      // Kandiller
  mosque,    // Bayramlar, Ramazan
  star,      // Kadir Gecesi
  calendar,  // Üç aylar, Hicri yılbaşı
}
