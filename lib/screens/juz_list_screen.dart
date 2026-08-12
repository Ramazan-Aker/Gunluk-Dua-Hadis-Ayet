import 'dart:async';

import 'package:flutter/material.dart';

import '../models/quran_juz.dart';
import '../services/quran_audio_service.dart';
import '../services/quran_progress_service.dart';
import '../services/smart_goal_reminder_service.dart';
import '../services/achievement_service.dart';
import '../theme/app_theme.dart';
import 'juz_reader_screen.dart';
import 'quran_reading_plan_screen.dart';

class JuzListScreen extends StatefulWidget {
  const JuzListScreen({super.key});

  @override
  State<JuzListScreen> createState() => _JuzListScreenState();
}

class _JuzListScreenState extends State<JuzListScreen> {
  final _progress = QuranProgressService();
  Set<int> _completed = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final completed = await _progress.completedJuz();
    if (mounted) setState(() => _completed = completed);
  }

  Future<void> _toggle(int number, bool value) async {
    final completed = await _progress.setJuzCompleted(number, value);
    unawaited(SmartGoalReminderService().refreshSchedule());
    unawaited(AchievementService().evaluateAndUnlock(notify: true));
    if (mounted) setState(() => _completed = completed);
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_completed.length / 30 * 100).round();
    return Scaffold(
      backgroundColor: AppTheme.ivory,
      appBar: AppBar(
        title: const Text('Cüzler'),
        actions: [
          IconButton(
            tooltip: 'Hatim planım',
            icon: const Icon(Icons.flag_outlined),
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const QuranReadingPlanScreen(
                    allowOpenJuzList: false,
                  ),
                ),
              );
              _reload();
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.navyContainer,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppTheme.ambientShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_stories_rounded, color: AppTheme.mint),
                    SizedBox(width: 10),
                    Text('Hatim İlerlemesi',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _completed.length / 30,
                    minHeight: 9,
                    backgroundColor: AppTheme.navy,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.mint),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${_completed.length}/30 cüz • %$percent tamamlandı',
                    style: const TextStyle(color: Color(0xFFD0E4FF))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...quranJuzList.map((juz) {
            final done = _completed.contains(juz.number);
            final surahName =
                QuranAudioService.turkishSurahNames[juz.startSurah] ??
                    'Sure ${juz.startSurah}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => JuzReaderScreen(juz: juz)),
                    );
                    _reload();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.ambientShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: done
                                ? AppTheme.mint
                                : const Color(0xFFFFDEA3)
                                    .withValues(alpha: .45),
                            shape: BoxShape.circle,
                          ),
                          child: Text('${juz.number}',
                              style: TextStyle(
                                  color: done
                                      ? AppTheme.emerald
                                      : const Color(0xFF6B4C00),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${juz.number}. Cüz',
                                  style: const TextStyle(
                                      color: AppTheme.navy,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(
                                  '$surahName Suresi • ${juz.startAyah}. ayetten başlar',
                                  style: const TextStyle(
                                      color: AppTheme.textMuted, fontSize: 13)),
                            ],
                          ),
                        ),
                        Checkbox(
                          value: done,
                          activeColor: AppTheme.emerald,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                          onChanged: (value) =>
                              _toggle(juz.number, value ?? false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
