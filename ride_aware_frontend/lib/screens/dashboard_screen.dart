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

class RideSlot {
  final String rideId;
  final DateTime start;
  final DateTime end;
  final Map<String, dynamic>? threshold;
  final List<WeatherPoint> weather;

  RideSlot({
    required this.rideId,
    required this.start,
    required this.end,
    this.threshold,
    this.weather = const <WeatherPoint>[],
  });
}

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
  RideSlot? _pendingRide; // last completed, no feedback yet
  RideSlot? _nextRide; // immediate next route after the pending one
  Timer? _tick;
  Timer? _feedbackTicker;
  bool _showFeedback = false;
  String? _pendingFeedbackThresholdId;

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
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      setState(() {}); // existing periodic refresh
    });
    _refreshFeedbackFlag();
    _feedbackTicker =
        Timer.periodic(const Duration(minutes: 1), (_) => _refreshFeedbackFlag());
  }

  Future<void> _loadPrefs() async {
    final p = await _prefsService.loadPreferences();
    final feedbackGiven = await _prefsService.isEndFeedbackGivenToday();
    setState(() {
      _prefs = p;
      _endFeedbackGiven = feedbackGiven;
    });
  }

  Future<void> _refreshFeedbackFlag() async {
    final pendingId = await _prefsService.getPendingFeedbackThresholdId();
    final submitted = pendingId != null
        ? await _prefsService.getFeedbackSubmitted(pendingId)
        : false;
    final hideForNextRide = await _computeHideForNextRide();
    if (!mounted) return;
    setState(() {
      _pendingFeedbackThresholdId = pendingId;
      _endFeedbackGiven = submitted;
      _showFeedback = pendingId != null && !submitted && !hideForNextRide;
    });
  }

  Future<bool> _computeHideForNextRide() async {
    if (_nextRide == null) return false;
    final now = DateTime.now();
    final hideAt = _nextRide!.start.subtract(const Duration(minutes: 1));
    return now.isAfter(hideAt);
  }

  RideSlot? _determineNextRide(DateTime start) {
    if (_prefs == null) return null;
    final windows = _prefs!.commuteWindows;
    final startLocal = windows.startLocal;
    final endLocal = windows.endLocal;

    final endToday = DateTime(
        start.year, start.month, start.day, endLocal.hour, endLocal.minute);

    if (start.isBefore(endToday)) {
      // Morning ride – next is the evening commute
      return RideSlot(
        rideId: '',
        start: endToday,
        end: endToday,
        threshold: null,
        weather: const <WeatherPoint>[],
      );
    }

    // Evening ride – next ride is tomorrow morning
    final nextDay = start.add(const Duration(days: 1));
    final nextMorning = DateTime(
        nextDay.year, nextDay.month, nextDay.day, startLocal.hour, startLocal.minute);
    return RideSlot(
      rideId: '',
      start: nextMorning,
      end: nextMorning,
      threshold: null,
      weather: const <WeatherPoint>[],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _feedbackTicker?.cancel();
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
      _pendingFeedbackThresholdId = null;
      _showFeedback = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _alertKey.currentState?.refreshForecast();
    }
  }


  @override
  Widget build(BuildContext context) {
    _resetFlagsIfNewDay();
    final showFeedback = _showFeedback;
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
                              if (_pendingFeedbackThresholdId != null) {
                                _prefsService.setFeedbackSubmitted(
                                    _pendingFeedbackThresholdId!, true);
                              } else if (_pendingRide != null) {
                                _prefsService.setFeedbackSubmitted(
                                    _pendingRide!.rideId, true);
                              }
                              _showFeedback = false;
                              _pendingFeedbackThresholdId = null;
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

              onRideStarted: (
                String rideId, DateTime start, Map<String, dynamic> threshold) async {
                // No-op for now; could persist active ride
              },

              onRideEnded: (
                  String rideId,
                  DateTime start,
                  DateTime end,
                  String status,
                  Map<String, dynamic> summary,
                  Map<String, dynamic> threshold,
                  List<Map<String, dynamic>> weatherHistory) async {
                final weatherPoints =
                    weatherHistory.map((e) => WeatherPoint.fromJson(e)).toList();
                final entry = RideHistoryEntry(
                  rideId: rideId,
                  start: start,
                  end: end,
                  status: status,
                  summary: summary,
                  threshold: threshold,
                  feedback: null,
                  weather: weatherPoints,
                );
                try {
                  await _apiService.saveRideHistoryEntry(entry);
                } catch (_) {}

                setState(() {
                  _pendingRide = RideSlot(
                    rideId: rideId,
                    start: start,
                    end: end,
                    threshold: threshold,
                    weather: weatherPoints,
                  );
                  _nextRide = _determineNextRide(start);
                  _endFeedbackGiven = false;
                });

                await _prefsService.setPendingFeedback(DateTime.now());
                await _prefsService.setPendingFeedbackThresholdId(rideId);
                await _refreshFeedbackFlag();
              },
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
