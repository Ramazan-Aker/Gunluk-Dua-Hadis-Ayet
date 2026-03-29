/// Model class for daily prayer times
/// Used in Ramadan prayer times feature
class PrayerTimes {
  final DateTime date;
  final String imsak;   // Sahur (Fajr start time)
  final String gunes;   // Sunrise
  final String ogle;    // Dhuhr (Noon)
  final String ikindi;  // Asr (Afternoon)
  final String aksam;   // Maghrib (Iftar/Evening)
  final String yatsi;   // Isha (Night)

  PrayerTimes({
    required this.date,
    required this.imsak,
    required this.gunes,
    required this.ogle,
    required this.ikindi,
    required this.aksam,
    required this.yatsi,
  });

  factory PrayerTimes.fromJson(Map<String, dynamic> json, DateTime date) {
    return PrayerTimes(
      date: date,
      imsak: json['fajr'] ?? json['imsak'] ?? '00:00',
      gunes: json['sun'] ?? json['sunrise'] ?? json['gunes'] ?? '00:00',
      ogle: json['dhuhr'] ?? json['ogle'] ?? '00:00',
      ikindi: json['asr'] ?? json['ikindi'] ?? '00:00',
      aksam: json['maghrib'] ?? json['aksam'] ?? '00:00',
      yatsi: json['isha'] ?? json['yatsi'] ?? '00:00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'imsak': imsak,
      'gunes': gunes,
      'ogle': ogle,
      'ikindi': ikindi,
      'aksam': aksam,
      'yatsi': yatsi,
    };
  }

  /// Get iftar time (same as aksam/maghrib)
  String get iftar => aksam;

  /// Get sahur time (same as imsak/fajr)
  String get sahur => imsak;

  /// Check if this is today's prayer times
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  /// Format date as "1 Gün" or "15 Gün"
  String get dayLabel {
    final day = date.day;
    return '$day. Gün';
  }

  /// Format date as "19 Şubat" or "1 Mart"
  String get dateLabel {
    final months = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${date.day} ${months[date.month]}';
  }

  /// Full date with day of week: "19 Şubat 2026 Perşembe"
  String get fullDateLabel {
    final months = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    const days = ['Pazar', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi'];
    return '${date.day} ${months[date.month]} ${date.year} ${days[date.weekday % 7]}';
  }

  @override
  String toString() {
    return 'PrayerTimes($dateLabel: İmsak $imsak, Akşam $aksam)';
  }
}
