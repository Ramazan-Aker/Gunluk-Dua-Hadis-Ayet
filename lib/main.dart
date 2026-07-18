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
import 'services/widget_verse_android_bridge.dart';
import 'widget_verse_launch_handler.dart';
import 'widget_verse_pending.dart';

/// Main entry point of the Daily Dua & Hadith app
void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

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

  Future<void> _androidWidgetVersePipeline() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await HomeScreenWidgetService.syncRandomVerseForWidget();
    await WidgetVerseAndroidBridge.consumeAndDispatchToFlutter();
    await WidgetVerseLaunchHandler.handleInitialLaunch();
    await WidgetVerseAndroidBridge.consumeAndDispatchToFlutter();
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
      if (!kIsWeb && Platform.isAndroid) {
        await _androidWidgetVersePipeline();
        _scheduleAndroidWidgetVersePulls();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      // App metadata
      title: 'Her Gün İslam',
      debugShowCheckedModeBanner: false,
      
      // Theme configuration
      theme: ThemeData(
        // Primary color scheme (blue + gold theme)
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF1E40AF),
        scaffoldBackgroundColor: const Color(0xFFEFF6FF),
        
        // AppBar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E40AF),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        
        // Text theme
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
          displayMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
          bodyLarge: TextStyle(
            fontSize: 18,
            color: Color(0xFF2C3E50),
            height: 1.6,
          ),
          bodyMedium: TextStyle(
            fontSize: 16,
            color: Color(0xFF2C3E50),
          ),
        ),
        
        // Button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E40AF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
        
        // Card theme
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: Colors.white,
        ),
        
        // Color scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E40AF),
          primary: const Color(0xFF1E40AF),
          secondary: const Color(0xFFF59E0B),
          surface: const Color(0xFFF8FAFC),
        ),
      ),
      
      // Home screen with bottom navigation
      home: const MainNavigationScreen(),
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
  int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
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
    const RamadanScreen(),
    const QuranScreen(),
    const HomeScreen(),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E40AF),
        selectedItemColor: const Color(0xFFF59E0B),
        unselectedItemColor: Colors.white70,
        selectedFontSize: 14,
        unselectedFontSize: 12,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.mosque),
            label: 'İmsakiye',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Kur\'an',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.celebration),
            label: 'Mesajlar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Dini Günler',
          ),
        ],
      ),
    );
  }
}

