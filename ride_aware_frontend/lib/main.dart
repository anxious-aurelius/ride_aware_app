import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app_initializer.dart';
import 'services/notification_service.dart';

// Global color definitions for consistent theming
const Color _primaryBlue = Color(0xFF2196F3);
const Color _successGreen = Color(0xFF4CAF50);
const Color _darkBackground = Color(0xFF121212);

// Top-level function to handle background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();

  print("📱 Background Message: ${message.notification?.title}");
  print("📱 Background Body: ${message.notification?.body}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const ActiveCommuterApp());
}

class ActiveCommuterApp extends StatelessWidget {
  const ActiveCommuterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Active Commuter Support System',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryBlue,
        ).copyWith(secondary: _successGreen),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _darkBackground,
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryBlue,
          brightness: Brightness.dark,
        ).copyWith(
          secondary: _successGreen,
          background: _darkBackground,
          surface: const Color(0xFF1E1E1E),
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const AppInitializer(),
      debugShowCheckedModeBanner: false,
    );
  }
}
