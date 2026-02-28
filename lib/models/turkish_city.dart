/// Model class for Turkish cities
/// Used in Ramadan prayer times feature
class TurkishCity {
  final String id;
  final String name;
  final String country;
  final String? region;

  TurkishCity({
    required this.id,
    required this.name,
    required this.country,
    this.region,
  });

  factory TurkishCity.fromJson(Map<String, dynamic> json) {
    return TurkishCity(
      id: json['id'].toString(),
      name: json['city'] ?? json['name'] ?? '',
      country: json['country'] ?? 'Türkiye',
      region: json['region'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country': country,
      'region': region,
    };
  }

  @override
  String toString() {
    return region != null ? '$name ($region)' : name;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TurkishCity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
