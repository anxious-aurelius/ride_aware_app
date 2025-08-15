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
import 'package:active_commuter_support/models/ride_history_entry.dart'; // <- provides WeatherPoint + RideHistoryEntry
import 'package:active_commuter_support/models/user_preferences.dart';
import 'package:flutter/material.dart';

// Keep RideSlot local (no conflict with your models)
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
  // --- Services ---
  final NotificationService _notificationService = NotificationService();
  final PreferencesService _prefsService = PreferencesService();
  final ApiService _apiService = ApiService();

  // --- State ---
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

  // --- Bottom navigation ---
  int _navIndex = 0;

  // --- UI helpers ---
  static const _hPad = EdgeInsets.symmetric(horizontal: 16);
  static const _sectionGap = SizedBox(height: 18);
  static const _maxContentWidth = 720.0;

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
    if (!mounted) return;
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
    final rideEndToday =
    DateTime(now.year, now.month, now.day, endLocal.hour, endLocal.minute);

    if (now.isAfter(rideEndToday)) {
      final thresholdId = await _prefsService.getCurrentThresholdId();
      final usedId = thresholdId ?? 'auto-${rideEndToday.toIso8601String()}';

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

    final endToday =
    DateTime(start.year, start.month, start.day, endLocal.hour, endLocal.minute);

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
      'summary': 'No issues reported. User closed the feedback without filling.',
    };
    try {
      await _apiService.submitFeedback(payload);
    } catch (_) {}
    if (_pendingFeedbackThresholdId != null) {
      await _prefsService.setFeedbackSubmitted(_pendingFeedbackThresholdId!, true);
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
      if (!mounted) return;
      setState(() {
        _feedbackSummary = result['summary'] as String;
        _endFeedbackGiven = true;
        if (_pendingFeedbackThresholdId != null) {
          _prefsService.setFeedbackSubmitted(_pendingFeedbackThresholdId!, true);
        } else if (_pendingRide != null) {
          _prefsService.setFeedbackSubmitted(_pendingRide!.rideId, true);
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

  // --- Bottom navigation actions ---
  void _onNavTap(int index) async {
    setState(() => _navIndex = index);
    switch (index) {
      case 0: // Weather
        _alertKey.currentState?.openHourlyForecast();
        break;
      case 1: // History
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
        );
        break;
      case 2: // Preferences
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PreferencesScreen()),
        );
        await _loadPrefs();
        break;
    }
  }

  // --- UI Building blocks ---
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      elevation: 1,
      centerTitle: true,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      scrolledUnderElevation: 2,
      title: Text(
        'Dashboard',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
      actions: [
        Tooltip(
          message: 'End Ride',
          child: IconButton(
            onPressed: _manualEndRide,
            icon: const Icon(Icons.stop_circle_outlined),
          ),
        ),
        Tooltip(
          message: 'Settings',
          child: IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PreferencesScreen()),
              );
              await _loadPrefs();
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ),
      ],
    );
  }

  Widget _welcomeHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainer.withOpacity(0.60),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.12)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: cs.primaryContainer,
              child:
              Icon(Icons.pedal_bike, size: 23, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back',
                      style: tt.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      )),
                  const SizedBox(height: 2),
                  Text('Plan ahead for your next ride',
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 16, 10),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _centered({required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: child,
      ),
    );
  }

  /// Do not wrap UpcomingCommuteAlert inside a big card; just a local theme.
  Widget _upcomingCommuteBlock() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final localTheme = theme.copyWith(
      cardTheme: theme.cardTheme.copyWith(
        color: cs.surfaceContainerHighest,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.10)),
        ),
      ),
      chipTheme: theme.chipTheme.copyWith(
        backgroundColor: cs.surfaceContainerHighest,
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.30)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle:
        theme.textTheme.labelMedium?.copyWith(color: cs.onSurface),
      ),
      listTileTheme: theme.listTileTheme.copyWith(
        iconColor: cs.primary,
        textColor: cs.onSurface,
        dense: true,
      ),
      dividerTheme: theme.dividerTheme.copyWith(
        color: cs.outlineVariant.withOpacity(0.06),
        thickness: 1,
        space: 16,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Theme(
        data: localTheme,
        child: UpcomingCommuteAlert(
          key: _alertKey,
          feedbackSummary: _feedbackSummary,
          onThresholdUpdated: _loadPrefs,
          onRideStarted:
              (String rideId, DateTime start, Map<String, dynamic> threshold) async {
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
            final alreadySubmitted =
                await _prefsService.getFeedbackSubmitted(rideId) ?? false;
            if (alreadySubmitted) return;
            final existingPending =
            await _prefsService.getPendingFeedbackThresholdId();
            if (existingPending == rideId) return;
            if (existingPending != null && existingPending != rideId) return;
            // --------------------------

            // Explicit generic to ensure List<WeatherPoint> from models
            final weatherPoints = weatherHistory
                .map<WeatherPoint>((e) => WeatherPoint.fromJson(e))
                .toList();

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

            if (!mounted) return;
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

            await _prefsService.setPendingFeedback(DateTime.now());
            await _prefsService.setPendingFeedbackThresholdId(rideId);
            await _notificationService.showFeedbackNotification();
          },
        ),
      ),
    );
  }

  // We remove the refresh button section entirely (per your screenshot).
  Widget _actionSpacerRemoved() => const SizedBox.shrink();

  // Single “Ride History” shortcut card (kept), matching History styling.
  Widget _rideHistoryShortcut(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
        color: cs.surfaceContainerHighest.withOpacity(0.96),
        child: ListTile(
          leading: Icon(Icons.history, color: cs.primary),
          title: const Text('Ride History',
              style: TextStyle(fontWeight: FontWeight.w600)),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    _resetFlagsIfNewDay();
    final showFeedback = _showFeedback;
    final cs = Theme.of(context).colorScheme;

    final navBar = Theme(
      data: Theme.of(context).copyWith(
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.transparent, // we color the wrapper Container
          indicatorColor: cs.primary.withOpacity(0.12),
          iconTheme: MaterialStateProperty.all(
            IconThemeData(color: cs.onSurfaceVariant),
          ),
          labelTextStyle: MaterialStateProperty.all(
            TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          elevation: 0,
          height: 68,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.96),
          border: Border(
            top: BorderSide(color: cs.outlineVariant.withOpacity(0.25)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _navIndex,
            onDestinationSelected: _onNavTap,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.cloud_outlined),
                selectedIcon: Icon(Icons.cloud),
                label: 'Weather',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                selectedIcon: Icon(Icons.history_rounded),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune),
                selectedIcon: Icon(Icons.tune_rounded),
                label: 'Preferences',
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: _buildAppBar(context),
      backgroundColor: cs.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadPrefs();
            _alertKey.currentState?.refreshForecast();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              SliverToBoxAdapter(child: _centered(child: _welcomeHeader(context))),
              SliverToBoxAdapter(child: const SizedBox(height: 10)),

              // Post-ride feedback card
              SliverToBoxAdapter(
                child: _centered(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: showFeedback
                        ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: RideFeedbackCard(
                        feedbackGiven: _endFeedbackGiven,
                        onTap: _endFeedbackGiven ? null : _openFeedbackForm,
                        onClose: _dismissFeedback,
                      ),
                    )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),

              // Upcoming commute
              SliverToBoxAdapter(child: _sectionTitle('Upcoming commute')),
              SliverToBoxAdapter(child: _centered(child: _upcomingCommuteBlock())),

              // (Removed) Refresh Forecast button section
              SliverToBoxAdapter(child: _actionSpacerRemoved()),

              // Ride History shortcut (kept)
              const SliverToBoxAdapter(child: SizedBox(height: 22)),
              SliverToBoxAdapter(child: _centered(child: _rideHistoryShortcut(context))),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: navBar,
    );
  }
}
