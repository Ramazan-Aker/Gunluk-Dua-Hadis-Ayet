import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

const _onboardingCompletedKey = 'onboarding_completed_v1';

/// Uygulama rehberini yalnızca ilk kullanımda gösterir.
class OnboardingGate extends StatefulWidget {
  final Widget child;

  const OnboardingGate({super.key, required this.child});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late final Future<bool> _isCompleted = _loadCompletionState();
  bool? _completedInSession;

  Future<bool> _loadCompletionState() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> _completeOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingCompletedKey, true);
    if (mounted) setState(() => _completedInSession = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_completedInSession == true) return widget.child;

    return FutureBuilder<bool>(
      future: _isCompleted,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _OnboardingLoadingView();
        }
        if (snapshot.data == true) return widget.child;
        return OnboardingScreen(onFinished: _completeOnboarding);
      },
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      eyebrow: 'HER GÜNE GÜZEL BİR BAŞLANGIÇ',
      title: 'Maneviyatın her gün yanında',
      description:
          'Günün ayetini, duasını ve hadisini oku; namaz, Kur’an ve zikir hedeflerini Günlük Manevi Plan’da bir arada takip et.',
      icon: Icons.auto_awesome_rounded,
      accent: AppTheme.gold,
      highlights: ['Günlük plan', 'Dua ve hadis', 'Hedef serisi'],
    ),
    _OnboardingPageData(
      eyebrow: 'KUR’AN-I KERİM',
      title: 'Oku, dinle ve ilerlemeni takip et',
      description:
          'Surelere veya 30 cüze göre oku. Hatim bitiş tarihini belirle, günlük hedefini takip et ve kaldığın yere kolayca dön.',
      icon: Icons.menu_book_rounded,
      accent: AppTheme.emerald,
      highlights: ['Hatim planı', '30 cüz', 'Sesli dinleme'],
    ),
    _OnboardingPageData(
      eyebrow: 'HEDEFLER VE ÖĞRENME',
      title: 'Küçük adımları alışkanlığa çevir',
      description:
          'Akıllı hatırlatmalarını ayarla, hedef serilerini ve rozetlerini takip et. Esmaül Hüsna’yı dinleyerek öğren, ilerlemeni haftalık ve aylık grafiklerde gör.',
      icon: Icons.insights_rounded,
      accent: Color(0xFF7A4DB3),
      highlights: ['Akıllı hatırlatma', 'Rozetler', 'Manevi istatistikler'],
    ),
    _OnboardingPageData(
      eyebrow: 'NAMAZ VAKİTLERİ',
      title: 'Vakitleri şehir şehir takip et',
      description:
          'En fazla üç şehir ekle, sekmelerden hızlıca geçiş yap. Yaklaşan vakit bildirimlerini aç; namaz hedeflerini ve kaza takibini tek yerden yönet.',
      icon: Icons.mosque_rounded,
      accent: Color(0xFF5A8F82),
      highlights: ['3 şehir', 'Namaz hedefi', 'Kaza takibi'],
    ),
    _OnboardingPageData(
      eyebrow: 'PAYLAŞ VE HATIRLA',
      title: 'Güzel sözleri sana özel paylaş',
      description:
          'Mesajları favorilerine ekle, son kullandıklarına dön ve imzanı ekle. Hikâye, gönderi veya Reels için uygun görsel hazırla.',
      icon: Icons.favorite_rounded,
      accent: Color(0xFFB76E79),
      highlights: ['Favoriler', 'Kişisel imza', 'Farklı paylaşım boyutları'],
    ),
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isFinishing = false;

  bool get _isLastPage => _currentPage == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    await widget.onFinished();
  }

  Future<void> _next() async {
    if (_isLastPage) {
      await _finish();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _previous() async {
    if (_currentPage == 0) return;
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ivory,
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingTopBar(
              currentPage: _currentPage,
              pageCount: _pages.length,
              onSkip: _finish,
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => _OnboardingPage(
                  data: _pages[index],
                  pageIndex: index,
                ),
              ),
            ),
            _OnboardingControls(
              currentPage: _currentPage,
              pageCount: _pages.length,
              isFinishing: _isFinishing,
              onBack: _previous,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingTopBar extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final VoidCallback onSkip;

  const _OnboardingTopBar({
    required this.currentPage,
    required this.pageCount,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 4),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.navy,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.nights_stay_rounded,
              color: AppTheme.gold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Her Gün İslam',
              style: TextStyle(
                color: AppTheme.navy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (currentPage < pageCount - 1)
            TextButton(
              onPressed: onSkip,
              child: const Text('Atla'),
            ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  final int pageIndex;

  const _OnboardingPage({required this.data, required this.pageIndex});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final compact = screenHeight < 700;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, compact ? 8 : 20, 24, 12),
      child: Column(
        children: [
          _FeatureIllustration(
            icon: data.icon,
            accent: data.accent,
            pageIndex: pageIndex,
            compact: compact,
          ),
          SizedBox(height: compact ? 20 : 30),
          Text(
            data.eyebrow,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.emerald,
              fontSize: 12,
              height: 1.2,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: compact ? 27 : 31,
              height: 1.12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              data.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 15,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: compact ? 16 : 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: data.highlights
                .map((label) =>
                    _HighlightChip(label: label, accent: data.accent))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FeatureIllustration extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final int pageIndex;
  final bool compact;

  const _FeatureIllustration({
    required this.icon,
    required this.accent,
    required this.pageIndex,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final height = compact ? 220.0 : 285.0;

    return Container(
      width: double.infinity,
      height: height,
      constraints: const BoxConstraints(maxWidth: 520),
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -54,
              right: -38,
              child: _DecorativeCircle(
                size: 150,
                color: accent.withValues(alpha: .20),
              ),
            ),
            Positioned(
              bottom: -62,
              left: -34,
              child: _DecorativeCircle(
                size: 170,
                color: AppTheme.gold.withValues(alpha: .12),
              ),
            ),
            Positioned(
              top: 26,
              left: 28,
              child: Icon(
                Icons.star_rounded,
                size: 13,
                color: Colors.white.withValues(alpha: .65),
              ),
            ),
            Positioned(
              right: 35,
              bottom: 35,
              child: Icon(
                Icons.star_rounded,
                size: 10,
                color: Colors.white.withValues(alpha: .45),
              ),
            ),
            Container(
              width: compact ? 132 : 158,
              height: compact ? 132 : 158,
              decoration: BoxDecoration(
                color: AppTheme.ivory,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.gold, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, size: compact ? 62 : 76, color: accent),
            ),
            Positioned(
              bottom: 19,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .16)),
                ),
                child: Text(
                  '${pageIndex + 1} / 4',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorativeCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  final String label;
  final Color accent;

  const _HighlightChip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingControls extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final bool isFinishing;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _OnboardingControls({
    required this.currentPage,
    required this.pageCount,
    required this.isFinishing,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLastPage = currentPage == pageCount - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pageCount,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: index == currentPage ? 24 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: index == currentPage
                      ? AppTheme.gold
                      : AppTheme.outline.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (currentPage > 0) ...[
                IconButton.outlined(
                  onPressed: isFinishing ? null : onBack,
                  tooltip: 'Geri',
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: isFinishing ? null : onNext,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: AppTheme.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: isFinishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLastPage ? 'Uygulamayı Keşfet' : 'Devam Et',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLastPage
                                  ? Icons.explore_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 20,
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingLoadingView extends StatelessWidget {
  const _OnboardingLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.navy,
      body: Center(
        child:
            CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2.5),
      ),
    );
  }
}

class _OnboardingPageData {
  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final List<String> highlights;

  const _OnboardingPageData({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.highlights,
  });
}
