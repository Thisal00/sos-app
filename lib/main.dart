import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'firebase_options.dart';
import 'theme/theme.dart';
import 'services/notification_service.dart';
import 'services/weather_service.dart';
import 'services/background_service.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main_screen.dart';
import 'screens/wardrobe_screen.dart';
// IMPORTANT: Import your splash screen here
import 'screens/splash_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();
  if (message.notification != null) {
    NotificationService.showNotification(
      id: message.messageId?.hashCode ?? DateTime.now().millisecond,
      title: message.notification!.title ?? "FamilyLink Alert",
      body: message.notification!.body ?? "Emergency signal received!",
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await WeatherService.checkAndSendMorningAlert(isTesting: false);
    return Future.value(true);
  });
}

Duration _calculateDelayUntilSixAM() {
  final now = DateTime.now();
  var sixAM = DateTime(now.year, now.month, now.day, 6, 0);
  if (now.isAfter(sixAM)) sixAM = sixAM.add(const Duration(days: 1));
  return sixAM.difference(now);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseMessaging.instance
      .requestPermission(alert: true, badge: true, sound: true);
  await NotificationService.initialize();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      "daily_weather_task",
      "weatherTask",
      frequency: const Duration(hours: 24),
      initialDelay: _calculateDelayUntilSixAM(),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  } catch (e) {
    debugPrint("Workmanager initialization failed: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FamilyLink SL',
      theme: AppTheme.lightTheme,
      home: const AuthCheck(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const MainScreen(),
        '/wardrobe': (context) => const WardrobeScreen(),
      },
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  // Flag to control the splash screen animation duration
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _initializeSystem();

    // Timer to keep the Splash Screen visible for 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  Future<void> _initializeSystem() async {
    await _requestAdvancedPermissions();

    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (user != null) {
        await prefs.setString('current_uid', user.uid);
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          await prefs.setString('family_code', doc.data()?['familyCode'] ?? '');
        }
        await initializeService();
      } else {
        await prefs.remove('current_uid');
        await prefs.remove('family_code');
      }
    });
  }

  Future<void> _requestAdvancedPermissions() async {
    await Permission.notification.request();
    await Permission.microphone.request();

    var locStatus = await Permission.location.request();
    if (locStatus.isGranted) {
      await Permission.locationAlways.request();
    }

    await Permission.ignoreBatteryOptimizations.request();
  }

  @override
  Widget build(BuildContext context) {
    // While _showSplash is true, show the animation
    if (_showSplash) {
      return const SplashScreen();
    }

    // After 3 seconds, proceed with the normal Auth logic
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(
                  child: CircularProgressIndicator(color: Colors.deepOrange)));
        }
        if (snapshot.hasData) return const MainScreen();
        return const LoginScreen();
      },
    );
  }
}
