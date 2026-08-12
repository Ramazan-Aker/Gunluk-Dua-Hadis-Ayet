import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../services/achievement_service.dart';
import '../services/firebase_service.dart' show FirebaseService;
import '../theme/app_theme.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  AchievementSummary? _summary;

  @override
  void initState() {
    super.initState();
    FirebaseService.logScreenView(screenName: 'screen_achievements');
    _load();
  }

  Future<void> _load() async {
    final summary = await AchievementService().evaluateAndUnlock();
    if (mounted) setState(() => _summary = summary);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      backgroundColor: AppTheme.ivory,
      appBar: AppBar(title: const Text('Başarılar ve Rozetler')),
      body: summary == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 34),
                children: [
                  _AchievementHeader(summary: summary),
                  const SizedBox(height: 18),
                  const Text(
                    'Rozet koleksiyonun',
                    style: TextStyle(
                      color: AppTheme.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 11),
                  ...summary.achievements.map(
                    (achievement) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AchievementCard(status: achievement),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AchievementHeader extends StatelessWidget {
  const _AchievementHeader({required this.summary});

  final AchievementSummary summary;

  @override
  Widget build(BuildContext context) {
    final progress = summary.unlockedCount / summary.achievements.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.navy, AppTheme.navyContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.square(
                  dimension: 82,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    color: AppTheme.gold,
                    backgroundColor: Colors.white.withValues(alpha: .14),
                  ),
                ),
                const Text('🏆', style: TextStyle(fontSize: 31)),
              ],
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manevi yolculuğun',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${summary.unlockedCount}/${summary.achievements.length} rozet kazanıldı',
                  style: const TextStyle(color: Color(0xFFD0E4FF)),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Küçük ve düzenli adımlar büyük bir ilerleme oluşturur.',
                  style: TextStyle(color: AppTheme.gold, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.status});

  final AchievementStatus status;

  @override
  Widget build(BuildContext context) {
    final unlocked = status.unlocked;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: unlocked
            ? Border.all(color: AppTheme.gold.withValues(alpha: .6))
            : null,
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked
                  ? const Color(0xFFFFDEA3).withValues(alpha: .55)
                  : AppTheme.surfaceLow,
            ),
            child: unlocked
                ? Text(status.definition.symbol,
                    style: const TextStyle(fontSize: 25))
                : const Icon(Icons.lock_outline_rounded,
                    color: AppTheme.outline),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        status.definition.title,
                        style: const TextStyle(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (unlocked)
                      const Icon(Icons.verified_rounded,
                          color: AppTheme.emerald, size: 19),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  status.definition.description,
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                if (!unlocked) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            value: status.progress,
                            color: AppTheme.gold,
                            backgroundColor: AppTheme.surfaceLow,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${status.current.clamp(0, status.definition.target)}/${status.definition.target}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
