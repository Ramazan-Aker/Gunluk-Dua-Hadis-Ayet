import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
import 'services/daily_reminder_service.dart';
import 'services/firebase_service.dart';
import 'screens/home_screen.dart';
import 'screens/ramadan_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/religious_days_screen.dart';

/// Main entry point of the Daily Dua & Hadith app
void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (Analytics & Crashlytics)
  try {
    await FirebaseService.initialize();
  } catch (e, stackTrace) {
    // Firebase init failed - app continues without it
  }
  
  // Initialize AdMob
  await AdService.initialize();
  
  // Initialize Notification Service
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  // Check if we need to reschedule notifications (after boot)
  final shouldReschedule = await notificationService.shouldRescheduleNotifications();
  
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
class DailyDuaApp extends StatelessWidget {
  const DailyDuaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // App metadata
      title: 'Her Gün İslam',
      debugShowCheckedModeBanner: false,
      
      // Theme configuration
      theme: ThemeData(
        // Primary color scheme (teal theme)
        primarySwatch: Colors.teal,
        primaryColor: const Color(0xFF0D9488),
        scaffoldBackgroundColor: const Color(0xFFF0FDFA),
        
        // AppBar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D9488),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        
        // Text theme
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F766E),
          ),
          displayMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F766E),
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
            backgroundColor: const Color(0xFF0D9488),
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
          seedColor: const Color(0xFF0D9488),
          primary: const Color(0xFF0D9488),
          secondary: const Color(0xFF14B8A6),
          surface: const Color(0xFFF0FDFA),
        ),
      ),
      
      // Home screen with bottom navigation
      home: const MainNavigationScreen(),
    );
  }
}

/// Main navigation screen with bottom navigation bar
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // Screens for navigation
  final List<Widget> _screens = [
    const HomeScreen(),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0D9488),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        selectedFontSize: 14,
        unselectedFontSize: 12,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mosque),
            label: 'İmsakiye',
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

