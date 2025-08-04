import 'package:flutter/material.dart';
import '../viewmodels/upcoming_commute_view_model.dart';
import '../utils/parsing.dart';
import '../utils/i18n.dart';
import 'commute_summary.dart';
import 'weather_metric_card.dart';

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
          child: Text(t('Error: ${_vm.error}')),
        ),
      );
    }

    final result = _vm.result!;
    final limits = result.limits;
    final status = _statusInfo(result.status);

    // Temperature evaluation
    final minTemp = parseDouble(result.summary['min_temp']);
    final maxTemp = parseDouble(result.summary['max_temp']);
    String tempCaption;
    IconData tempIcon;
    Color tempColor;
    if (minTemp < limits.minTemperature) {
      tempCaption = 'Feels Cold';
      tempIcon = Icons.ac_unit;
      tempColor = Colors.amber;
    } else if (maxTemp > limits.maxTemperature) {
      tempCaption = 'Feels Warm';
      tempIcon = Icons.local_fire_department;
      tempColor = Colors.amber;
    } else {
      tempCaption = 'Comfortable';
      tempIcon = Icons.thermostat;
      tempColor = Colors.green;
    }
    final tempDesc =
        'Forecast: ${minTemp.toStringAsFixed(0)}°C–${maxTemp.toStringAsFixed(0)}°C • Your comfort range: ${limits.minTemperature}°C–${limits.maxTemperature}°C';

    // Wind speed
    final windSpeed = parseDouble(result.summary['max_wind_speed']) * 3.6;
    final windLimit = limits.maxWindSpeed * 3.6;
    final windColor = _levelColor(windSpeed, windLimit);
    final windIcon = windColor == Colors.green ? Icons.air : Icons.warning;
    final windDesc =
        'Strong gusts up to ${windSpeed.toStringAsFixed(0)} km/h (Your limit: ${windLimit.toStringAsFixed(0)} km/h)';

    // Headwind & Crosswind
    final headwind = parseDouble(result.summary['max_headwind']) * 3.6;
    final crosswind = parseDouble(result.summary['max_crosswind']) * 3.6;
    final headLimit = limits.headwindSensitivity * 3.6;
    final crossLimit = limits.crosswindSensitivity * 3.6;
    final headRisk = _riskLevel(headwind, headLimit);
    final crossRisk = _riskLevel(crosswind, crossLimit);
    final windDirColor = _combineColors(
      _riskColor(headwind, headLimit),
      _riskColor(crosswind, crossLimit),
    );
    final windDirDesc =
        'Headwind risk: $headRisk • Crosswind: $crossRisk (Your limits: Headwind ${headLimit.toStringAsFixed(0)} km/h, Crosswind ${crossLimit.toStringAsFixed(0)} km/h)';

    // Rain
    final rain = parseDouble(result.summary['max_rain']);
    final rainLimit = limits.maxRainIntensity;
    final rainColor = _levelColor(rain, rainLimit);
    final rainDesc =
        'Expected: ${rain.toStringAsFixed(1)} mm/hr • You’re comfortable up to: ${rainLimit.toStringAsFixed(1)} mm/hr';

    // Humidity
    final humidity = parseDouble(result.summary['max_humidity']);
    final humidityLimit = limits.maxHumidity.toDouble();
    final humidityColor = _levelColor(humidity, humidityLimit);
    final humidityDesc =
        'Forecast: ${humidity.toStringAsFixed(0)}% • You prefer ≤ ${humidityLimit.toStringAsFixed(0)}%';

    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: status.color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t('Upcoming Commute'),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(status.icon, color: status.color),
                const SizedBox(width: 4),
                Text(
                  t(status.label),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: status.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CommuteSummary(
                  dateLabel: _formatDateTime(result.time),
                  routeName: result.route.routeName,
                ),
                const SizedBox(height: 12),
                WeatherMetricCard(
                  icon: tempIcon,
                  caption: tempCaption,
                  description: tempDesc,
                  color: tempColor,
                ),
                WeatherMetricCard(
                  icon: windIcon,
                  caption: 'Wind Gusts',
                  description: windDesc,
                  color: windColor,
                ),
                WeatherMetricCard(
                  icon: Icons.explore,
                  caption: 'Wind Direction Impact',
                  description: windDirDesc,
                  color: windDirColor,
                ),
                WeatherMetricCard(
                  icon: Icons.umbrella,
                  caption: 'Chance of Rain',
                  description: rainDesc,
                  color: rainColor,
                ),
                WeatherMetricCard(
                  icon: Icons.opacity,
                  caption: 'Humidity',
                  description: humidityDesc,
                  color: humidityColor,
                ),
                if (result.issues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _issuesSection(result, status.color, theme),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _vm.load,
                    icon: const Icon(Icons.refresh),
                    label: Text(t('Re-evaluate Commute')),
                  ),
                ),
              ],
            ),
          ),
        ],
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
              Text(t('Issues'),
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
            Text(t('No commute time set')),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _pickTime,
              child: Text(t('Set Ride Time')),
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

  _StatusInfo _statusInfo(String status) {
    switch (status) {
      case 'alert':
        return const _StatusInfo(
            Colors.red, Icons.close, 'Unfavourable Conditions');
      case 'warning':
        return const _StatusInfo(Colors.amber, Icons.warning, 'Caution');
      default:
        return const _StatusInfo(Colors.green, Icons.check, 'All Clear');
    }
  }

  Color _levelColor(double value, double limit) {
    if (value > limit) return Colors.red;
    if (value > limit * 0.7) return Colors.amber;
    return Colors.green;
  }

  String _riskLevel(double value, double limit) {
    if (value > limit) return 'High';
    if (value > limit * 0.7) return 'Moderate';
    return 'Low';
  }

  Color _riskColor(double value, double limit) {
    if (value > limit) return Colors.red;
    if (value > limit * 0.7) return Colors.amber;
    return Colors.green;
  }

  Color _combineColors(Color a, Color b) {
    if (a == Colors.red || b == Colors.red) return Colors.red;
    if (a == Colors.amber || b == Colors.amber) return Colors.amber;
    return Colors.green;
  }

}

class _StatusInfo {
  final Color color;
  final IconData icon;
  final String label;
  const _StatusInfo(this.color, this.icon, this.label);
}
