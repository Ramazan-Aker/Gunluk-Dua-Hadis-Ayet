class ReadyMessageDesign {
  final String id;
  final String category;
  final String categoryLabel;
  final String title;
  final String message;
  final String source;
  final String? creator;
  final String? license;
  final String? sourceUrl;
  final String? licenseUrl;

  String get backgroundAssetPath => 'assets/message_backgrounds/$id.jpg';

  const ReadyMessageDesign({
    required this.id,
    required this.category,
    required this.categoryLabel,
    required this.title,
    required this.message,
    required this.source,
    this.creator,
    this.license,
    this.sourceUrl,
    this.licenseUrl,
  });

  factory ReadyMessageDesign.fromJson(Map<String, dynamic> json) {
    return ReadyMessageDesign(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? 'diger',
      categoryLabel: json['categoryLabel'] as String? ?? 'Diğer',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      source: json['source'] as String? ?? 'Özgün içerik',
      creator: json['creator'] as String?,
      license: json['license'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      licenseUrl: json['licenseUrl'] as String?,
    );
  }
}
