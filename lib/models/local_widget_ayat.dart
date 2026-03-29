/// Yerel asset’ten gelen, widget ve çevrimdışı kullanım için ayet satırı.
class LocalWidgetAyat {
  final String surah;
  final String footer;
  final int ayah;
  final String arabic;
  final String turkish;

  const LocalWidgetAyat({
    required this.surah,
    required this.footer,
    required this.ayah,
    required this.arabic,
    required this.turkish,
  });

  factory LocalWidgetAyat.fromJson(Map<String, dynamic> json) {
    return LocalWidgetAyat(
      surah: json['surah'] as String,
      footer: json['footer'] as String,
      ayah: json['ayah'] as int,
      arabic: json['arabic'] as String,
      turkish: json['turkish'] as String,
    );
  }
}
