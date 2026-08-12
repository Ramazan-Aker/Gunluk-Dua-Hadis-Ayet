class QiblaDirection {
  const QiblaDirection({
    required this.bearingDegrees,
    required this.distanceKm,
  });

  final double bearingDegrees;
  final double distanceKm;

  String get cardinalDirection {
    const directions = <String>[
      'Kuzey',
      'Kuzeydoğu',
      'Doğu',
      'Güneydoğu',
      'Güney',
      'Güneybatı',
      'Batı',
      'Kuzeybatı',
    ];
    final index = ((bearingDegrees + 22.5) ~/ 45) % directions.length;
    return directions[index];
  }
}
