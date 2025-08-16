import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import 'preferences_service.dart';

final FlutterLocalNotificationsPlugin _backgroundNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final prefs = PreferencesService();
  final action = message.data['action'];
  final thresholdId = message.data['threshold_id'];

  if (action == 'feedback' && thresholdId != null) {
    await prefs.setPendingFeedbackThresholdId(thresholdId);
    await prefs.setPendingFeedback(DateTime.now());
  } else if (action == 'pre_ride' && thresholdId != null) {
    final body = message.notification?.body ?? '';
    await prefs.setPreRideSummary(thresholdId, body);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
        android: androidSettings, iOS: iosSettings);
    await _backgroundNotificationsPlugin.initialize(initSettings);

    const androidDetails = AndroidNotificationDetails(
      'pre_ride_channel',
      'Pre-Ride Alerts',
      channelDescription: 'Notifications for upcoming ride weather alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _backgroundNotificationsPlugin.show(
      1,
      'Weather Alert: Prepare for your ride',
      body,
      notificationDetails,
    );
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

  Future<void> initialize() async {
    try {
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
          ' Notification permission granted: ${settings.authorizationStatus}',
        );
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosSettings = DarwinInitializationSettings();
        const initSettings = InitializationSettings(
            android: androidSettings, iOS: iosSettings);
        await _localNotificationsPlugin.initialize(initSettings);

        FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler);

        await _getFCMToken();

        _setupForegroundMessageHandling();

        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          if (kDebugMode) {
            print(' FCM Token refreshed: $newToken');
          }
          _fcmToken = newToken;
          _sendTokenToBackend(newToken);
        });
      } else {
        if (kDebugMode) {
          print(' Notification permission denied');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(' Error initializing notifications: $e');
      }
    }
  }

  Future<void> _getFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        _fcmToken = token;
        if (kDebugMode) {
          print(' FCM Token: $token');
        }
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      if (kDebugMode) {
        print(' Error getting FCM token: $e');
      }
    }
  }


  Future<void> _sendTokenToBackend(String token) async {
    try {
      await _apiService.submitFCMToken(token);
      if (kDebugMode) {
        print(' FCM Token sent to backend successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print(' Error sending FCM token to backend: $e');
      }
    }
  }


  void _setupForegroundMessageHandling() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (kDebugMode) {
        print(' Foreground Message: ${message.notification?.title}');
        print(' Foreground Body: ${message.notification?.body}');
        print(' Data: ${message.data}');
      }

      final notif = message.notification;
      final data = message.data;
      final action = data['action'];
      final thresholdId = data['threshold_id'];

      if (notif != null) {
        if (action == 'pre_ride') {
          await showPreRideAlert(notif.body ?? '');
        } else {
          await _showLocalNotification(
            notif.title ?? 'Ride Aware',
            notif.body ?? '',
            payload: action ?? '',
          );
        }
      }

      if (action == 'feedback' && thresholdId != null) {
        await _prefs.setPendingFeedbackThresholdId(thresholdId);
        await _prefs.setPendingFeedback(DateTime.now());
      } else if (action == 'pre_ride' && thresholdId != null) {
        final body = message.notification?.body ?? '';
        await _prefs.setPreRideSummary(thresholdId, body);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final action = message.data['action'];
      final thresholdId = message.data['threshold_id'];
      if (action == 'feedback' && thresholdId != null) {
        await _prefs.setPendingFeedbackThresholdId(thresholdId);
        await _prefs.setPendingFeedback(DateTime.now());
      } else if (action == 'pre_ride' && thresholdId != null) {
        final body = message.notification?.body ?? '';
        await _prefs.setPreRideSummary(thresholdId, body);
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


  String? get fcmToken => _fcmToken;

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

  Future<void> showPreRideAlert(String message) async {
    const androidDetails = AndroidNotificationDetails(
      'pre_ride_channel',
      'Pre-Ride Alerts',
      channelDescription: 'Notifications for upcoming ride weather alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _localNotificationsPlugin.show(
      1,
      'Weather Alert: Prepare for your ride',
      message,
      notificationDetails,
    );
  }


  Future<bool> areNotificationsEnabled() async {
    NotificationSettings settings = await _firebaseMessaging
        .getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }


  Future<bool> requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging
        .requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}
