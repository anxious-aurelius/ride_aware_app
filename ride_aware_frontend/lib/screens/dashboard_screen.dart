import 'package:active_commuter_support/screens/preferences_screen.dart';
import 'package:active_commuter_support/services/notification_service.dart';
import 'package:active_commuter_support/services/preferences_service.dart';
import 'package:active_commuter_support/widgets/upcoming_commute_alert.dart';
import 'package:active_commuter_support/screens/post_ride_feedback_screen.dart';
import 'package:active_commuter_support/models/user_preferences.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final NotificationService _notificationService = NotificationService();
  final PreferencesService _prefsService = PreferencesService();

  UserPreferences? _prefs;
  String _feedbackSummary = 'You did a great job!';
  bool _morningFeedbackGiven = false;
  bool _eveningFeedbackGiven = false;
  DateTime _lastReset = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await _prefsService.loadPreferences();
    await _notificationService.scheduleFeedbackNotifications(p.commuteWindows);
    setState(() {
      _prefs = p;
    });
  }

  void _resetFlagsIfNewDay() {
    final now = DateTime.now();
    if (now.year != _lastReset.year ||
        now.month != _lastReset.month ||
        now.day != _lastReset.day) {
      _morningFeedbackGiven = false;
      _eveningFeedbackGiven = false;
      _feedbackSummary = 'You did a great job!';
      _lastReset = now;
    }
  }

  String? _pendingFeedback() {
    if (_prefs == null) return null;
    final now = TimeOfDay.now();
    final morning = _prefs!.commuteWindows.morningLocal;
    final evening = _prefs!.commuteWindows.eveningLocal;
    bool isAfter(TimeOfDay a, TimeOfDay b) =>
        a.hour > b.hour || (a.hour == b.hour && a.minute >= b.minute);
    // Prioritize evening feedback once the evening commute has passed.
    if (!_eveningFeedbackGiven && isAfter(now, evening)) {
      return 'evening';
    }
    // Show morning feedback any time after the morning commute until it is given.
    if (!_morningFeedbackGiven && isAfter(now, morning)) {
      return 'morning';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    _resetFlagsIfNewDay();
    final pending = _pendingFeedback();
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

            // Commute Status Panel
            const UpcomingCommuteAlert(),

            if (pending != null)
              Card(
                margin: const EdgeInsets.all(16),
                child: ListTile(
                  leading: const Icon(Icons.feedback, color: Colors.orange),
                  title: const Text('Feedback available for your last ride'),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PostRideFeedbackScreen(commuteTime: pending),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _feedbackSummary = result['summary'] as String;
                        if (result['commute'] == 'morning') {
                          _morningFeedbackGiven = true;
                        } else {
                          _eveningFeedbackGiven = true;
                        }
                      });
                    }
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

            // Feedback Summary Card
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.insights, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      _feedbackSummary,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
