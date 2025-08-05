import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/user_preferences.dart';
import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;

  /// Initialize Firebase Cloud Messaging
  Future<void> initialize() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      if (kDebugMode) {
        print(
          '🔔 Notification permission granted: ${settings.authorizationStatus}',
        );
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get the FCM token
        await _getFCMToken();

        // Set up foreground message handling
        _setupForegroundMessageHandling();

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          if (kDebugMode) {
            print('🔄 FCM Token refreshed: $newToken');
          }
          _fcmToken = newToken;
          _sendTokenToBackend(newToken);
        });
      } else {
        if (kDebugMode) {
          print('❌ Notification permission denied');
        }
      }
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _localNotifications.initialize(initSettings);
      tz.initializeTimeZones();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing notifications: $e');
      }
    }
  }

  /// Get FCM token and send to backend
  Future<void> _getFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        _fcmToken = token;
        if (kDebugMode) {
          print('📱 FCM Token: $token');
        }
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting FCM token: $e');
      }
    }
  }

  /// Send FCM token to backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      await _apiService.submitFCMToken(token);
      if (kDebugMode) {
        print('✅ FCM Token sent to backend successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending FCM token to backend: $e');
      }
    }
  }

  /// Set up foreground message handling
  void _setupForegroundMessageHandling() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('📱 Foreground Message: ${message.notification?.title}');
        print('📱 Foreground Body: ${message.notification?.body}');
        print('📱 Data: ${message.data}');
      }

      // Show in-app notification or handle as needed
      _showInAppNotification(message);
    });

    // Handle notification taps when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('📱 Notification tapped: ${message.notification?.title}');
      }
      // Handle navigation or actions when notification is tapped
      _handleNotificationTap(message);
    });
  }

  /// Show in-app notification (you can customize this)
  void _showInAppNotification(RemoteMessage message) {
    // This is a simple implementation - you might want to use a proper notification package
    // or show a custom dialog/snackbar
    if (kDebugMode) {
      print('🔔 Showing in-app notification: ${message.notification?.title}');
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    // Handle what happens when user taps the notification
    // For example, navigate to a specific screen based on message data
    if (kDebugMode) {
      print('👆 Handling notification tap: ${message.data}');
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    NotificationSettings settings = await _firebaseMessaging
        .getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Request notification permissions (can be called manually)
  Future<bool> requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging
        .requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<void> scheduleFeedbackNotifications(CommuteWindows windows) async {
    final now = DateTime.now();
    final morning = windows.morningLocal;
    final evening = windows.eveningLocal;
    final morningTime = DateTime(
      now.year,
      now.month,
      now.day,
      morning.hour,
      morning.minute,
    );
    final eveningTime = DateTime(
      now.year,
      now.month,
      now.day,
      evening.hour,
      evening.minute,
    );
    await _scheduleLocal(1, morningTime);
    await _scheduleLocal(2, eveningTime);
  }

  Future<void> _scheduleLocal(int id, DateTime time) async {
    await _localNotifications.zonedSchedule(
      id,
      'Your commute is over',
      'Tap to give feedback on your ride.',
      tz.TZDateTime.from(time, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails('feedback', 'Feedback'),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
