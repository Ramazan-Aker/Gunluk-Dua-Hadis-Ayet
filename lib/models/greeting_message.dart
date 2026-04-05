/// Model for Cuma, Kandil, and Bayram greeting messages
class GreetingMessage {
  final String id;
  final String category;
  final String title;
  final String text;
  /// API'den gelen görsel URL'si (Pixabay vb.)
  final String? imageUrl;

  GreetingMessage({
    required this.id,
    required this.category,
    required this.title,
    required this.text,
    this.imageUrl,
  });

  factory GreetingMessage.fromJson(Map<String, dynamic> json, String category) {
    return GreetingMessage(
      id: json['id'] as String? ?? '',
      category: category,
      title: json['title'] as String? ?? '',
      text: json['text'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'title': title,
      'text': text,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }
}

/// Greeting category enum for card theme selection
enum GreetingCategory {
  cuma,
  kandil,
  bayram,
}

/// Subcategories for Kandil and Bayram
class GreetingCategoryInfo {
  static const List<String> cumaIds = ['cuma'];
  static const List<String> kandilIds = [
    'mevlid',
    'regaib',
    'mirac',
    'berat',
    'kadir',
  ];
  static const List<String> bayramIds = [
    'ramazan_bayrami',
    'kurban_bayrami',
  ];
  static const List<String> apiCategoryIds = ['günlük_dua'];
  static const List<String> specialOccasionIds = [
    'tebrikler',
    'teselli',
    'hayirli_olsun',
    'dua_isteme',
  ];

  static GreetingCategory getCategoryType(String categoryId) {
    if (cumaIds.contains(categoryId)) return GreetingCategory.cuma;
    if (kandilIds.contains(categoryId)) return GreetingCategory.kandil;
    if (bayramIds.contains(categoryId)) return GreetingCategory.bayram;
    if (apiCategoryIds.contains(categoryId)) return GreetingCategory.cuma;
    return GreetingCategory.cuma;
  }

  static String getDisplayName(String categoryId) {
    switch (categoryId) {
      case 'cuma':
        return 'Cuma';
      case 'mevlid':
        return 'Mevlid Kandili';
      case 'regaib':
        return 'Regaib Kandili';
      case 'mirac':
        return 'Mirac Kandili';
      case 'berat':
        return 'Berat Kandili';
      case 'kadir':
        return 'Kadir Gecesi';
      case 'ramazan_bayrami':
        return 'Ramazan Bayramı';
      case 'kurban_bayrami':
        return 'Kurban Bayramı';
      case 'günlük_dua':
        return 'Günlük Dua & Zikir';
      case 'tebrikler':
        return 'Tebrikler';
      case 'teselli':
        return 'Teselli & Başsağlığı';
      case 'hayirli_olsun':
        return 'Hayırlı Olsun';
      case 'dua_isteme':
        return 'Dua İsteme';
      default:
        return categoryId;
    }
  }
}
