import 'dart:async';

import 'package:active_commuter_support/app_initializer.dart';
import 'package:active_commuter_support/screens/preferences_screen.dart';
import 'package:active_commuter_support/services/notification_service.dart';
import 'package:active_commuter_support/services/preferences_service.dart';
import 'package:active_commuter_support/widgets/upcoming_commute_alert.dart';
import 'package:active_commuter_support/widgets/standard_card.dart';
import 'package:active_commuter_support/widgets/standard_list_tile.dart';
import 'package:active_commuter_support/widgets/ride_feedback_card.dart';
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

    // Periodic heartbeat:
    _tick = Timer.periodic(const Duration(seconds: 20), (_) async {
      await _maybeAutoEndRide();
      _alertKey.currentState?.maybePreRideAlertCheck();
      if (!mounted) return;
      setState(() {}); // keep UI fresh
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

  Future<void> _maybeAutoEndRide() async {
    if (_prefs == null) return;

    // robust guards (persisted + in-memory)
    if (_showFeedback) return;
    if (_endFeedbackGiven) return;
    final alreadyPendingId = await _prefsService.getPendingFeedbackThresholdId();
    if (alreadyPendingId != null) return; // already created; don't redo

    // extra guard in case memory flag got stale
    final endGivenToday = await _prefsService.isEndFeedbackGivenToday();
    if (endGivenToday) return;

    final now = DateTime.now();
    final endLocal = _prefs!.commuteWindows.endLocal;
    final rideEndToday = DateTime(
        now.year, now.month, now.day, endLocal.hour, endLocal.minute);

    if (now.isAfter(rideEndToday)) {
      final thresholdId = await _prefsService.getCurrentThresholdId();
      final usedId =
          thresholdId ?? 'auto-${rideEndToday.toIso8601String()}';

      // create pending exactly once
      await _prefsService.setPendingFeedback(DateTime.now());
      await _prefsService.setPendingFeedbackThresholdId(usedId);

      _nextRide = _determineNextRide(now);

      if (!mounted) return;
      setState(() {
        _showFeedback = true;
        _endFeedbackGiven = false;
        _pendingFeedbackThresholdId = usedId; // <- use the actual persisted ID
      });

      await _notificationService.showFeedbackNotification();
    }
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

  Future<void> _manualEndRide() async {
    // avoid duplicates
    final alreadyPendingId = await _prefsService.getPendingFeedbackThresholdId();
    if (alreadyPendingId != null) return;

    final thresholdId = await _prefsService.getCurrentThresholdId();
    if (thresholdId == null) return;

    await _prefsService.setPendingFeedback(DateTime.now());
    await _prefsService.setPendingFeedbackThresholdId(thresholdId);
    _nextRide = _determineNextRide(DateTime.now());
    if (!mounted) return;
    setState(() {
      _showFeedback = true;
      _endFeedbackGiven = false;
      _pendingFeedbackThresholdId = thresholdId;
    });

    await _notificationService.showFeedbackNotification();
  }

  Future<void> _dismissFeedback() async {
    final payload = {
      'commute': 'end',
      'temperature_ok': true,
      'wind_speed_ok': true,
      'headwind_ok': true,
      'crosswind_ok': true,
      'precipitation_ok': true,
      'humidity_ok': true,
      'summary':
      'No issues reported. User closed the feedback without filling.',
    };
    try {
      await _apiService.submitFeedback(payload);
    } catch (_) {}
    if (_pendingFeedbackThresholdId != null) {
      await _prefsService.setFeedbackSubmitted(
          _pendingFeedbackThresholdId!, true);
    }
    await _prefsService.setEndFeedbackGiven(DateTime.now());
    await _prefsService.setPendingFeedback(null);
    await _prefsService.setPendingFeedbackThresholdId(null);
    if (!mounted) return;
    setState(() {
      _feedbackSummary =
      'No issues reported. You had no problem with current threshold.';
      _endFeedbackGiven = true;
      _showFeedback = false;
      _pendingFeedbackThresholdId = null;
    });
  }

  Future<void> _openFeedbackForm() async {
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
      await _prefsService.setEndFeedbackGiven(DateTime.now());
      await _prefsService.setPendingFeedback(null);
      await _prefsService.setPendingFeedbackThresholdId(null);
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
            onPressed: _manualEndRide,
            icon: const Icon(Icons.stop),
            tooltip: 'End Ride',
          ),
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

            // Welcome
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

            // Post-ride feedback card
            if (showFeedback)
              RideFeedbackCard(
                feedbackGiven: _endFeedbackGiven,
                onTap: _endFeedbackGiven ? null : _openFeedbackForm,
                onClose: _dismissFeedback,
              ),

            // Commute Status Panel
            UpcomingCommuteAlert(
              key: _alertKey,
              feedbackSummary: _feedbackSummary,
              onThresholdUpdated: _loadPrefs,

              onRideStarted: (String rideId, DateTime start,
                  Map<String, dynamic> threshold) async {
                // Hide any pending feedback when a new ride begins
                await _prefsService.setPendingFeedback(null);
                await _prefsService.setPendingFeedbackThresholdId(null);
                if (!mounted) return;
                setState(() {
                  _showFeedback = false;
                  _pendingRide = null;
                  _pendingFeedbackThresholdId = null;
                });
              },

              onRideEnded: (
                  String rideId,
                  DateTime start,
                  DateTime end,
                  String status,
                  Map<String, dynamic> summary,
                  Map<String, dynamic> threshold,
                  List<Map<String, dynamic>> weatherHistory,
                  ) async {
                // --- IDEMPOTENT GUARDS ---
                // 1) Already submitted? bail.
                final alreadySubmitted =
                    await _prefsService.getFeedbackSubmitted(rideId) ?? false;
                if (alreadySubmitted) {
                  // do not re-show card / re-notify
                  return;
                }
                // 2) Already pending with same ID? bail.
                final existingPending =
                await _prefsService.getPendingFeedbackThresholdId();
                if (existingPending == rideId) {
                  return;
                }
                // 3) If another pending ID exists (rare), don't override to avoid thrash.
                if (existingPending != null && existingPending != rideId) {
                  return;
                }
                // --------------------------

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
                  _showFeedback = true;
                  _pendingFeedbackThresholdId = rideId;
                });

                // mark pending once
                await _prefsService.setPendingFeedback(DateTime.now());
                await _prefsService.setPendingFeedbackThresholdId(rideId);

                // notify once
                await _notificationService.showFeedbackNotification();
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
                        // cannot revoke here; user can in OS settings
                      }
                    },
                  ),
                );
              },
            ),

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
