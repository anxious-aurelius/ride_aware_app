import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import 'preferences_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final prefs = PreferencesService();
  final action = message.data['action'];
  final thresholdId = message.data['threshold_id'];

  if (action == 'feedback' && thresholdId != null) {
    await prefs.setPendingFeedbackThresholdId(thresholdId);
    await prefs.setPendingFeedback(DateTime.now());
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final PreferencesService _prefs = PreferencesService();

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
        // Initialize local notifications
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosSettings = DarwinInitializationSettings();
        const initSettings = InitializationSettings(
            android: androidSettings, iOS: iosSettings);
        await _localNotificationsPlugin.initialize(initSettings);

        // Register background handler
        FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler);

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

  /// Set up foreground and tapped message handling
  void _setupForegroundMessageHandling() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (kDebugMode) {
        print('📱 Foreground Message: ${message.notification?.title}');
        print('📱 Foreground Body: ${message.notification?.body}');
        print('📱 Data: ${message.data}');
      }

      final notif = message.notification;
      final data = message.data;
      final action = data['action'];
      final thresholdId = data['threshold_id'];

      if (notif != null) {
        await _showLocalNotification(
          notif.title ?? 'Ride Aware',
          notif.body ?? '',
          payload: action ?? '',
        );
      }

      if (action == 'feedback' && thresholdId != null) {
        await _prefs.setPendingFeedbackThresholdId(thresholdId);
        await _prefs.setPendingFeedback(DateTime.now());
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final action = message.data['action'];
      final thresholdId = message.data['threshold_id'];
      if (action == 'feedback' && thresholdId != null) {
        await _prefs.setPendingFeedbackThresholdId(thresholdId);
        await _prefs.setPendingFeedback(DateTime.now());
      }
    });
  }

  Future<void> _showLocalNotification(String title, String body,
      {String? payload}) async {
    const android = AndroidNotificationDetails(
      'ride_aware_default',
      'Ride Aware',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    await _localNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Show a local notification indicating feedback is available
  Future<void> showFeedbackNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'feedback_channel',
      'Ride Feedback',
      channelDescription: 'Notifications for ride feedback availability',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _localNotificationsPlugin.show(
      0,
      'Ride feedback ready',
      'Please provide feedback for your last ride.',
      notificationDetails,
    );
  }

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
}
