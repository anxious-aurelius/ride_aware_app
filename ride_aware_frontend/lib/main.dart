import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app_initializer.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await NotificationService().initialize();

  runApp(const ActiveCommuterApp());
}

class ActiveCommuterApp extends StatelessWidget {
  const ActiveCommuterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Active Commuter Support System',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const AppInitializer(),
      debugShowCheckedModeBanner: false,
    );
  }
}
