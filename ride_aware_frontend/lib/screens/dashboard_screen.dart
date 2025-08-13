import 'dart:async';

import 'package:active_commuter_support/app_initializer.dart';
import 'package:active_commuter_support/screens/preferences_screen.dart';
import 'package:active_commuter_support/services/notification_service.dart';
import 'package:active_commuter_support/services/preferences_service.dart';
import 'package:active_commuter_support/widgets/upcoming_commute_alert.dart';
import 'package:active_commuter_support/widgets/standard_card.dart';
import 'package:active_commuter_support/widgets/standard_list_tile.dart';
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
  DateTime? _pendingFeedbackSince;

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
    final pendingSince = await _prefsService.getPendingFeedbackSince();
    setState(() {
      _prefs = p;
      _endFeedbackGiven = feedbackGiven;
      _pendingFeedbackSince = pendingSince;
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
      _prefsService.setPendingFeedback(null);
      _prefsService.setPendingFeedbackThresholdId(null);
      _pendingFeedbackSince = null;
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

    final startTod = _prefs!.commuteWindows.startLocal;
    final endTod = _prefs!.commuteWindows.endLocal;

    DateTime nextStartLocal = DateTime(
      now.year,
      now.month,
      now.day,
      startTod.hour,
      startTod.minute,
    );
    if (!now.isBefore(nextStartLocal)) {
      nextStartLocal = nextStartLocal.add(const Duration(days: 1));
    }
    final hideTime = nextStartLocal.subtract(const Duration(minutes: 1));

    DateTime prevEndLocal = DateTime(
      now.year,
      now.month,
      now.day,
      endTod.hour,
      endTod.minute,
    );
    if (!now.isAfter(prevEndLocal)) {
      prevEndLocal = prevEndLocal.subtract(const Duration(days: 1));
    }
    final showTime = prevEndLocal.add(const Duration(hours: 1));

    if (now.isAfter(hideTime)) {
      _endFeedbackGiven = false;
      _feedbackSummary = 'You did a great job!';
      _feedbackNotificationShown = false;
      _prefsService.clearEndFeedbackGiven();
      _prefsService.setPendingFeedback(null);
      _prefsService.setPendingFeedbackThresholdId(null);
      _pendingFeedbackSince = null;
      return false;
    }

    if (_pendingFeedbackSince == null && now.isAfter(showTime)) {
      _pendingFeedbackSince = now;
      _prefsService.setPendingFeedback(now);
    }

    return _pendingFeedbackSince != null && now.isAfter(showTime);
  }

  Future<void> _saveRideHistoryIfCompleted() async {
    if (_prefs == null || _historySaved) return;

    final now = DateTime.now();

    final startTod = _prefs!.commuteWindows.startLocal;
    final endTod = _prefs!.commuteWindows.endLocal;

    final todayEndLocal = DateTime(
      now.year,
      now.month,
      now.day,
      endTod.hour,
      endTod.minute,
    );

    if (!now.isAfter(todayEndLocal.add(const Duration(minutes: 1)))) return;

    final result = _alertKey.currentState?.result;
    if (result == null) return;

    final thresholdId = await _prefsService.getCurrentThresholdId();
    if (thresholdId == null) return;

    final startLocal = DateTime(
      now.year,
      now.month,
      now.day,
      startTod.hour,
      startTod.minute,
    );
    final endLocal = DateTime(
      now.year,
      now.month,
      now.day,
      endTod.hour,
      endTod.minute,
    );

    final startUtc = startLocal.toUtc();
    final endUtc = endLocal.toUtc();

    final entry = RideHistoryEntry(
      rideId: thresholdId,
      startUtc: startUtc,
      endUtc: endUtc,
      status: result.status,
      summary: result.summary,
      threshold: null, // TODO: fill your threshold map if you have it
      feedback: null,
      weather: const [], // TODO: populate with snapshots if available
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
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PreferencesScreen(),
                ),
              );
              await _loadPrefs();
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
              StandardCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.feedback,
                    color: _endFeedbackGiven
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.error,
                  ),
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
                              _pendingFeedbackSince = null;
                            });
                            _prefsService.setEndFeedbackGiven(DateTime.now());
                            _prefsService.setPendingFeedback(null);
                            _prefsService.setPendingFeedbackThresholdId(null);
                          }
                        },
                ),
              ),

            // Commute Status Panel
            UpcomingCommuteAlert(
              key: _alertKey,
              feedbackSummary: _feedbackSummary,
              onThresholdUpdated: _loadPrefs,
            ),

            StandardListTile(
              icon: Icons.history,
              title: 'Ride History',
              subtitle: 'View your last 30 days of rides',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HistoryScreen(),
                  ),
                );
              },
            ),

            FutureBuilder<bool>(
              future: _notificationService.areNotificationsEnabled(),
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? false;
                return StandardCard(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable weather alerts'),
                    secondary: Icon(Icons.notifications,
                        color: Theme.of(context).colorScheme.primary),
                    value: enabled,
                    onChanged: (value) async {
                      if (value) {
                        final granted =
                            await _notificationService.requestPermissions();
                        if (granted) setState(() {});
                      } else {
                        // No direct way to revoke permissions; just ignore
                      }
                    },
                  ),
                );
              },
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
            StandardListTile(
              icon: Icons.refresh,
              title: 'Refresh App',
              subtitle: 'Restart the app and reload all data',
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AppInitializer()),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
