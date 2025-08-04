import 'package:flutter/material.dart';
import '../viewmodels/upcoming_commute_view_model.dart';
import '../utils/parsing.dart';

class UpcomingCommuteAlert extends StatefulWidget {
  const UpcomingCommuteAlert({super.key});

  @override
  State<UpcomingCommuteAlert> createState() => _UpcomingCommuteAlertState();
}

class _UpcomingCommuteAlertState extends State<UpcomingCommuteAlert> {
  final UpcomingCommuteViewModel _vm = UpcomingCommuteViewModel();

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onUpdate);
    _vm.load();
  }

  void _onUpdate() => setState(() {});

  @override
  void dispose() {
    _vm.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_vm.needsCommuteTime) {
      return _buildSetTimeCard(theme);
    }
    if (_vm.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_vm.error != null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: ${_vm.error}'),
        ),
      );
    }
    final result = _vm.result!;
    final limits = result.limits;
    final color = result.status == 'alert'
        ? Colors.red
        : result.status == 'warning'
            ? Colors.amber
            : Colors.green;
    final icon = result.status == 'alert'
        ? Icons.error
        : result.status == 'warning'
            ? Icons.warning
            : Icons.check_circle;
    final headwind = parseDouble(result.forecast['headwind']);
    final crosswind = parseDouble(result.forecast['crosswind']);
    return Card(
      margin: const EdgeInsets.all(16),
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text('Upcoming Commute Alert',
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Next ride: ${_formatDateTime(result.time)}, Route: ${result.route.routeName}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _metricRow('Temperature',
                '${result.forecast['temp']}°C',
                'range ${limits.minTemperature}-${limits.maxTemperature}°C'),
            _metricRow('Wind speed',
                '${result.forecast['wind_speed']} m/s',
                'max ${limits.maxWindSpeed} m/s'),
            _metricRow('Headwind',
                '${headwind.toStringAsFixed(1)} m/s',
                'max ${limits.headwindSensitivity} m/s'),
            _metricRow('Crosswind',
                '${crosswind.toStringAsFixed(1)} m/s',
                'max ${limits.crosswindSensitivity} m/s'),
            _metricRow('Rain',
                '${result.forecast['rain'] ?? 0} mm',
                'max ${limits.maxRainIntensity} mm'),
            _metricRow('Humidity',
                '${result.forecast['humidity']}%',
                'max ${limits.maxHumidity}%'),
            if (result.issues.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _issuesSection(result, color, theme),
              ),
          ],
        ),
      ),
    );
  }

  Widget _issuesSection(
      CommuteAlertResult result, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, size: 16, color: color),
              const SizedBox(width: 6),
              Text('Issues',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ...result.issues
              .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('• $e',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: color)),
                  ))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildSetTimeCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No commute time set'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _pickTime,
              child: const Text('Set Ride Time'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      await _vm.setCommuteTime(picked);
    }
  }

  String _formatDateTime(DateTime dt) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final day = days[dt.weekday - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $hour:$minute $ampm';
  }

  Widget _metricRow(String label, String value, String threshold) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(threshold,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
