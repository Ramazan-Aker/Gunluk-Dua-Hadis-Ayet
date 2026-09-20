import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/surah_ayah_detail.dart';
import '../services/quran_audio_service.dart';
import '../services/quran_listening_service.dart';
import '../services/quran_offline_repository.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';

class QuranListeningScreen extends StatefulWidget {
  const QuranListeningScreen({super.key, this.initialChapter, this.handler});

  final int? initialChapter;
  final QuranListeningHandler? handler;

  @override
  State<QuranListeningScreen> createState() => _QuranListeningScreenState();
}

class _QuranListeningScreenState extends State<QuranListeningScreen> {
  QuranListeningHandler? _handler;
  String? _error;
  int? _verseChapter;
  Future<List<SurahAyahDetail>>? _verseFuture;
  Timer? _sleepTimer;
  int? _sleepMinutes;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final handler = widget.handler ?? await QuranListening.initialize();
      if (!mounted) return;
      setState(() => _handler = handler);

      final number = widget.initialChapter ??
          handler.chapter ??
          handler.bookmark?.chapter ??
          1;
      if (handler.chapter != number) {
        await handler.openChapter(
          number,
          start: handler.bookmark?.chapter == number
              ? Duration(milliseconds: handler.bookmark!.positionMs)
              : Duration.zero,
          autoplay: false,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Ses sistemi başlatılamadı. Tekrar deneyin.');
      }
    }
  }

  Future<List<SurahAyahDetail>> _verseTextFuture(int chapter) {
    if (_verseChapter != chapter || _verseFuture == null) {
      _verseChapter = chapter;
      _verseFuture =
          QuranOfflineRepository.instance.getSurahAyahsAsDetails(chapter);
    }
    return _verseFuture!;
  }

  String _clock(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _saveBookmark() async {
    await _handler?.saveBookmark();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dinleme konumu kaydedildi.')),
    );
  }

  void _share() {
    final handler = _handler;
    if (handler == null) return;
    Share.share(
      '${handler.title} • ${handler.currentVerse}. Ayet\nHer Gün İslam',
    );
  }

  Future<void> _selectSleepTimer() async {
    final value = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Uyku zamanlayıcısı',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Sürenin sonunda dinleme otomatik duraklar.'),
            ),
            for (final minutes in [15, 30, 45, 60])
              ListTile(
                leading: const Icon(Icons.nights_stay_outlined),
                title: Text('$minutes dakika'),
                trailing: _sleepMinutes == minutes
                    ? const Icon(Icons.check_rounded, color: AppTheme.emerald)
                    : null,
                onTap: () => Navigator.pop(context, minutes),
              ),
            ListTile(
              leading: const Icon(Icons.timer_off_outlined),
              title: const Text('Kapalı'),
              onTap: () => Navigator.pop(context, 0),
            ),
          ],
        ),
      ),
    );
    if (value == null || !mounted) return;
    _sleepTimer?.cancel();
    setState(() => _sleepMinutes = value == 0 ? null : value);
    if (value > 0) {
      _sleepTimer = Timer(Duration(minutes: value), () {
        _handler?.pause();
        if (mounted) setState(() => _sleepMinutes = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final handler = _handler;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'HER GÜN İSLAM',
              style: TextStyle(
                color: AppTheme.emerald,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 2),
            Text('Kur’an Dinleme'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Konumu kaydet',
            onPressed: handler == null ? null : _saveBookmark,
            icon: const Icon(Icons.bookmark_border_rounded),
          ),
          IconButton(
            tooltip: 'Paylaş',
            onPressed: handler == null ? null : _share,
            icon: const Icon(Icons.share_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: TopBannerAdBody(
        child: handler == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() => _error = null);
                          _initialize();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(_error!),
                      ),
              )
            : AnimatedBuilder(
                animation: handler.revision,
                builder: (context, _) => _buildContent(handler),
              ),
      ),
    );
  }

  Widget _buildContent(QuranListeningHandler handler) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        _buildSelectors(handler),
        const SizedBox(height: 20),
        if (handler.busy)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(
                borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
        if (handler.error != null)
          _InfoStrip(
            icon: Icons.error_outline_rounded,
            text: handler.error!,
            color: Theme.of(context).colorScheme.error,
          ),
        if (handler.chapter != null && handler.recitation != null)
          _buildPlayerCard(handler),
        const SizedBox(height: 18),
        if (handler.chapter != null && handler.recitation != null)
          _buildSettingsCard(handler),
        const SizedBox(height: 18),
        const _InfoStrip(
          icon: Icons.info_outline_rounded,
          text:
              'Dinleme, bu sayfadan çıkınca arka planda devam eder. Kilit ekranından ve bildirim merkezinden kontrol edebilirsiniz. Çevrimdışı kayıtlı değilse internet bağlantısı gerekir.',
          color: AppTheme.emerald,
        ),
      ],
    );
  }

  Widget _buildSelectors(QuranListeningHandler handler) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            key: ValueKey('chapter-${handler.chapter}'),
            initialValue: handler.chapter,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'SURE SEÇ',
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
              ),
            ),
            items: [
              for (var number = 1; number <= 114; number++)
                DropdownMenuItem(
                  value: number,
                  child: Text(
                    '$number. ${QuranAudioService.turkishSurahNames[number] ?? 'Sure $number'}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
            onChanged: handler.busy
                ? null
                : (number) {
                    if (number != null) handler.openChapter(number);
                  },
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: _StaticSelector(
            label: 'OKUYUCU',
            value: 'Mişari Raşid',
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerCard(QuranListeningHandler handler) {
    final total = handler.player.duration ?? Duration.zero;
    final maxMs = total.inMilliseconds.clamp(1, 1 << 40).toDouble();
    final positionMs = handler.player.position.inMilliseconds
        .toDouble()
        .clamp(0, maxMs)
        .toDouble();
    final lastVerse = handler.recitation!.timings.last.verseNumber;
    final isLastVerse = handler.currentVerse == lastVerse;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEBE7DC)),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [AppTheme.navy, AppTheme.emerald],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.ambientShadow,
            ),
            child: const Icon(Icons.mic_none_rounded,
                size: 38, color: AppTheme.mint),
          ),
          const SizedBox(height: 14),
          Text(
            '${handler.title} Suresi',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          const Text.rich(
            TextSpan(
              text: 'Mişari Raşid el-Afasi • ',
              children: [
                TextSpan(
                  text: 'Quran.com',
                  style: TextStyle(
                    color: AppTheme.emerald,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.mint.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.mint),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 7, color: AppTheme.emerald),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    '${handler.currentVerse}. Ayet${isLastVerse ? ' (Son Ayet)' : ''}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.emerald,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<SurahAyahDetail>>(
            future: _verseTextFuture(handler.chapter!),
            builder: (context, snapshot) {
              final verses = snapshot.data;
              final index = handler.currentVerse - 1;
              if (verses == null || index < 0 || index >= verses.length) {
                return const SizedBox.shrink();
              }
              final verse = verses[index];
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF9F5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2DDD5)),
                ),
                child: Column(
                  children: [
                    Text(
                      verse.arabicText,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 25,
                        height: 1.9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      color: AppTheme.gold.withValues(alpha: .55),
                    ),
                    Text(
                      '“${verse.turkishText}”',
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _Waveform(progress: maxMs == 0 ? 0 : positionMs / maxMs),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 7,
              activeTrackColor: AppTheme.navy,
              inactiveTrackColor: AppTheme.surfaceLow,
              thumbColor: AppTheme.navy,
              overlayColor: AppTheme.mint.withValues(alpha: .35),
            ),
            child: Slider(
              value: positionMs,
              max: maxMs,
              onChanged: handler.busy
                  ? null
                  : (value) =>
                      handler.seek(Duration(milliseconds: value.round())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_clock(handler.player.position),
                    style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                Text(_clock(total),
                    style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PlayerIconButton(
                tooltip: '10 saniye geri',
                onPressed: handler.busy
                    ? null
                    : () => handler.seekRelative(const Duration(seconds: -10)),
                icon: Icons.replay_10_rounded,
              ),
              _PlayerIconButton(
                tooltip: 'Önceki ayet',
                onPressed: handler.busy ? null : handler.skipToPreviousVerse,
                icon: Icons.skip_previous_rounded,
              ),
              IconButton.filled(
                iconSize: 34,
                constraints:
                    const BoxConstraints.tightFor(width: 60, height: 60),
                tooltip: handler.player.playing ? 'Duraklat' : 'Dinle',
                onPressed: handler.busy
                    ? null
                    : () => handler.player.playing
                        ? handler.pause()
                        : handler.play(),
                icon: Icon(handler.player.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded),
              ),
              _PlayerIconButton(
                tooltip: 'Sonraki ayet',
                onPressed: handler.busy ? null : handler.skipToNextVerse,
                icon: Icons.skip_next_rounded,
              ),
              _PlayerIconButton(
                tooltip: '10 saniye ileri',
                onPressed: handler.busy
                    ? null
                    : () => handler.seekRelative(const Duration(seconds: 10)),
                icon: Icons.forward_10_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(QuranListeningHandler handler) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2DDD5)),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D9),
                  borderRadius: BorderRadius.circular(13),
                  border:
                      Border.all(color: AppTheme.gold.withValues(alpha: .35)),
                ),
                child: const Icon(Icons.fast_forward_rounded,
                    color: AppTheme.gold),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sonraki sureye otomatik geç',
                        style: TextStyle(
                            color: AppTheme.navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Sure bittiğinde kesintisiz dinle',
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Switch(value: handler.autoNext, onChanged: handler.setAutoNext),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          const Row(
            children: [
              Icon(Icons.sync_rounded, color: AppTheme.emerald, size: 19),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AYET TEKRARI & EZBER',
                  maxLines: 2,
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey(
                '${handler.chapter}/${handler.repeatedVerse?.verseNumber}/${handler.currentVerse}'),
            initialValue:
                handler.repeatedVerse?.verseNumber ?? handler.currentVerse,
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Tekrar edilecek ayet'),
            items: handler.recitation!.timings
                .map(
                  (timing) => DropdownMenuItem(
                    value: timing.verseNumber,
                    child: Text('${timing.verseNumber}. Ayet'),
                  ),
                )
                .toList(),
            onChanged: handler.busy
                ? null
                : (verse) {
                    if (verse != null) {
                      handler.repeatVerse(verse,
                          handler.repeatCount == 1 ? 3 : handler.repeatCount);
                    }
                  },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final count in [1, 3, 5, 10]) ...[
                Expanded(
                  child: _RepeatChoice(
                    label: count == 1 ? 'Kapalı' : '$count kez',
                    selected: handler.repeatCount == count,
                    onTap: handler.busy
                        ? null
                        : () => handler.repeatVerse(
                              handler.repeatedVerse?.verseNumber ??
                                  handler.currentVerse,
                              count,
                            ),
                  ),
                ),
                if (count != 10) const SizedBox(width: 8),
              ],
            ],
          ),
          if (handler.repeatCount > 1) ...[
            const SizedBox(height: 10),
            Text(
              handler.repeatsLeft > 0
                  ? 'Kalan tekrar: ${handler.repeatsLeft}'
                  : 'Tekrar tamamlandı',
              style: const TextStyle(
                color: AppTheme.emerald,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          InkWell(
            onTap: _selectSleepTimer,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.nights_stay_outlined,
                      color: AppTheme.gold, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Uyku Zamanlayıcısı',
                        style: TextStyle(
                            color: AppTheme.navy,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLow,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _sleepMinutes == null
                              ? 'Kapalı'
                              : '$_sleepMinutes dk',
                          style: const TextStyle(
                              color: AppTheme.navy,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppTheme.textMuted, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticSelector extends StatelessWidget {
  const _StaticSelector({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.navy.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 20, color: AppTheme.emerald),
            ],
          ),
        ],
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.progress});

  final double progress;
  static const heights = <double>[
    10,
    16,
    22,
    18,
    26,
    14,
    22,
    18,
    12,
    24,
    28,
    19,
    23,
    15,
    27,
    17,
    24,
    13,
  ];

  @override
  Widget build(BuildContext context) {
    final active = (heights.length * progress.clamp(0, 1)).round();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var index = 0; index < heights.length; index++)
          Container(
            width: 4,
            height: heights[index],
            decoration: BoxDecoration(
              color: index < active
                  ? (index < heights.length ~/ 2
                      ? AppTheme.emerald
                      : AppTheme.navy)
                  : const Color(0xFFE4E9ED),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _PlayerIconButton extends StatelessWidget {
  const _PlayerIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        color: AppTheme.navy,
        iconSize: 25,
      );
}

class _RepeatChoice extends StatelessWidget {
  const _RepeatChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color:
            selected ? AppTheme.mint.withValues(alpha: .7) : AppTheme.surface,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? AppTheme.emerald : const Color(0xFFE2DDD5),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    const Icon(Icons.check_rounded,
                        size: 16, color: AppTheme.emerald),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppTheme.emerald : AppTheme.navy,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2DDD5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      );
}
