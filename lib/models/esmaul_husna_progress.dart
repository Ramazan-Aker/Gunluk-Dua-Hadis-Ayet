class EsmaulHusnaProgress {
  final Set<int> favorites;
  final Set<int> memorized;

  const EsmaulHusnaProgress({
    this.favorites = const {},
    this.memorized = const {},
  });

  double get memorizedRatio => memorized.length / 99;
}
