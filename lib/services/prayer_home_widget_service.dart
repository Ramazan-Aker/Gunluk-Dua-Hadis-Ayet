import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/prayer_times.dart';
import '../models/prayer_widget_moment.dart';

class PrayerHomeWidgetService {
  PrayerHomeWidgetService._();

  static const String qualifiedAndroidName =
      'com.tahram.gunlukduahadis.PrayerTimesWidgetProvider';
  static const String iosWidgetName = 'PrayerTimesWidget';
  static const String iosAppGroupId = 'group.com.tahram.gunlukduahadis';

  static const String cityKey = 'prayer_widget_city';
  static const String scheduleKey = 'prayer_widget_schedule_json';
  static const String updatedAtKey = 'prayer_widget_updated_at';

  static bool get _isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static List<PrayerWidgetMoment> buildSchedule(
    List<PrayerTimes> prayerTimes,
  ) {
    final moments = <PrayerWidgetMoment>[];
    for (final day in prayerTimes) {
      final entries = <(String, String)>[
        ('Sabah', day.imsak),
        ('Öğle', day.ogle),
        ('İkindi', day.ikindi),
        ('Akşam', day.aksam),
        ('Yatsı', day.yatsi),
      ];
      for (final entry in entries) {
        final at = _timeOnDate(day.date, entry.$2);
        if (at == null) continue;
        moments.add(
          PrayerWidgetMoment(name: entry.$1, time: entry.$2, at: at),
        );
      }
    }
    moments.sort((a, b) => a.at.compareTo(b.at));
    return moments;
  }

  static PrayerWidgetMoment? nextMoment(
    List<PrayerWidgetMoment> schedule, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    for (final moment in schedule) {
      if (moment.at.isAfter(current)) return moment;
    }
    return null;
  }

  static Future<void> syncForWidget({
    required String cityName,
    required List<PrayerTimes> prayerTimes,
  }) async {
    if (!_isSupportedPlatform || prayerTimes.isEmpty) return;
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(iosAppGroupId);
      }
      final schedule = buildSchedule(prayerTimes);
      if (schedule.isEmpty) return;
      await HomeWidget.saveWidgetData(cityKey, cityName);
      await HomeWidget.saveWidgetData(
        scheduleKey,
        jsonEncode(schedule.map((moment) => moment.toJson()).toList()),
      );
      await HomeWidget.saveWidgetData(
        updatedAtKey,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
      await refreshWidget();
    } catch (_) {}
  }

  static Future<void> refreshWidget() async {
    if (!_isSupportedPlatform) return;
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(iosAppGroupId);
      }
      await HomeWidget.updateWidget(
        qualifiedAndroidName: qualifiedAndroidName,
        iOSName: iosWidgetName,
      );
    } catch (_) {}
  }

  static Future<void> requestPinWidgetFromApp() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: qualifiedAndroidName,
      );
    } catch (_) {}
  }

  static DateTime? _timeOnDate(DateTime date, String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}
