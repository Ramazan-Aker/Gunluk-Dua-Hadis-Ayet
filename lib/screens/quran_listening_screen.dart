import 'package:flutter/material.dart';
import '../services/quran_listening_service.dart';
import '../services/quran_audio_service.dart';

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
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final handler = widget.handler ?? await QuranListening.initialize();
      if (!mounted) return;
      setState(() => _handler = handler);
      final number = widget.initialChapter;
      if (number != null && handler.chapter != number) {
        await handler.openChapter(number,
          start: handler.bookmark?.chapter == number ? Duration(milliseconds: handler.bookmark!.positionMs) : Duration.zero, autoplay: false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Ses sistemi başlatılamadı. Tekrar deneyin.');
      }
    }
  }

  String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final h = _handler;
    return Scaffold(
        appBar: AppBar(title: const Text('Kur’an dinleme')),
        body: h == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: () {
                          setState(() => _error = null);
                          _initialize();
                        },
                        child: Text(_error!)))
            : AnimatedBuilder(
                animation: h.revision,
                builder: (context, _) =>
                    ListView(padding: const EdgeInsets.all(20), children: [
                      const Icon(Icons.headphones_rounded, size: 64),
                      const SizedBox(height: 16),
                      Text(h.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium),
                      const Text('Mişari Raşid el-Afasi • Quran.com',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<int>(
                          key: ValueKey(h.chapter),
                          initialValue: h.chapter,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Sure seç'),
                          items: [
                            for (var n = 1; n <= 114; n++)
                              DropdownMenuItem(
                                  value: n,
                                  child: Text(
                                      '$n. ${QuranAudioService.turkishSurahNames[n] ?? 'Sure $n'}',
                                      overflow: TextOverflow.ellipsis))
                          ],
                          onChanged: h.busy
                              ? null
                              : (n) {
                                  if (n != null) h.openChapter(n);
                                }),
                      if (h.chapter == null && h.bookmark != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: FilledButton.icon(
                                onPressed: h.busy
                                    ? null
                                    : () => h.openChapter(h.bookmark!.chapter,
                                        start: Duration(
                                            milliseconds:
                                                h.bookmark!.positionMs)),
                                icon: const Icon(Icons.history),
                                label: Text(
                                    '${QuranAudioService.turkishSurahNames[h.bookmark!.chapter]} • Kaldığım yerden devam et'))),
                      if (h.busy)
                        const Padding(
                            padding: EdgeInsets.all(16),
                            child: LinearProgressIndicator()),
                      if (h.error != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(h.error!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))),
                      if (h.chapter != null && h.recitation != null) ...[
                        const SizedBox(height: 20),
                        Text('${h.currentVerse}. ayet',
                            textAlign: TextAlign.center),
                        Slider(
                            value: h.player.position.inMilliseconds
                                .toDouble()
                                .clamp(
                                    0,
                                    (h.player.duration?.inMilliseconds ?? 1)
                                        .clamp(1, 1 << 40)
                                        .toDouble()),
                            max: (h.player.duration?.inMilliseconds ?? 1)
                                .clamp(1, 1 << 40)
                                .toDouble(),
                            onChanged: h.busy
                                ? null
                                : (value) => h.seek(
                                    Duration(milliseconds: value.round()))),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_clock(h.player.position)),
                              Text(_clock(h.player.duration ?? Duration.zero))
                            ]),
                        Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            children: [
                              IconButton(
                                  tooltip: 'Önceki sure',
                                  onPressed: h.busy || h.chapter == 1
                                      ? null
                                      : h.skipToPrevious,
                                  icon: const Icon(Icons.skip_previous)),
                              IconButton.filled(
                                  iconSize: 36,
                                  tooltip:
                                      h.player.playing ? 'Duraklat' : 'Dinle',
                                  onPressed: h.busy
                                      ? null
                                      : () => h.player.playing
                                          ? h.pause()
                                          : h.play(),
                                  icon: Icon(h.player.playing
                                      ? Icons.pause
                                      : Icons.play_arrow)),
                              IconButton(
                                  tooltip: 'Durdur',
                                  onPressed: h.busy ? null : h.stop,
                                  icon: const Icon(Icons.stop)),
                              IconButton(
                                  tooltip: 'Sonraki sure',
                                  onPressed: h.busy || h.chapter == 114
                                      ? null
                                      : h.skipToNext,
                                  icon: const Icon(Icons.skip_next)),
                            ]),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Sonraki sureye otomatik geç'),
                            value: h.autoNext,
                            onChanged: h.setAutoNext),
                        const Divider(),
                        Text('Ayet tekrarı',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                            key: ValueKey(
                                '${h.chapter}/${h.repeatedVerse?.verseNumber}'),
                            initialValue:
                                h.repeatedVerse?.verseNumber ?? h.currentVerse,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Tekrar edilecek ayet'),
                            items: h.recitation!.timings
                                .map((t) => DropdownMenuItem(
                                    value: t.verseNumber,
                                    child: Text('${t.verseNumber}. ayet')))
                                .toList(),
                            onChanged: h.busy
                                ? null
                                : (v) {
                                    if (v != null) {
                                      h.repeatVerse(
                                          v,
                                          h.repeatCount == 1
                                              ? 3
                                              : h.repeatCount);
                                    }
                                  }),
                        Wrap(spacing: 8, children: [
                          for (final count in [1, 3, 5, 10])
                            ChoiceChip(
                                label: Text(count == 1
                                    ? 'Tekrar kapalı'
                                    : '$count kez'),
                                selected: h.repeatCount == count,
                                onSelected: h.busy
                                    ? null
                                    : (_) => h.repeatVerse(
                                        h.repeatedVerse?.verseNumber ??
                                            h.currentVerse,
                                        count))
                        ]),
                        if (h.repeatCount > 1)
                          Text(h.repeatsLeft > 0
                              ? 'Kalan tekrar: ${h.repeatsLeft}'
                              : 'Tekrar tamamlandı'),
                        const Divider(),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                          'Dinleme, bu sayfadan çıkınca devam eder. Kilit ekranından duraklatabilirsiniz. Dinlemek için internet bağlantısı gerekir.',
                          style: TextStyle(fontSize: 12)),
                    ])));
  }
}
