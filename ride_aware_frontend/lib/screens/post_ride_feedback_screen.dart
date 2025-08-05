import 'package:flutter/material.dart';
import '../services/commute_status_service.dart';
import '../services/api_service.dart';

class PostRideFeedbackScreen extends StatefulWidget {
  final String commuteTime; // 'morning' or 'evening'
  const PostRideFeedbackScreen({super.key, required this.commuteTime});

  @override
  State<PostRideFeedbackScreen> createState() => _PostRideFeedbackScreenState();
}

class _PostRideFeedbackScreenState extends State<PostRideFeedbackScreen> {
  final CommuteStatusApiService _statusService = CommuteStatusApiService();
  final ApiService _apiService = ApiService();

  late Future<List<String>> _violationsFuture;

  bool temperatureOk = true;
  bool windSpeedOk = true;
  bool headwindOk = true;
  bool crosswindOk = true;
  bool precipitationOk = true;
  bool humidityOk = true;

  @override
  void initState() {
    super.initState();
    _violationsFuture = _loadViolations();
  }

  Future<List<String>> _loadViolations() async {
    final status = await _statusService.getCommuteStatus();
    final data = widget.commuteTime == 'morning'
        ? status.morning
        : status.evening;
    return data.violations;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride Feedback')),
      body: FutureBuilder<List<String>>(
        future: _violationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Failed to load feedback questions'),
            );
          }
          final v = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildQuestion(
                v.contains('temperature')
                    ? 'The temperature was above/below your set range. How did you feel? (Good/Bad)'
                    : 'Temperature was within your comfort range. Were you okay with it? (Good/Bad)',
                temperatureOk,
                (val) => setState(() => temperatureOk = val),
              ),
              _buildQuestion(
                v.contains('wind_speed')
                    ? 'Wind speed was higher than your threshold. Were you comfortable with the wind force? (Yes/No)'
                    : 'You handled the wind well. Did it feel okay? (Yes/No)',
                windSpeedOk,
                (val) => setState(() => windSpeedOk = val),
              ),
              _buildQuestion(
                v.contains('headwind')
                    ? 'Strong headwinds today. Was the headwind too much for you? (Yes/No)'
                    : 'Did you notice any effort from headwind? Was it manageable? (Yes/No)',
                headwindOk,
                (val) => setState(() => headwindOk = val),
              ),
              _buildQuestion(
                v.contains('crosswind')
                    ? 'Notable crosswinds occurred. Did you feel instability due to crosswinds? (Yes/No)'
                    : 'Any crosswind during the ride – did you stay stable? (Yes/No)',
                crosswindOk,
                (val) => setState(() => crosswindOk = val),
              ),
              _buildQuestion(
                v.contains('precipitation')
                    ? 'It was quite wet. Were the conditions too wet for you? (Yes/No)'
                    : 'Conditions stayed fairly dry. Were they okay for you? (Yes/No)',
                precipitationOk,
                (val) => setState(() => precipitationOk = val),
              ),
              _buildQuestion(
                v.contains('humidity')
                    ? 'Humidity was high. Did you feel itchy or uncomfortable from sweat? (Yes/No)'
                    : 'Humidity was moderate. Were you comfortable regarding sweat? (Yes/No)',
                humidityOk,
                (val) => setState(() => humidityOk = val),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _submit, child: const Text('Submit')),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuestion(String text, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(text),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.green,
      inactiveThumbColor: Colors.red,
    );
  }

  Future<void> _submit() async {
    final payload = {
      'commute_time': widget.commuteTime,
      'temperature_ok': temperatureOk,
      'wind_speed_ok': windSpeedOk,
      'headwind_ok': headwindOk,
      'crosswind_ok': crosswindOk,
      'precipitation_ok': precipitationOk,
      'humidity_ok': humidityOk,
    };
    try {
      await _apiService.submitFeedback(payload);
      final summary = _generateSummary();
      if (context.mounted) {
        Navigator.pop(context, {
          'summary': summary,
          'commute': widget.commuteTime,
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit feedback: $e')),
        );
      }
    }
  }

  String _generateSummary() {
    final issues = <String>[];
    if (!temperatureOk) issues.add('temperature');
    if (!windSpeedOk) issues.add('wind speed');
    if (!headwindOk) issues.add('headwind');
    if (!crosswindOk) issues.add('crosswind');
    if (!precipitationOk) issues.add('precipitation');
    if (!humidityOk) issues.add('humidity');
    if (issues.isEmpty) {
      return 'All good! You were comfortable with today\'s ride conditions.';
    }
    return 'You had trouble with ${issues.join(' and ')}. Consider adjusting your thresholds.';
  }
}
