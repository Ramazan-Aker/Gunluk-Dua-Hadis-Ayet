import 'package:flutter/material.dart';
import '../models/religious_day.dart';
import '../services/religious_days_service.dart';
import '../services/firebase_service.dart' show FirebaseService;
import '../services/ad_service.dart';

/// Dini günler ekranı - Tüm kandiller ve bayramlara kalan süre
class ReligiousDaysScreen extends StatefulWidget {
  const ReligiousDaysScreen({Key? key}) : super(key: key);

  @override
  State<ReligiousDaysScreen> createState() => _ReligiousDaysScreenState();
}

class _ReligiousDaysScreenState extends State<ReligiousDaysScreen> {
  final ReligiousDaysService _service = ReligiousDaysService();
  bool _showPassedOnly = false; // false = tümü, true = sadece geçenler

  @override
  void initState() {
    super.initState();
    FirebaseService.logScreenView(screenName: 'screen_religious_days');
  }

  List<ReligiousDay> _getFilteredDays() {
    final all = _service.getAllDays();
    if (_showPassedOnly) {
      return all.where((d) => d.daysFromNow < 0).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    }
    return all;
  }

  IconData _getIcon(IconType type) {
    switch (type) {
      case IconType.moon:
        return Icons.nightlight_round;
      case IconType.mosque:
        return Icons.mosque;
      case IconType.star:
        return Icons.star;
      case IconType.calendar:
        return Icons.calendar_today;
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _getFilteredDays();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dini Günler',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showPassedOnly ? Icons.event_available : Icons.history,
            ),
            tooltip: _showPassedOnly ? 'Tümünü göster' : 'Geçen günleri göster',
            onPressed: () {
              setState(() => _showPassedOnly = !_showPassedOnly);
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0FDFA), Color(0xFFCCFBF1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: days.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _showPassedOnly
                              ? 'Henüz geçmiş dini gün yok'
                              : 'Dini gün verisi yüklenemedi',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF0F766E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final day = days[index];
                  final daysLeft = day.daysFromNow;
                  final isToday = daysLeft == 0;
                  final isPassed = daysLeft < 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {},
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? const Color(0xFF0D9488)
                                      : isPassed
                                          ? Colors.grey.shade300
                                          : const Color(0xFF0D9488).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _getIcon(day.iconType),
                                  color: isToday || isPassed
                                      ? (isToday ? Colors.white : Colors.grey.shade600)
                                      : const Color(0xFF0D9488),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      day.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isPassed
                                            ? Colors.grey.shade600
                                            : const Color(0xFF0F766E),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      day.formattedDate,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? const Color(0xFF0D9488)
                                      : isPassed
                                          ? Colors.grey.shade200
                                          : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  day.countdownText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isToday
                                        ? Colors.white
                                        : isPassed
                                            ? Colors.grey.shade600
                                            : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const AdBannerWidget(),
          ],
        ),
      ),
    );
  }
}
