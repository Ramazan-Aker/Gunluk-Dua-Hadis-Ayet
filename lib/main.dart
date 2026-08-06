import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'services/home_screen_widget_service.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
import 'services/daily_reminder_service.dart';
import 'services/firebase_service.dart';
import 'screens/home_screen.dart';
import 'screens/ramadan_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/religious_days_screen.dart';
import 'screens/quran_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/widget_verse_android_bridge.dart';
import 'widget_verse_launch_handler.dart';
import 'widget_verse_pending.dart';
import 'theme/app_theme.dart';

/// Main entry point of the Daily Dua & Hadith app
void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // These integrations are mobile-only. Skipping them on web keeps the
  // browser preview usable without changing the Android/iOS startup flow.
  if (!kIsWeb) {
    // Initialize Firebase (Analytics & Crashlytics)
    try {
      await FirebaseService.initialize();
    } catch (e) {
      // Firebase init failed - app continues without it
    }

    // Initialize AdMob
    await AdService.initialize();

    // Initialize Notification Service
    final notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.shouldRescheduleNotifications();

    // Initialize daily reminder notifications
    final reminderService = DailyReminderService();
    await reminderService.initializeDailyReminder();
  }

  // Set preferred orientations (portrait only for better UX)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Run the app
  runApp(const DailyDuaApp());
}

/// Root widget of the application
class DailyDuaApp extends StatefulWidget {
  const DailyDuaApp({super.key});

  @override
  State<DailyDuaApp> createState() => _DailyDuaAppState();
}

class _DailyDuaAppState extends State<DailyDuaApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri?>? _widgetClickSub;

  Future<void> _widgetVersePipeline() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    await HomeScreenWidgetService.syncRandomVerseForWidget();
    if (Platform.isAndroid) {
      await WidgetVerseAndroidBridge.consumeAndDispatchToFlutter();
    }
    await WidgetVerseLaunchHandler.handleInitialLaunch();
    if (Platform.isAndroid) {
      await WidgetVerseAndroidBridge.consumeAndDispatchToFlutter();
    }
  }

  void _scheduleAndroidWidgetVersePulls() {
    if (kIsWeb || !Platform.isAndroid) return;
    Future<void>(() async {
      await WidgetVerseAndroidBridge.consumeAndDispatchToFlutter();
    });
    Future<void>.delayed(const Duration(milliseconds: 250), () async {
      await WidgetVerseAndroidBridge.consumeAndDispatchToFlutter();
    });
    Future<void>.delayed(const Duration(milliseconds: 800), () async {
      await WidgetVerseAndroidBridge.consumeAndDispatchToFlutter();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _widgetClickSub = WidgetVerseLaunchHandler.subscribeWidgetClicks();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      FlutterNativeSplash.remove();
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _widgetVersePipeline();
        if (Platform.isAndroid) _scheduleAndroidWidgetVersePulls();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClickSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb && Platform.isAndroid) {
      unawaited(HomeScreenWidgetService.syncRandomVerseForWidget());
      WidgetVerseAndroidBridge.consumeAndDispatchToFlutter();
      _scheduleAndroidWidgetVersePulls();
    } else if (state == AppLifecycleState.resumed &&
        !kIsWeb &&
        Platform.isIOS) {
      unawaited(HomeScreenWidgetService.syncRandomVerseForWidget());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      // App metadata
      title: 'Her Gün İslam',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.light,

      // Home screen with bottom navigation
      home: const OnboardingGate(child: MainNavigationScreen()),
    );
  }
}

/// Main navigation screen with bottom navigation bar
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  /// Orta sekme: Ana Sayfa
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (pendingWidgetVerseListIndex.value != null) _selectedIndex = 1;
    pendingWidgetVerseListIndex.addListener(_onPendingWidgetVerseForNav);
  }

  @override
  void dispose() {
    pendingWidgetVerseListIndex.removeListener(_onPendingWidgetVerseForNav);
    super.dispose();
  }

  void _onPendingWidgetVerseForNav() {
    if (pendingWidgetVerseListIndex.value != null) {
      setState(() => _selectedIndex = 1);
    }
  }

  // Sıra: İmsakiye, Kur'an, Ana Sayfa, Mesajlar, Dini Günler
  final List<Widget> _screens = [
    const HomeScreen(),
    const QuranScreen(),
    const RamadanScreen(),
    const MessagesScreen(),
    const ReligiousDaysScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [
            BoxShadow(
              color: AppTheme.navy.withValues(alpha: .07),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: AppTheme.navy,
          unselectedItemColor: AppTheme.textMuted,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: _ActiveNavIcon(Icons.home_rounded),
              label: 'Ana Sayfa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: _ActiveNavIcon(Icons.menu_book_rounded),
              label: 'Kur\'an',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.mosque_outlined),
              activeIcon: _ActiveNavIcon(Icons.mosque_rounded),
              label: 'Namaz',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: _ActiveNavIcon(Icons.chat_bubble_rounded),
              label: 'Mesajlar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz_rounded),
              activeIcon: _ActiveNavIcon(Icons.more_horiz_rounded),
              label: 'Diğer',
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveNavIcon extends StatelessWidget {
  final IconData icon;
  const _ActiveNavIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(height: 2),
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: AppTheme.gold,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
