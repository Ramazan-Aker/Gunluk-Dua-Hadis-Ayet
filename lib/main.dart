import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
import 'services/daily_reminder_service.dart';
import 'services/firebase_service.dart';
import 'screens/home_screen.dart';
import 'screens/ramadan_screen.dart';
import 'screens/messages_screen.dart';

/// Main entry point of the Daily Dua & Hadith app
void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (Analytics & Crashlytics)
  debugPrint('🚀 ========== FIREBASE INIT START ==========');
  debugPrint('🚀 Initializing Firebase...');
  try {
    await FirebaseService.initialize();
    debugPrint('🚀 Firebase initialization attempt completed');
    debugPrint('🚀 ========== FIREBASE INIT END ==========');
  } catch (e, stackTrace) {
    debugPrint('⚠️ ========== FIREBASE INIT ERROR ==========');
    debugPrint('⚠️ Firebase initialization failed in main: $e');
    debugPrint('⚠️ Stack trace: $stackTrace');
    debugPrint('⚠️ App will continue without Firebase');
    debugPrint('⚠️ ==========================================');
  }
  
  // Initialize AdMob
  await AdService.initialize();
  
  // Initialize Notification Service
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  // Check if we need to reschedule notifications (after boot)
  final shouldReschedule = await notificationService.shouldRescheduleNotifications();
  if (shouldReschedule) {
    debugPrint('🔄 Rescheduling notifications after device boot/update...');
  }
  
  // Initialize daily reminder notifications
  final reminderService = DailyReminderService();
  await reminderService.initializeDailyReminder();
  
  if (shouldReschedule) {
    debugPrint('✅ Notifications rescheduled successfully');
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
class DailyDuaApp extends StatelessWidget {
  const DailyDuaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // App metadata
      title: 'Günlük Dua & Hadis',
      debugShowCheckedModeBanner: false,
      
      // Theme configuration
      theme: ThemeData(
        // Primary color scheme (green/olive theme)
        primarySwatch: Colors.green,
        primaryColor: const Color(0xFF6B8E23),
        scaffoldBackgroundColor: const Color(0xFFF5F5DC),
        
        // AppBar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF6B8E23),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        
        // Text theme
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D5016),
          ),
          displayMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D5016),
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
            backgroundColor: const Color(0xFF6B8E23),
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
          seedColor: const Color(0xFF6B8E23),
          primary: const Color(0xFF6B8E23),
          secondary: const Color(0xFF8FBC8F),
          surface: const Color(0xFFF5F5DC),
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
        backgroundColor: const Color(0xFF6B8E23),
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
        ],
      ),
    );
  }
}

