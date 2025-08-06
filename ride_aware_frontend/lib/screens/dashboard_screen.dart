import 'dart:async';

import 'package:active_commuter_support/app_initializer.dart';
import 'package:active_commuter_support/screens/preferences_screen.dart';
import 'package:active_commuter_support/services/notification_service.dart';
import 'package:active_commuter_support/services/preferences_service.dart';
import 'package:active_commuter_support/widgets/upcoming_commute_alert.dart';
import 'package:active_commuter_support/screens/post_ride_feedback_screen.dart';
import 'package:active_commuter_support/screens/history_screen.dart';
import 'package:active_commuter_support/services/api_service.dart';
import 'package:active_commuter_support/models/ride_history_entry.dart';
import 'package:active_commuter_support/models/user_preferences.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();
  final PreferencesService _prefsService = PreferencesService();
  final ApiService _apiService = ApiService();

  UserPreferences? _prefs;
  String _feedbackSummary = 'You did a great job!';
  bool _endFeedbackGiven = false;
  DateTime _lastReset = DateTime.now();
  bool _feedbackNotificationShown = false;
  bool _historySaved = false;
  Timer? _feedbackTimer;

  final GlobalKey<UpcomingCommuteAlertState> _alertKey =
      GlobalKey<UpcomingCommuteAlertState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _alertKey.currentState?.refreshForecast();
    });
    _feedbackTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  Future<void> _loadPrefs() async {
    final p = await _prefsService.loadPreferences();
    final feedbackGiven = await _prefsService.isEndFeedbackGivenToday();
    setState(() {
      _prefs = p;
      _endFeedbackGiven = feedbackGiven;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _resetFlagsIfNewDay() {
    final now = DateTime.now();
    if (now.year != _lastReset.year ||
        now.month != _lastReset.month ||
        now.day != _lastReset.day) {
      _endFeedbackGiven = false;
      _feedbackSummary = 'You did a great job!';
      _lastReset = now;
      _prefsService.clearEndFeedbackGiven();
      _feedbackNotificationShown = false;
      _historySaved = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _alertKey.currentState?.refreshForecast();
    }
  }

  bool _shouldShowFeedbackCard() {
    if (_prefs == null) return false;
    final now = DateTime.now();

    final start = _prefs!.commuteWindows.startLocal;
    final end = _prefs!.commuteWindows.endLocal;

    // Show the feedback card one hour after the user's current route end time
    final todayEnd =
        DateTime(now.year, now.month, now.day, end.hour, end.minute);
    final showTime = todayEnd.add(const Duration(hours: 1));

    // Hide the card one minute before the next route start time
    DateTime nextStart =
        DateTime(now.year, now.month, now.day, start.hour, start.minute);
    if (now.isAfter(nextStart) || now.isAtSameMomentAs(nextStart)) {
      nextStart = nextStart.add(const Duration(days: 1));
    }
    final hideTime = nextStart.subtract(const Duration(minutes: 1));

    return now.isAfter(showTime) && now.isBefore(hideTime);
  }

  Future<void> _saveRideHistoryIfCompleted() async {
    if (_prefs == null || _historySaved) return;
    final now = DateTime.now();
    final end = _prefs!.commuteWindows.endLocal;
    final todayEnd = DateTime(now.year, now.month, now.day, end.hour, end.minute);
    if (!now.isAfter(todayEnd)) return;
    final result = _alertKey.currentState?.result;
    if (result == null) return;
    final thresholdId = await _prefsService.getCurrentThresholdId();
    if (thresholdId == null) return;

    final entry = RideHistoryEntry(
      thresholdId: thresholdId,
      date: DateTime.now().toUtc(),
      startTime: _prefs!.commuteWindows.startLocal,
      endTime: _prefs!.commuteWindows.endLocal,
      status: result.status,
      summary: result.summary,
      feedback: null,
    );
    try {
      await _apiService.saveRideHistoryEntry(entry);
      _historySaved = true;
    } catch (_) {
      // Ignore network errors for now
    }
  }

  @override
  Widget build(BuildContext context) {
    _resetFlagsIfNewDay();
    _saveRideHistoryIfCompleted();
    final showFeedback = _shouldShowFeedbackCard();
    if (showFeedback && !_endFeedbackGiven && !_feedbackNotificationShown) {
      _notificationService.showFeedbackNotification();
      _feedbackNotificationShown = true;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PreferencesScreen(),
                ),
              );
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Welcome Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.waving_hand, size: 28, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Welcome back!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Plan ahead for your next ride',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),

            // Commute Feedback Card
            if (showFeedback)
              Card(
                color: _endFeedbackGiven ? Colors.grey : Colors.red,
                margin: const EdgeInsets.all(16),
                child: ListTile(
                  leading: const Icon(Icons.feedback, color: Colors.white),
                  title: Text(
                    _endFeedbackGiven
                        ? 'Feedback submitted for your last ride'
                        : 'Feedback available for your last ride',
                  ),
                  onTap: _endFeedbackGiven
                      ? null
                      : () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PostRideFeedbackScreen(
                                commute: 'end',
                              ),
                            ),
                          );
                          if (result != null) {
                            setState(() {
                              _feedbackSummary = result['summary'] as String;
                              _endFeedbackGiven = true;
                            });
                            _prefsService.setEndFeedbackGiven(DateTime.now());
                          }
                        },
                ),
              ),

            // Commute Status Panel
            UpcomingCommuteAlert(
              key: _alertKey,
              feedbackSummary: _feedbackSummary,
            ),

            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Ride History'),
                subtitle: const Text('View your last 30 days of rides'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HistoryScreen(),
                    ),
                  );
                },
              ),
            ),

            // Notification Status Card
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      size: 48,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<bool>(
                      future: _notificationService.areNotificationsEnabled(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final enabled = snapshot.data!;
                          return Column(
                            children: [
                              Text(
                                enabled
                                    ? 'Weather alerts are enabled'
                                    : 'Weather alerts are disabled',
                                style: TextStyle(
                                  color: enabled ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (!enabled) ...[
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    final granted = await _notificationService
                                        .requestPermissions();
                                    if (granted) {
                                      setState(() {}); // Refresh the UI
                                    }
                                  },
                                  child: const Text('Enable Notifications'),
                                ),
                              ],
                            ],
                          );
                        }
                        return const CircularProgressIndicator();
                      },
                    ),
                    const SizedBox(height: 8),
                    if (_notificationService.fcmToken != null)
                      Text(
                        'Token: ${_notificationService.fcmToken!.substring(0, 20)}...',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // // Feedback Summary Card
            // Card(
            //   margin: const EdgeInsets.all(16),
            //   child: Padding(
            //     padding: const EdgeInsets.all(16),
            //     child: Column(
            //       children: [
            //         const Icon(Icons.insights, size: 48),
            //         const SizedBox(height: 8),
            //         Text(
            //           _feedbackSummary,
            //           textAlign: TextAlign.center,
            //           style: const TextStyle(
            //             fontSize: 18,
            //             fontWeight: FontWeight.bold,
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),

            // App Refresh Card
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Refresh App'),
                subtitle:
                    const Text('Restart the app and reload all data'),
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const AppInitializer()),
                    (route) => false,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
