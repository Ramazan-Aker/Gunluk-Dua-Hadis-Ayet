enum ShareFormat {
  feed('Gönderi', 1080, 1350),
  story('Hikâye / Reels', 1080, 1920),
  square('Kare', 1080, 1080);

  final String label;
  final double width;
  final double height;

  const ShareFormat(this.label, this.width, this.height);

  double get aspectRatio => width / height;
}
