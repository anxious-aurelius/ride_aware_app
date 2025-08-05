import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../viewmodels/upcoming_commute_view_model.dart';
import '../utils/parsing.dart';
import '../utils/i18n.dart';
import '../models/user_preferences.dart';
import '../services/preferences_service.dart';
import '../services/api_service.dart';

// Helper classes defined outside the widget
class _WeatherMetric {
  final IconData icon;
  final String caption;
  final String description;
  final String subDescription;
  final Color color;

  const _WeatherMetric(
    this.icon,
    this.caption,
    this.description,
    this.subDescription,
    this.color,
  );
}

class _StatusInfo {
  final Color color;
  final IconData icon;
  final String label;
  const _StatusInfo(this.color, this.icon, this.label);
}

class UpcomingCommuteAlert extends StatefulWidget {
  final String feedbackSummary;

  const UpcomingCommuteAlert({
    super.key,
    this.feedbackSummary = 'You did a great job!',
  });

  @override
  State<UpcomingCommuteAlert> createState() => _UpcomingCommuteAlertState();
}

class _UpcomingCommuteAlertState extends State<UpcomingCommuteAlert> {
  final UpcomingCommuteViewModel _vm = UpcomingCommuteViewModel();
  final PreferencesService _preferencesService = PreferencesService();
  final ApiService _apiService = ApiService();

  final TextEditingController _windSpeedController = TextEditingController();
  final TextEditingController _rainIntensityController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();
  final TextEditingController _minTemperatureController = TextEditingController();
  final TextEditingController _maxTemperatureController = TextEditingController();

  double _headwindSensitivity = 20.0;
  double _crosswindSensitivity = 15.0;

  final GlobalKey<FormState> _thresholdFormKey = GlobalKey<FormState>();
  bool _showThresholdForm = false;
  bool _isSaving = false;

  UserPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('📋 UpcomingCommuteAlert initialized');
    }
    _vm.addListener(_onUpdate);
    _vm.load();
    _loadPrefs();
  }

  void _onUpdate() => setState(() {});

  Future<void> _loadPrefs() async {
    final prefs = await _preferencesService.loadPreferences();
    setState(() {
      _prefs = prefs;
    });
  }

  @override
  void dispose() {
    _vm.removeListener(_onUpdate);
    _windSpeedController.dispose();
    _rainIntensityController.dispose();
    _humidityController.dispose();
    _minTemperatureController.dispose();
    _maxTemperatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_vm.needsCommuteTime) {
      return _buildSetTimeCard(theme);
    }
    if (_vm.isLoading) {
      return _buildLoadingCard(theme);
    }
    if (_vm.error != null) {
      return _buildErrorCard(theme);
    }

    final result = _vm.result!;
    final limits = result.limits;
    final status = _statusInfo(result.status);

    bool showPostCommuteCard = false;
    if (_prefs != null) {
      final now = DateTime.now();
      final morning = _prefs!.commuteWindows.morningLocal;
      final todayMorningTime = DateTime(
        now.year,
        now.month,
        now.day,
        morning.hour,
        morning.minute,
      );
      showPostCommuteCard = now.isAfter(todayMorningTime);
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 8,
      shadowColor: status.color.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(theme, status, result),
            _buildWeatherMetrics(theme, result, limits),
            if (result.issues.isNotEmpty)
              _buildIssuesSection(result, status.color, theme),
            if (showPostCommuteCard) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.withOpacity(0.15),
                        Colors.green.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.thumb_up, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.feedbackSummary.isNotEmpty
                                  ? widget.feedbackSummary
                                  : 'You did a great job!',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'If you want to adjust your thresholds for next time, tap below:',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      !_showThresholdForm
                          ? _buildAdjustThresholdsCTA(theme)
                          : _buildThresholdForm(theme),
                    ],
                  ),
                ),
              ),
            ],
            _buildActionSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(
    ThemeData theme,
    _StatusInfo status,
    CommuteAlertResult result,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            status.color.withOpacity(0.15),
            status.color.withOpacity(0.05),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Main header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: status.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: status.color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.directions_bike,
                  size: 28,
                  color: status.color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  t('Upcoming Commute'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: status.color,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: status.color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(status.icon, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      t(status.label),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Date/time row
          Row(
            children: [
              const SizedBox(
                width: 56,
              ), // Align with text above (icon width + padding)
              Icon(
                Icons.schedule,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                _formatDateTime(result.time),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherMetrics(
    ThemeData theme,
    CommuteAlertResult result,
    WeatherLimits limits,
  ) {
    // Temperature evaluation
    final minTemp = parseDouble(result.summary['min_temp']);
    final maxTemp = parseDouble(result.summary['max_temp']);
    String tempCaption;
    IconData tempIcon;
    Color tempColor;
    if (minTemp < limits.minTemperature) {
      tempCaption = 'Too Cold';
      tempIcon = Icons.ac_unit;
      tempColor = Colors.red;
    } else if (maxTemp > limits.maxTemperature) {
      tempCaption = 'Too Warm';
      tempIcon = Icons.local_fire_department;
      tempColor = Colors.red;
    } else {
      tempCaption = 'Comfortable';
      tempIcon = Icons.thermostat;
      tempColor = Colors.green;
    }
    final tempDesc =
        '${minTemp.toStringAsFixed(0)}°C - ${maxTemp.toStringAsFixed(0)}°C';
    final tempSubDesc =
        'Your range: ${limits.minTemperature}°C - ${limits.maxTemperature}°C';

    // Wind speed
    final windSpeed = parseDouble(result.summary['max_wind_speed']) * 3.6;
    final windLimit = limits.maxWindSpeed * 3.6;
    final windColor = _levelColor(windSpeed, windLimit);
    final windIcon = windColor == Colors.green ? Icons.air : Icons.warning;
    final windDesc = '${windSpeed.toStringAsFixed(0)} km/h gusts';
    final windSubDesc = 'Your limit: ${windLimit.toStringAsFixed(0)} km/h';

    // Headwind & Crosswind
    final headwind = parseDouble(result.summary['max_headwind']) * 3.6;
    final crosswind = parseDouble(result.summary['max_crosswind']) * 3.6;
    final headLimit = limits.headwindSensitivity * 3.6;
    final crossLimit = limits.crosswindSensitivity * 3.6;
    final windDirColor = _combineColors(
      _riskColor(headwind, headLimit),
      _riskColor(crosswind, crossLimit),
    );
    final windDirDesc =
        'Head: ${headwind.toStringAsFixed(0)} | Cross: ${crosswind.toStringAsFixed(0)} km/h';
    final windDirSubDesc =
        'Limits: ${headLimit.toStringAsFixed(0)} | ${crossLimit.toStringAsFixed(0)} km/h';

    // Rain
    final rain = parseDouble(result.summary['max_rain']);
    final rainLimit = limits.maxRainIntensity;
    final rainColor = _levelColor(rain, rainLimit);
    final rainDesc = '${rain.toStringAsFixed(1)} mm/hr expected';
    final rainSubDesc = 'Your limit: ${rainLimit.toStringAsFixed(1)} mm/hr';

    // Humidity
    final humidity = parseDouble(result.summary['max_humidity']);
    final humidityLimit = limits.maxHumidity.toDouble();
    final humidityColor = _levelColor(humidity, humidityLimit);
    final humidityDesc = '${humidity.toStringAsFixed(0)}% humidity';
    final humiditySubDesc = 'Your limit: ${humidityLimit.toStringAsFixed(0)}%';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weather Conditions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildEnhancedWeatherGrid([
            _WeatherMetric(
              tempIcon,
              tempCaption,
              tempDesc,
              tempSubDesc,
              tempColor,
            ),
            _WeatherMetric(
              windIcon,
              'Wind Speed',
              windDesc,
              windSubDesc,
              windColor,
            ),
            _WeatherMetric(
              Icons.explore,
              'Wind Direction',
              windDirDesc,
              windDirSubDesc,
              windDirColor,
            ),
            _WeatherMetric(
              Icons.umbrella,
              'Precipitation',
              rainDesc,
              rainSubDesc,
              rainColor,
            ),
            _WeatherMetric(
              Icons.opacity,
              'Humidity',
              humidityDesc,
              humiditySubDesc,
              humidityColor,
            ),
          ], theme),
        ],
      ),
    );
  }

  Widget _buildEnhancedWeatherGrid(
    List<_WeatherMetric> metrics,
    ThemeData theme,
  ) {
    return Column(
      children: [
        // First row - Temperature (full width)
        _buildEnhancedWeatherCard(metrics[0], theme, isFullWidth: true),
        const SizedBox(height: 12),
        // Second row - Wind Speed and Wind Direction
        Row(
          children: [
            Expanded(child: _buildEnhancedWeatherCard(metrics[1], theme)),
            const SizedBox(width: 12),
            Expanded(child: _buildEnhancedWeatherCard(metrics[2], theme)),
          ],
        ),
        const SizedBox(height: 12),
        // Third row - Rain and Humidity
        Row(
          children: [
            Expanded(child: _buildEnhancedWeatherCard(metrics[3], theme)),
            const SizedBox(width: 12),
            Expanded(child: _buildEnhancedWeatherCard(metrics[4], theme)),
          ],
        ),
      ],
    );
  }

  Widget _buildEnhancedWeatherCard(
    _WeatherMetric metric,
    ThemeData theme, {
    bool isFullWidth = false,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            metric.color.withOpacity(0.1),
            metric.color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: metric.color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: metric.color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: metric.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(metric.icon, color: metric.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t(metric.caption),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t(metric.description),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: metric.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t(metric.subDescription),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (metric.color == Colors.red) {
      return GestureDetector(
        onTap: () => _showConditionWarning(context, metric.caption),
        child: card,
      );
    }
    return card;
  }

  void _showConditionWarning(BuildContext context, String metricName) {
    String message;
    switch (metricName) {
      case 'Humidity':
        message =
            'Humidity is above your set range. Consider bringing an extra water bottle.';
        break;
      case 'Too Cold':
      case 'Too Warm':
        message =
            'Temperature is outside your comfort zone. Consider taking alternative transport or dressing appropriately.';
        break;
      case 'Wind Speed':
      case 'Wind Direction':
        message =
            'Wind conditions are too strong. Consider taking an alternative route.';
        break;
      case 'Rain':
      case 'Precipitation':
        message =
            'Rain is expected. Consider carrying rainwear or waterproof gear.';
        break;
      default:
        message =
            'Weather condition is outside your preferred range. Be careful.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('$metricName Alert')),
        content: Text(t(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t('OK')),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustThresholdsCTA(ThemeData theme) {
    return InkWell(
      onTap: () {
        setState(() {
          _showThresholdForm = true;
        });
        _initThresholdControllers();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.tune, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Adjust Thresholds',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdForm(ThemeData theme) {
    return Form(
      key: _thresholdFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNumberField(
            controller: _windSpeedController,
            label: 'Max Wind Speed (m/s)',
            min: 0,
            max: 200,
          ),
          const SizedBox(height: 12),
          _buildNumberField(
            controller: _rainIntensityController,
            label: 'Max Rain Intensity (mm/hr)',
            min: 0,
            max: 50,
          ),
          const SizedBox(height: 12),
          _buildNumberField(
            controller: _humidityController,
            label: 'Max Humidity (%)',
            min: 0,
            max: 100,
          ),
          const SizedBox(height: 12),
          _buildNumberField(
            controller: _minTemperatureController,
            label: 'Min Temperature (°C)',
            min: -50,
            max: 60,
          ),
          const SizedBox(height: 12),
          _buildNumberField(
            controller: _maxTemperatureController,
            label: 'Max Temperature (°C)',
            min: -50,
            max: 60,
          ),
          const SizedBox(height: 16),
          Text(
            'Headwind Sensitivity (${_headwindSensitivity.toStringAsFixed(0)} km/h)',
            style: theme.textTheme.bodyMedium,
          ),
          Slider(
            value: _headwindSensitivity,
            min: 0,
            max: 50,
            divisions: 50,
            label: _headwindSensitivity.toStringAsFixed(0),
            onChanged: (v) => setState(() => _headwindSensitivity = v),
          ),
          const SizedBox(height: 8),
          Text(
            'Crosswind Sensitivity (${_crosswindSensitivity.toStringAsFixed(0)} km/h)',
            style: theme.textTheme.bodyMedium,
          ),
          Slider(
            value: _crosswindSensitivity,
            min: 0,
            max: 50,
            divisions: 50,
            label: _crosswindSensitivity.toStringAsFixed(0),
            onChanged: (v) => setState(() => _crosswindSensitivity = v),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        setState(() {
                          _showThresholdForm = false;
                        });
                      },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSaving ? null : _saveThresholds,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required double min,
    required double max,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\\d*\\.?\\d*')),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field is required';
        }
        final number = double.tryParse(value);
        if (number == null) {
          return 'Please enter a valid number';
        }
        if (number < min || number > max) {
          return 'Value must be between $min and $max';
        }
        if (controller == _minTemperatureController) {
          final maxTemp = double.tryParse(_maxTemperatureController.text);
          if (maxTemp != null && number > maxTemp) {
            return 'Min temperature must be ≤ max temperature';
          }
        }
        if (controller == _maxTemperatureController) {
          final minTemp = double.tryParse(_minTemperatureController.text);
          if (minTemp != null && number < minTemp) {
            return 'Max temperature must be ≥ min temperature';
          }
        }
        return null;
      },
    );
  }

  Future<void> _initThresholdControllers() async {
    final prefs = await _preferencesService.loadPreferences();
    setState(() {
      _windSpeedController.text = prefs.weatherLimits.maxWindSpeed.toString();
      _rainIntensityController.text =
          prefs.weatherLimits.maxRainIntensity.toString();
      _humidityController.text = prefs.weatherLimits.maxHumidity.toString();
      _minTemperatureController.text =
          prefs.weatherLimits.minTemperature.toString();
      _maxTemperatureController.text =
          prefs.weatherLimits.maxTemperature.toString();
      _headwindSensitivity = prefs.weatherLimits.headwindSensitivity;
      _crosswindSensitivity = prefs.weatherLimits.crosswindSensitivity;
    });
  }

  Future<void> _saveThresholds() async {
    setState(() {
      _isSaving = true;
    });
    if (!_thresholdFormKey.currentState!.validate()) {
      setState(() {
        _isSaving = false;
      });
      return;
    }
    try {
      final newLimits = WeatherLimits(
        maxWindSpeed: double.parse(_windSpeedController.text),
        maxRainIntensity: double.parse(_rainIntensityController.text),
        maxHumidity: double.parse(_humidityController.text),
        minTemperature: double.parse(_minTemperatureController.text),
        maxTemperature: double.parse(_maxTemperatureController.text),
        headwindSensitivity: _headwindSensitivity,
        crosswindSensitivity: _crosswindSensitivity,
      );

      final prefs = await _preferencesService.loadPreferences();
      final updatedPrefs = prefs.copyWith(weatherLimits: newLimits);

      await _apiService.submitThresholds(updatedPrefs);
      await _preferencesService.savePreferencesWithDeviceId(updatedPrefs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thresholds updated!')),
        );
      }

      await _vm.load();

      setState(() {
        _isSaving = false;
        _showThresholdForm = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update thresholds: $e')),
        );
      }
      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _buildIssuesSection(
    CommuteAlertResult result,
    Color color,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.warning_amber, size: 18, color: color),
                ),
                const SizedBox(width: 8),
                Text(
                  t('Weather Alerts'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...result.issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        issue,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _vm.load,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(t('Refresh Forecast')),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer.withOpacity(0.3),
              theme.colorScheme.primaryContainer.withOpacity(0.1),
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Analyzing weather conditions...',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.red.withOpacity(0.1), Colors.red.withOpacity(0.05)],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(Icons.error_outline, color: Colors.red, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load forecast',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('Error: ${_vm.error}'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _vm.load,
              icon: const Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetTimeCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.secondaryContainer.withOpacity(0.3),
              theme.colorScheme.secondaryContainer.withOpacity(0.1),
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.schedule,
                color: theme.colorScheme.secondary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Set Your Commute Time',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('No commute time set'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.access_time),
              label: Text(t('Set Ride Time')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
      'Sunday',
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
          Colors.red,
          Icons.close,
          'Unfavourable Conditions',
        );
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
