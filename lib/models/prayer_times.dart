/// Model class for daily prayer times
/// Used in Ramadan prayer times feature
class PrayerTimes {
  final DateTime date;
  final String imsak; // Sahur (Fajr start time)
  final String gunes; // Sunrise
  final String ogle; // Dhuhr (Noon)
  final String ikindi; // Asr (Afternoon)
  final String aksam; // Maghrib (Iftar/Evening)
  final String yatsi; // Isha (Night)

  PrayerTimes({
    required this.date,
    required this.imsak,
    required this.gunes,
    required this.ogle,
    required this.ikindi,
    required this.aksam,
    required this.yatsi,
  });

  static final RegExp _clockPattern = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');

  factory PrayerTimes.fromJson(Map<String, dynamic> json, DateTime date) {
    final parsed = tryFromJson(json, date);
    if (parsed == null) {
      throw const FormatException('Eksik veya geçersiz namaz vakti verisi.');
    }
    return parsed;
  }

  /// Parses a complete row. A missing or malformed clock value rejects the
  /// row instead of silently displaying a misleading `00:00` value.
  static PrayerTimes? tryFromJson(
    Map<String, dynamic> json,
    DateTime date,
  ) {
    final imsak = _readClock(json, const ['fajr', 'imsak']);
    final gunes = _readClock(json, const ['sun', 'sunrise', 'gunes']);
    final ogle = _readClock(json, const ['dhuhr', 'ogle']);
    final ikindi = _readClock(json, const ['asr', 'ikindi']);
    final aksam = _readClock(json, const ['maghrib', 'aksam']);
    final yatsi = _readClock(json, const ['isha', 'yatsi']);
    if ([imsak, gunes, ogle, ikindi, aksam, yatsi].contains(null)) {
      return null;
    }

    final result = PrayerTimes(
      date: DateTime(date.year, date.month, date.day),
      imsak: imsak!,
      gunes: gunes!,
      ogle: ogle!,
      ikindi: ikindi!,
      aksam: aksam!,
      yatsi: yatsi!,
    );
    return result.hasChronologicalOrder ? result : null;
  }

  static String? _readClock(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is! String) continue;
      final normalized = value.trim();
      if (_clockPattern.hasMatch(normalized)) return normalized;
    }
    return null;
  }

  bool get hasChronologicalOrder {
    final values = [imsak, gunes, ogle, ikindi, aksam, yatsi]
        .map(_minutesSinceMidnight)
        .toList();
    for (var index = 1; index < values.length; index++) {
      if (values[index] <= values[index - 1]) return false;
    }
    return true;
  }

  static int _minutesSinceMidnight(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
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
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    return '${date.day} ${months[date.month]}';
  }

  /// Full date with day of week: "19 Şubat 2026 Perşembe"
  String get fullDateLabel {
    final months = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    const days = [
      'Pazar',
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi'
    ];
    return '${date.day} ${months[date.month]} ${date.year} ${days[date.weekday % 7]}';
  }

  @override
  String toString() {
    return 'PrayerTimes($dateLabel: İmsak $imsak, Akşam $aksam)';
  }
}
