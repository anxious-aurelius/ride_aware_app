import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

import '../models/user_preferences.dart';
import '../models/geo_point.dart';
import '../models/route_model.dart';
import '../services/api_service.dart';
import '../services/preferences_service.dart';
import '../services/device_id_service.dart';
import '../services/routing_service.dart';
import 'dashboard_screen.dart';
import 'map_preview_screen.dart';
import 'location_picker_screen.dart';
import '../app_initializer.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _preferencesService = PreferencesService();
  final _deviceIdService = DeviceIdService();
  final _routingService = RoutingService();

  // Controllers
  final _windSpeedController = TextEditingController();
  final _rainIntensityController = TextEditingController();
  final _humidityController = TextEditingController();
  final _minTemperatureController = TextEditingController();
  final _maxTemperatureController = TextEditingController();
  final _visibilityController = TextEditingController();
  final _pollutionController = TextEditingController();
  final _uvIndexController = TextEditingController();

  double _headwindSensitivity = 20.0;
  double _crosswindSensitivity = 15.0;

  // Route specific
  final _homeLatController = TextEditingController();
  final _homeLonController = TextEditingController();
  final _officeLatController = TextEditingController();
  final _officeLonController = TextEditingController();

  // Route time (local)
  TimeOfDay _routeStartTime = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _routeEndTime = const TimeOfDay(hour: 17, minute: 30);

  UserPreferences _currentPreferences = UserPreferences.defaultValues();
  bool _isSubmitting = false;
  bool _isGettingLocation = false;
  bool _isLoading = true;
  bool _isFetchingRoute = false;

  List<LatLng> _routePolylinePoints = [];
  LatLng? _startMarkerPoint;
  LatLng? _endMarkerPoint;

  @override
  void initState() {
    super.initState();
    _loadExistingPreferences();
  }

  @override
  void dispose() {
    _windSpeedController.dispose();
    _rainIntensityController.dispose();
    _humidityController.dispose();
    _minTemperatureController.dispose();
    _maxTemperatureController.dispose();
    _visibilityController.dispose();
    _pollutionController.dispose();
    _uvIndexController.dispose();
    _homeLatController.dispose();
    _homeLonController.dispose();
    _officeLatController.dispose();
    _officeLonController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPreferences() async {
    try {
      final preferences = await _preferencesService.loadPreferences();
      setState(() {
        _currentPreferences = preferences;
        _populateControllers(preferences);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load existing preferences');
    }
  }

  void _populateControllers(UserPreferences preferences) {
    _windSpeedController.text = preferences.weatherLimits.maxWindSpeed.toString();
    _rainIntensityController.text = preferences.weatherLimits.maxRainIntensity.toString();
    _humidityController.text = preferences.weatherLimits.maxHumidity.toString();
    _minTemperatureController.text = preferences.weatherLimits.minTemperature.toString();
    _maxTemperatureController.text = preferences.weatherLimits.maxTemperature.toString();
    _headwindSensitivity = preferences.weatherLimits.headwindSensitivity;
    _crosswindSensitivity = preferences.weatherLimits.crosswindSensitivity;

    _visibilityController.text = preferences.environmentalRisk.minVisibility.toString();
    _pollutionController.text = preferences.environmentalRisk.maxPollution.toString();
    _uvIndexController.text = preferences.environmentalRisk.maxUvIndex.toString();

    if (!preferences.officeLocation.isEmpty) {
      _officeLatController.text = preferences.officeLocation.latitude.toStringAsFixed(6);
      _officeLonController.text = preferences.officeLocation.longitude.toStringAsFixed(6);
    }

    _routeStartTime = preferences.commuteWindows.startLocal;
    _routeEndTime = preferences.commuteWindows.endLocal;

    if (kDebugMode) {
      print('Time Debug:');
      print('   Stored Route Start: ${preferences.commuteWindows.start}');
      print('   Displayed Start Local: ${_formatTimeOfDay(_routeStartTime)}');
      print('   Stored Route End: ${preferences.commuteWindows.end}');
      print('   Displayed End Local: ${_formatTimeOfDay(_routeEndTime)}');
    }
  }

  String _formatTimeOfDay(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  UserPreferences _createPreferencesFromForm() {
    final startStr = CommuteWindows.localTimeOfDayToString(_routeStartTime);
    final endStr = CommuteWindows.localTimeOfDayToString(_routeEndTime);

    if (kDebugMode) {
      print('Time for Storage:');
      print('   Start: $startStr');
      print('   End: $endStr');
    }

    return UserPreferences(
      weatherLimits: WeatherLimits(
        maxWindSpeed: double.parse(_windSpeedController.text),
        maxRainIntensity: double.parse(_rainIntensityController.text),
        maxHumidity: double.parse(_humidityController.text),
        minTemperature: double.parse(_minTemperatureController.text),
        maxTemperature: double.parse(_maxTemperatureController.text),
        headwindSensitivity: _headwindSensitivity,
        crosswindSensitivity: _crosswindSensitivity,
      ),
      environmentalRisk: EnvironmentalRisk(
        minVisibility: double.parse(_visibilityController.text),
        maxPollution: double.parse(_pollutionController.text),
        maxUvIndex: double.parse(_uvIndexController.text),
      ),
      officeLocation: OfficeLocation(
        latitude: double.tryParse(_officeLatController.text) ?? 0.0,
        longitude: double.tryParse(_officeLonController.text) ?? 0.0,
      ),
      commuteWindows: CommuteWindows(start: startStr, end: endStr),
    );
  }

  Future<void> _selectRouteStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _routeStartTime,
      helpText: 'Select Route Start Time (Local)',
    );
    if (picked != null && picked != _routeStartTime) {
      setState(() => _routeStartTime = picked);
      if (kDebugMode) {
        print('Route Start Time Selected: ${_formatTimeOfDay(picked)}');
      }
    }
  }

  Future<void> _selectRouteEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _routeEndTime,
      helpText: 'Select Route End Time (Local)',
    );
    if (picked != null && picked != _routeEndTime) {
      setState(() => _routeEndTime = picked);
      if (kDebugMode) {
        print('Route End Time Selected: ${_formatTimeOfDay(picked)}');
      }
    }
  }

  Future<void> _useDeviceLocationForHome() async {
    setState(() => _isGettingLocation = true);
    try {
      final location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          _showErrorSnackBar('Location service is disabled');
          return;
        }
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          _showErrorSnackBar('Location permission denied');
          return;
        }
      }

      final locationData = await location.getLocation();
      setState(() {
        _homeLatController.text = locationData.latitude?.toStringAsFixed(6) ?? '';
        _homeLonController.text = locationData.longitude?.toStringAsFixed(6) ?? '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Home location updated successfully')),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to get location: ${e.toString()}');
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _pickLocation({
    required TextEditingController latController,
    required TextEditingController lonController,
    required String title,
  }) async {
    LatLng? initialLocation;
    if (latController.text.isNotEmpty && lonController.text.isNotEmpty) {
      initialLocation = LatLng(
        double.parse(latController.text),
        double.parse(lonController.text),
      );
    }

    final pickedLocation = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: initialLocation,
          title: title,
        ),
      ),
    );

    if (pickedLocation != null) {
      setState(() {
        latController.text = pickedLocation.latitude.toStringAsFixed(6);
        lonController.text = pickedLocation.longitude.toStringAsFixed(6);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title selected.')),
        );
      }
    }
  }

  Future<void> _previewRoute() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Please fill all required fields for route generation.');
      return;
    }

    final homeLat = double.tryParse(_homeLatController.text);
    final homeLon = double.tryParse(_homeLonController.text);
    final officeLat = double.tryParse(_officeLatController.text);
    final officeLon = double.tryParse(_officeLonController.text);

    if (homeLat == null || homeLon == null || officeLat == null || officeLon == null) {
      _showErrorSnackBar('Please enter valid numbers for all route coordinates.');
      return;
    }

    setState(() {
      _isFetchingRoute = true;
      _routePolylinePoints = [];
      _startMarkerPoint = null;
      _endMarkerPoint = null;
    });

    try {
      final startPoint = GeoPoint(latitude: homeLat, longitude: homeLon);
      final endPoint = GeoPoint(latitude: officeLat, longitude: officeLon);
      final routeGeoPoints = await _routingService.fetchRoutePoints(startPoint, endPoint);

      if (kDebugMode) {
        print('Route Points Debug:');
        print('   Total points: ${routeGeoPoints.length}');
        print('   Start point: ${startPoint.latitude}, ${startPoint.longitude}');
        print('   End point: ${endPoint.latitude}, ${endPoint.longitude}');
        if (routeGeoPoints.isNotEmpty) {
          print('   First route point: ${routeGeoPoints.first.latitude}, ${routeGeoPoints.first.longitude}');
          print('   Last route point: ${routeGeoPoints.last.latitude}, ${routeGeoPoints.last.longitude}');
        }
      }

      setState(() {
        _routePolylinePoints = routeGeoPoints.map((gp) => LatLng(gp.latitude, gp.longitude)).toList();
        _startMarkerPoint = LatLng(startPoint.latitude, startPoint.longitude);
        _endMarkerPoint = LatLng(endPoint.latitude, endPoint.longitude);
      });

      if (mounted) {
        final avgLat = (startPoint.latitude + endPoint.latitude) / 2;
        final avgLon = (startPoint.longitude + endPoint.longitude) / 2;
        final mapCenter = LatLng(avgLat, avgLon);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MapPreviewScreen(
              routePoints: _routePolylinePoints,
              mapCenter: mapCenter,
              startPoint: _startMarkerPoint!,
              endPoint: _endMarkerPoint!,
            ),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route previewed successfully!')),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to fetch route: ${e.toString()}');
      setState(() {
        _routePolylinePoints = [];
        _startMarkerPoint = null;
        _endMarkerPoint = null;
      });
    } finally {
      setState(() => _isFetchingRoute = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: cs.error),
    );
  }

  Future<void> _submitPreferencesAndRoute() async {
    if (!_formKey.currentState!.validate()) return;

    if (_routePolylinePoints.isEmpty || _startMarkerPoint == null || _endMarkerPoint == null) {
      _showErrorSnackBar('Please preview the commute route before saving.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final preferences = _createPreferencesFromForm();
      if (!preferences.isValid) {
        _showErrorSnackBar('Please check all fields for valid values');
        return;
      }

      final participantIdHash = await _deviceIdService.getParticipantIdHash();
      if (participantIdHash == null) {
        _showErrorSnackBar('Participant ID not set. Please restart the app and enter your code.');
        return;
      }

      final feedbackGiven = await _preferencesService.isEndFeedbackGivenToday();
      final String? oldThresholdId = await _preferencesService.getCurrentThresholdId();
      final String? newThresholdId = await _apiService.submitThresholds(preferences);

      await _preferencesService.savePreferencesWithDeviceId(preferences);
      await _preferencesService.clearEndFeedbackGiven();

      if (newThresholdId != null && !feedbackGiven && oldThresholdId != null) {
        await _preferencesService.setPendingFeedback(DateTime.now());
        await _preferencesService.setPendingFeedbackThresholdId(oldThresholdId);
      } else {
        await _preferencesService.setPendingFeedback(null);
        await _preferencesService.setPendingFeedbackThresholdId(null);
      }

      final startLocation = GeoPoint(
        latitude: _startMarkerPoint!.latitude,
        longitude: _startMarkerPoint!.longitude,
      );
      final endLocation = GeoPoint(
        latitude: _endMarkerPoint!.latitude,
        longitude: _endMarkerPoint!.longitude,
      );

      final routeModel = RouteModel(
        deviceId: participantIdHash,
        routeName: 'Home to Office',
        startLocation: startLocation,
        endLocation: endLocation,
        routePoints: _routePolylinePoints
            .map((ll) => GeoPoint(latitude: ll.latitude, longitude: ll.longitude))
            .toList(),
      );

      if (kDebugMode) {
        print('   Route Submission Debug:');
        print('   Participant ID Hash (as Device ID): $participantIdHash');
        print('   Route Name: ${routeModel.routeName}');
        print('   Start: ${routeModel.startLocation.latitude}, ${routeModel.startLocation.longitude}');
        print('   End: ${routeModel.endLocation.latitude}, ${routeModel.endLocation.longitude}');
        print('   Total route points: ${routeModel.routePoints.length}');
        print('   Commute Windows: Start ${preferences.commuteWindows.start}, End ${preferences.commuteWindows.end}');
        print('   Commute Windows (Local): Start ${_formatTimeOfDay(_routeStartTime)}, End ${_formatTimeOfDay(_routeEndTime)}');
        print('   Temperature Range: ${preferences.weatherLimits.minTemperature}°C to ${preferences.weatherLimits.maxTemperature}°C');
        print('   Route model JSON: ${jsonEncode(routeModel.toJson())}');
      }

      await _apiService.submitRoute(routeModel);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences and route saved!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save preferences or route: ${e.toString()}');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetAppId() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset App ID?'),
        content: const Text(
          'Are you sure you want to reset your app ID? This will remove your saved preferences and require re-entry of your participant code.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Reset')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _deviceIdService.clearParticipantIdHash();
        await _preferencesService.clearPreferences();
        if (!mounted) return;
        _showErrorSnackBar('App ID and preferences reset. Please re-enter your participant code.');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AppInitializer()),
              (route) => false,
        );
      } catch (e) {
        _showErrorSnackBar('Failed to reset app ID: ${e.toString()}');
      }
    }
  }

  // ---------- UI Helpers (History-style look) ----------
  Widget _sectionCard({required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withOpacity(0.96),
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.18)),
        ),
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _sectionHeader(String title, {IconData? icon}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        if (icon != null) ...[
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? helperText,
    String? unit,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      suffixText: unit,
      filled: true,
      fillColor: cs.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  // ---------- Screen ----------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        centerTitle: true,
        title: const Text('Set preferences'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset App ID',
            onPressed: _resetAppId,
          ),
        ],
      ),
      backgroundColor: cs.surface,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          children: [
            _buildWeatherLimitsSection(),
            const SizedBox(height: 16),
            _buildEnvironmentalRiskSection(),
            const SizedBox(height: 16),
            _buildCommuteWindowsSection(),
            const SizedBox(height: 16),
            _buildCommuteRouteSection(),
            const SizedBox(height: 20),
            _buildSubmitButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ---------- Sections ----------
  Widget _buildWeatherLimitsSection() {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Weather limits', icon: Icons.cloud),
          const SizedBox(height: 12),
          Text(
            'We’ll warn you when conditions cross your comfort thresholds.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _buildNumberField(
            controller: _windSpeedController,
            label: 'Max wind speed',
            helperText: '0 – 200',
            min: 0,
            max: 200,
            unit: 'km/h',
          ),
          const SizedBox(height: 16),
          _sliderBlock(
            title: 'Headwind Sensitivity',
            value: _headwindSensitivity,
            onChanged: (v) => setState(() => _headwindSensitivity = v),
            suffix: '${_headwindSensitivity.round()} km/h',
            description: 'Alert when headwind exceeds this speed during your commute.',
          ),
          const SizedBox(height: 12),
          _sliderBlock(
            title: 'Crosswind Sensitivity',
            value: _crosswindSensitivity,
            onChanged: (v) => setState(() => _crosswindSensitivity = v),
            suffix: '${_crosswindSensitivity.round()} km/h',
            description: 'Alert when crosswind exceeds this speed during your commute.',
          ),
          const SizedBox(height: 12),
          _buildNumberField(
            controller: _rainIntensityController,
            label: 'Max rain intensity',
            helperText: '0 – 50',
            min: 0,
            max: 50,
            allowDecimals: true,
            unit: 'mm/h',
          ),
          const SizedBox(height: 16),
          _buildNumberField(
            controller: _humidityController,
            label: 'Max humidity',
            helperText: '0 – 100',
            min: 0,
            max: 100,
            unit: '%',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  controller: _minTemperatureController,
                  label: 'Min temperature',
                  helperText: '-50 – 60',
                  min: -50,
                  max: 60,
                  unit: '°C',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(
                  controller: _maxTemperatureController,
                  label: 'Max temperature',
                  helperText: '-50 – 60',
                  min: -50,
                  max: 60,
                  unit: '°C',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sliderBlock({
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
    required String suffix,
    required String description,
  }) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: tt.titleSmall),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
              ),
              child: Text(suffix, style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 50,
          divisions: 50,
          label: suffix,
          onChanged: onChanged,
        ),
        Text(description, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildEnvironmentalRiskSection() {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Environmental risk', icon: Icons.health_and_safety_outlined),
          const SizedBox(height: 12),
          Text(
            'Optional limits for visibility, air quality, and UV exposure.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _buildNumberField(
            controller: _visibilityController,
            label: 'Min visibility',
            helperText: '0 – 10000',
            min: 0,
            max: 10000,
            unit: 'm',
          ),
          const SizedBox(height: 16),
          _buildNumberField(
            controller: _pollutionController,
            label: 'Max pollution',
            helperText: '0 – 500',
            min: 0,
            max: 500,
            unit: 'AQI',
          ),
          const SizedBox(height: 16),
          _buildNumberField(
            controller: _uvIndexController,
            label: 'Max UV index',
            helperText: '0 – 15',
            min: 0,
            max: 15,
          ),
        ],
      ),
    );
  }

  Widget _buildCommuteWindowsSection() {
    final now = DateTime.now();
    final timeZoneName = now.timeZoneName;
    final offsetHours = now.timeZoneOffset.inHours;
    final offsetMinutes = now.timeZoneOffset.inMinutes.remainder(60);
    final offsetString =
        '${offsetHours >= 0 ? '+' : ''}$offsetHours:${offsetMinutes.abs().toString().padLeft(2, '0')}';

    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Daily commute schedule', icon: Icons.schedule),
          const SizedBox(height: 8),
          Text(
            'Set your route start and end times for personalised weather alerts.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Local timezone: $timeZoneName (UTC$offsetString)',
            style: tt.bodySmall?.copyWith(color: cs.primary, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _timePickerTile(label: 'Route Start Time', value: _routeStartTime, onTap: _selectRouteStartTime)),
              const SizedBox(width: 12),
              Expanded(child: _timePickerTile(label: 'Route End Time', value: _routeEndTime, onTap: _selectRouteEndTime)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timePickerTile({
    required String label,
    required TimeOfDay value,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tt.titleSmall),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: cs.primary),
                const SizedBox(width: 10),
                Text(_formatTimeOfDay(value), style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommuteRouteSection() {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Commute route (Home → Office)', icon: Icons.map_outlined),
          const SizedBox(height: 12),
          Text('Home location', style: tt.titleSmall),
          const SizedBox(height: 8),
          Text(
            _homeLatController.text.isNotEmpty && _homeLonController.text.isNotEmpty
                ? 'Lat: ${_homeLatController.text}, Lon: ${_homeLonController.text}'
                : 'No home location selected',
            style: tt.bodyMedium,
          ),
          const SizedBox(height: 8),
          _outlinedButton(
            onPressed: () => _pickLocation(
              latController: _homeLatController,
              lonController: _homeLonController,
              title: 'Select Home Location',
            ),
            icon: Icons.place_outlined,
            label: 'Pick Home Location on Map',
          ),
          const SizedBox(height: 8),
          _outlinedButton(
            onPressed: _isGettingLocation ? null : _useDeviceLocationForHome,
            icon: _isGettingLocation ? Icons.hourglass_top : Icons.my_location,
            label: _isGettingLocation ? 'Getting home location…': 'Use current location (Home)',
            showSpinner: _isGettingLocation,
          ),
          const SizedBox(height: 20),
          Text('Office location', style: tt.titleSmall),
          const SizedBox(height: 8),
          Text(
            _officeLatController.text.isNotEmpty && _officeLonController.text.isNotEmpty
                ? 'Lat: ${_officeLatController.text}, Lon: ${_officeLonController.text}'
                : 'No office location selected',
            style: tt.bodyMedium,
          ),
          const SizedBox(height: 8),
          _outlinedButton(
            onPressed: () => _pickLocation(
              latController: _officeLatController,
              lonController: _officeLonController,
              title: 'Select Office Location',
            ),
            icon: Icons.apartment_outlined,
            label: 'Pick Office Location on Map',
          ),
          const SizedBox(height: 16),
          _filledButton(
            onPressed: _isFetchingRoute ? null : _previewRoute,
            icon: Icons.route_outlined,
            label: _isFetchingRoute ? 'Fetching route…' : 'Preview Route',
            busy: _isFetchingRoute,
          ),
          const SizedBox(height: 12),
          if (_routePolylinePoints.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('Route previewed. Ready to save.', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Inputs / Buttons ----------
  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String helperText,
    required double min,
    required double max,
    bool allowDecimals = false,
    String? unit,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [
        allowDecimals
            ? FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
            : FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
      ],
      decoration: _inputDecoration(label: label, helperText: helperText, unit: unit),
      validator: (value) {
        if (value == null || value.isEmpty) return 'This field is required';
        final number = double.tryParse(value);
        if (number == null) return 'Please enter a valid number';
        if (number < min || number > max) return 'Value must be between $min and $max';

        // Temperature cross-validation
        if (controller == _minTemperatureController) {
          final maxTemp = double.tryParse(_maxTemperatureController.text);
          if (maxTemp != null && number > maxTemp) return 'Min temperature must be ≤ max temperature';
        }
        if (controller == _maxTemperatureController) {
          final minTemp = double.tryParse(_minTemperatureController.text);
          if (minTemp != null && number < minTemp) return 'Max temperature must be ≥ min temperature';
        }
        return null;
      },
    );
  }

  Widget _outlinedButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    bool showSpinner = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: showSpinner
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : Icon(icon, color: cs.primary),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(label),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _filledButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    bool busy = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: busy
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final disabled = _isSubmitting || _isGettingLocation || _isFetchingRoute || _routePolylinePoints.isEmpty;
    return _filledButton(
      onPressed: disabled ? null : _submitPreferencesAndRoute,
      icon: Icons.save_outlined,
      label: _isSubmitting ? 'Saving…' : 'Save',
      busy: _isSubmitting,
    );
  }
}
