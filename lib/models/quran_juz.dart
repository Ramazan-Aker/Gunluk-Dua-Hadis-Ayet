class QuranJuz {
  final int number;
  final int startSurah;
  final int startAyah;

  const QuranJuz(this.number, this.startSurah, this.startAyah);
}

/// Medine mushafındaki standart 30 cüz başlangıçları.
const quranJuzList = <QuranJuz>[
  QuranJuz(1, 1, 1),
  QuranJuz(2, 2, 142),
  QuranJuz(3, 2, 253),
  QuranJuz(4, 3, 93),
  QuranJuz(5, 4, 24),
  QuranJuz(6, 4, 148),
  QuranJuz(7, 5, 82),
  QuranJuz(8, 6, 111),
  QuranJuz(9, 7, 88),
  QuranJuz(10, 8, 41),
  QuranJuz(11, 9, 93),
  QuranJuz(12, 11, 6),
  QuranJuz(13, 12, 53),
  QuranJuz(14, 15, 1),
  QuranJuz(15, 17, 1),
  QuranJuz(16, 18, 75),
  QuranJuz(17, 21, 1),
  QuranJuz(18, 23, 1),
  QuranJuz(19, 25, 21),
  QuranJuz(20, 27, 56),
  QuranJuz(21, 29, 46),
  QuranJuz(22, 33, 31),
  QuranJuz(23, 36, 28),
  QuranJuz(24, 39, 32),
  QuranJuz(25, 41, 47),
  QuranJuz(26, 46, 1),
  QuranJuz(27, 51, 31),
  QuranJuz(28, 58, 1),
  QuranJuz(29, 67, 1),
  QuranJuz(30, 78, 1),
];
