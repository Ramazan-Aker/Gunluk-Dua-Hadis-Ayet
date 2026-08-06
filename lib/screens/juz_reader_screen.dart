import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../models/quran_juz.dart';
import '../models/quran_offline_verse.dart';
import '../services/quran_audio_service.dart';
import '../services/quran_offline_repository.dart';
import '../services/quran_progress_service.dart';
import '../theme/app_theme.dart';

class JuzReaderScreen extends StatefulWidget {
  final QuranJuz juz;
  const JuzReaderScreen({super.key, required this.juz});

  @override
  State<JuzReaderScreen> createState() => _JuzReaderScreenState();
}

class _JuzReaderScreenState extends State<JuzReaderScreen> {
  final _progress = QuranProgressService();
  late Future<List<QuranOfflineVerse>> _versesFuture;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    final next =
        widget.juz.number < 30 ? quranJuzList[widget.juz.number] : null;
    _versesFuture = QuranOfflineRepository.instance.getVersesBetween(
      startSurah: widget.juz.startSurah,
      startAyah: widget.juz.startAyah,
      endSurah: next?.startSurah,
      endAyah: next?.startAyah,
    );
    _progress.completedJuz().then((values) {
      if (mounted) {
        setState(() => _completed = values.contains(widget.juz.number));
      }
    });
  }

  Future<void> _toggleCompleted() async {
    final values =
        await _progress.setJuzCompleted(widget.juz.number, !_completed);
    if (!mounted) return;
    setState(() => _completed = values.contains(widget.juz.number));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(_completed
              ? '${widget.juz.number}. cüz okundu olarak işaretlendi.'
              : 'Okundu işareti kaldırıldı.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ivory,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.juz.number}. Cüz'),
            const Text('Diyanet İşleri meali',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _completed ? 'Okundu işaretini kaldır' : 'Okundu işaretle',
            onPressed: _toggleCompleted,
            icon: Icon(
                _completed
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
                color: _completed ? AppTheme.emerald : AppTheme.navy),
          ),
        ],
      ),
      body: FutureBuilder<List<QuranOfflineVerse>>(
        future: _versesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final verses = snapshot.data ?? const <QuranOfflineVerse>[];
          if (verses.isEmpty) {
            return const Center(child: Text('Cüz içeriği yüklenemedi.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            itemCount: verses.length,
            itemBuilder: (context, index) {
              final verse = verses[index];
              final newSurah =
                  index == 0 || verses[index - 1].surah != verse.surah;
              return Column(
                children: [
                  if (newSurah) _SurahHeader(number: verse.surah),
                  _JuzVerseCard(verse: verse),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: ElevatedButton.icon(
            onPressed: _toggleCompleted,
            icon: Icon(_completed
                ? Icons.check_circle_rounded
                : Icons.check_circle_outline_rounded),
            label: Text(
                _completed ? 'Okundu olarak işaretlendi' : 'Bu cüzü okudum'),
          ),
        ),
      ),
    );
  }
}

class _SurahHeader extends StatelessWidget {
  final int number;
  const _SurahHeader({required this.number});

  @override
  Widget build(BuildContext context) {
    final name = QuranAudioService.turkishSurahNames[number] ?? 'Sure $number';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('$name Suresi',
                style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _JuzVerseCard extends StatelessWidget {
  final QuranOfflineVerse verse;
  const _JuzVerseCard({required this.verse});

  String get _shareText =>
      '${verse.arabic}\n\n${verse.turkish}\n\n— ${QuranAudioService.turkishSurahNames[verse.surah]} ${verse.ayahInSurah}. Ayet';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.surfaceLow,
              child: Text('${verse.ayahInSurah}',
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ),
          ),
          Text(
            verse.arabic,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: GoogleFonts.notoNaskhArabic(
                fontSize: 28, height: 1.85, color: AppTheme.navy),
          ),
          const SizedBox(height: 12),
          Text(verse.turkish,
              style: const TextStyle(fontSize: 16, height: 1.55)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                  onPressed: () => Share.share(_shareText),
                  icon: const Icon(Icons.share_outlined)),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _shareText));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ayet kopyalandı.')));
                },
                icon: const Icon(Icons.copy_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
