/// Model class for Daily Items (Dua, Hadith, or Ayah)
class DailyItem {
  final String type; // "dua", "hadith", or "ayah"
  final String text;
  final String source;
  final String? id;

  DailyItem({
    required this.type,
    required this.text,
    required this.source,
    this.id,
  });

  /// Factory constructor to create DailyItem from JSON
  factory DailyItem.fromJson(Map<String, dynamic> json) {
    return DailyItem(
      type: json['type'] as String,
      text: json['text'] as String,
      source: json['source'] as String,
      id: json['id'] as String?,
    );
  }

  /// Convert DailyItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'text': text,
      'source': source,
      if (id != null) 'id': id,
    };
  }

  /// Tür adı; emoji için [getIcon] kullanın.
  String getTitle() {
    switch (type.toLowerCase()) {
      case 'dua':
        return 'Günün Duası';
      case 'hadith':
        return 'Hadis';
      case 'ayah':
        return 'Ayet';
      default:
        return 'Günün Mesajı';
    }
  }

  /// Get icon emoji based on type
  String getIcon() {
    switch (type.toLowerCase()) {
      case 'dua':
        return '🤲';
      case 'hadith':
        return '📖';
      case 'ayah':
        return '✨';
      default:
        return '📝';
    }
  }
}

