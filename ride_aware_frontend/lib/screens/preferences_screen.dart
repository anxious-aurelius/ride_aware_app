import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:latlong2/latlong.dart'; // Only LatLng needed here now
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
import '../app_initializer.dart'; // For resetting to initial state

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _preferencesService = PreferencesService();
  final _deviceIdService = DeviceIdService(); // Now handles participant ID hash
  final _routingService = RoutingService();

  // Controllers for form fields
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

  // Route specific controllers
  final _homeLatController = TextEditingController();
  final _homeLonController = TextEditingController();
  final _officeLatController = TextEditingController();
  final _officeLonController = TextEditingController();

  // Route time variables (displayed in local time, stored as UTC)
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
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load existing preferences');
    }
  }

  void _populateControllers(UserPreferences preferences) {
    _windSpeedController.text = preferences.weatherLimits.maxWindSpeed
        .toString();
    _rainIntensityController.text = preferences.weatherLimits.maxRainIntensity
        .toString();
    _humidityController.text = preferences.weatherLimits.maxHumidity.toString();
    _minTemperatureController.text = preferences.weatherLimits.minTemperature
        .toString();
    _maxTemperatureController.text = preferences.weatherLimits.maxTemperature
        .toString();
    _headwindSensitivity =
        preferences.weatherLimits.headwindSensitivity;
    _crosswindSensitivity =
        preferences.weatherLimits.crosswindSensitivity;
    _visibilityController.text = preferences.environmentalRisk.minVisibility
        .toString();
    _pollutionController.text = preferences.environmentalRisk.maxPollution
        .toString();
    _uvIndexController.text = preferences.environmentalRisk.maxUvIndex
        .toString();

    // Populate office location if available
    if (!preferences.officeLocation.isEmpty) {
      _officeLatController.text = preferences.officeLocation.latitude
          .toStringAsFixed(6);
      _officeLonController.text = preferences.officeLocation.longitude
          .toStringAsFixed(6);
    }

    // Populate route times - convert from UTC to local time for display
    _routeStartTime = preferences.commuteWindows.startLocal;
    _routeEndTime = preferences.commuteWindows.endLocal;

    if (kDebugMode) {
      print('🕐 Time Conversion Debug:');
      print('   Stored Route Start UTC: ${preferences.commuteWindows.start}');
      print(
        '   Displayed Start Local: ${_formatTimeOfDay(_routeStartTime)}',
      );
      print('   Stored Route End UTC: ${preferences.commuteWindows.end}');
      print(
        '   Displayed End Local: ${_formatTimeOfDay(_routeEndTime)}',
      );
      print('   Current Timezone Offset: ${DateTime.now().timeZoneOffset}');
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  UserPreferences _createPreferencesFromForm() {
    // Convert local times to UTC for storage
    final startUtc = CommuteWindows.localTimeOfDayToUtc(_routeStartTime);
    final endUtc = CommuteWindows.localTimeOfDayToUtc(_routeEndTime);

    if (kDebugMode) {
      print('🕐 Time Conversion for Storage:');
      print('   Local Start: ${_formatTimeOfDay(_routeStartTime)}');
      print('   UTC Start: $startUtc');
      print('   Local End: ${_formatTimeOfDay(_routeEndTime)}');
      print('   UTC End: $endUtc');
      print('   Current Timezone Offset: ${DateTime.now().timeZoneOffset}');
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
      commuteWindows: CommuteWindows(start: startUtc, end: endUtc),
    );
  }

  Future<void> _selectRouteStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _routeStartTime,
      helpText: 'Select Route Start Time (Local)',
    );
    if (picked != null && picked != _routeStartTime) {
      setState(() {
        _routeStartTime = picked;
      });

      if (kDebugMode) {
        final utcTime = CommuteWindows.localTimeOfDayToUtc(picked);
        print('🕐 Route Start Time Selected:');
        print('   Local Time: ${_formatTimeOfDay(picked)}');
        print('   Will be stored as UTC: $utcTime');
      }
    }
  }

  Future<void> _selectRouteEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _routeEndTime,
      helpText: 'Select Route End Time (Local)',
    );
    if (picked != null && picked != _routeEndTime) {
      setState(() {
        _routeEndTime = picked;
      });

      if (kDebugMode) {
        final utcTime = CommuteWindows.localTimeOfDayToUtc(picked);
        print('🕐 Route End Time Selected:');
        print('   Local Time: ${_formatTimeOfDay(picked)}');
        print('   Will be stored as UTC: $utcTime');
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
        _homeLatController.text =
            locationData.latitude?.toStringAsFixed(6) ?? '';
        _homeLonController.text =
            locationData.longitude?.toStringAsFixed(6) ?? '';
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

    final LatLng? pickedLocation = await Navigator.push(
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
      _showErrorSnackBar(
        'Please fill all required fields for route generation.',
      );
      return;
    }

    final homeLat = double.tryParse(_homeLatController.text);
    final homeLon = double.tryParse(_homeLonController.text);
    final officeLat = double.tryParse(_officeLatController.text);
    final officeLon = double.tryParse(_officeLonController.text);

    if (homeLat == null ||
        homeLon == null ||
        officeLat == null ||
        officeLon == null) {
      _showErrorSnackBar(
        'Please enter valid numbers for all route coordinates.',
      );
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

      final routeGeoPoints = await _routingService.fetchRoutePoints(
        startPoint,
        endPoint,
      );

      if (kDebugMode) {
        print('🗺️ Route Points Debug:');
        print('   Total points: ${routeGeoPoints.length}');
        print(
          '   Start point: ${startPoint.latitude}, ${startPoint.longitude}',
        );
        print('   End point: ${endPoint.latitude}, ${endPoint.longitude}');
        if (routeGeoPoints.isNotEmpty) {
          print(
            '   First route point: ${routeGeoPoints.first.latitude}, ${routeGeoPoints.first.longitude}',
          );
          print(
            '   Last route point: ${routeGeoPoints.last.latitude}, ${routeGeoPoints.last.longitude}',
          );
        }
      }

      setState(() {
        _routePolylinePoints = routeGeoPoints
            .map((gp) => LatLng(gp.latitude, gp.longitude))
            .toList();
        _startMarkerPoint = LatLng(startPoint.latitude, startPoint.longitude);
        _endMarkerPoint = LatLng(endPoint.latitude, endPoint.longitude);
      });

      if (mounted) {
        double avgLat = (startPoint.latitude + endPoint.latitude) / 2;
        double avgLon = (startPoint.longitude + endPoint.longitude) / 2;
        LatLng mapCenter = LatLng(avgLat, avgLon);

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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _submitPreferencesAndRoute() async {
    if (!_formKey.currentState!.validate()) return;

    if (_routePolylinePoints.isEmpty ||
        _startMarkerPoint == null ||
        _endMarkerPoint == null) {
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

      // Get the participant ID hash, which is now the 'device_id' for the backend
      final participantIdHash = await _deviceIdService.getParticipantIdHash();
      if (participantIdHash == null) {
        _showErrorSnackBar(
          'Participant ID not set. Please restart the app and enter your code.',
        );
        return;
      }

      final feedbackGiven =
          await _preferencesService.isEndFeedbackGivenToday();
      final String? oldThresholdId =
          await _preferencesService.getCurrentThresholdId();
      final String? newThresholdId =
          await _apiService.submitThresholds(preferences);
      await _preferencesService.savePreferencesWithDeviceId(
        preferences,
      ); // This still uses the deviceIdService internally
      if (newThresholdId != null && !feedbackGiven && oldThresholdId != null) {
        await _preferencesService.setPendingFeedback(DateTime.now());
        await _preferencesService
            .setPendingFeedbackThresholdId(oldThresholdId);
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
        deviceId: participantIdHash, // Use the participant ID hash as deviceId
        routeName: 'Home to Office',
        startLocation: startLocation,
        endLocation: endLocation,
        routePoints: _routePolylinePoints
            .map(
              (ll) => GeoPoint(latitude: ll.latitude, longitude: ll.longitude),
            )
            .toList(),
      );

      if (kDebugMode) {
        print('📤 Route Submission Debug:');
        print('   Participant ID Hash (as Device ID): $participantIdHash');
        print('   Route Name: ${routeModel.routeName}');
        print(
          '   Start: ${routeModel.startLocation.latitude}, ${routeModel.startLocation.longitude}',
        );
        print(
          '   End: ${routeModel.endLocation.latitude}, ${routeModel.endLocation.longitude}',
        );
        print('   Total route points: ${routeModel.routePoints.length}');
        print(
          '   Commute Windows (UTC): Start ${preferences.commuteWindows.start}, End ${preferences.commuteWindows.end}',
        );
        print(
          '   Commute Windows (Local): Start ${_formatTimeOfDay(_routeStartTime)}, End ${_formatTimeOfDay(_routeEndTime)}',
        );
        print(
          '   Temperature Range: ${preferences.weatherLimits.minTemperature}°C to ${preferences.weatherLimits.maxTemperature}°C',
        );
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
      _showErrorSnackBar(
        'Failed to save preferences or route: ${e.toString()}',
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetAppId() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset App ID?'),
          content: const Text(
            'Are you sure you want to reset your app ID? This will remove your saved preferences and require re-entry of your participant code.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _deviceIdService.clearParticipantIdHash();
        await _preferencesService.clearPreferences(); // Also clear preferences
        if (mounted) {
          _showErrorSnackBar(
            'App ID and preferences reset. Please re-enter your participant code.',
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AppInitializer()),
            (Route<dynamic> route) => false, // Clear all routes
          );
        }
      } catch (e) {
        _showErrorSnackBar('Failed to reset app ID: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set preferences'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset App ID',
            onPressed: _resetAppId,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildWeatherLimitsSection(),
            const SizedBox(height: 24),
            _buildEnvironmentalRiskSection(),
            const SizedBox(height: 24),
            _buildCommuteWindowsSection(),
            const SizedBox(height: 24),
            _buildCommuteRouteSection(),
            const SizedBox(height: 32),
            _buildSubmitButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherLimitsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weather limits',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildNumberField(
              controller: _windSpeedController,
              label: 'Max wind speed (km/h)',
              helperText: '0 – 200 km/h',
              min: 0,
              max: 200,
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Headwind Sensitivity (${_headwindSensitivity.round()} km/h)',
                ),
                Slider(
                  value: _headwindSensitivity,
                  min: 0,
                  max: 50,
                  divisions: 50,
                  label: '${_headwindSensitivity.round()} km/h',
                  onChanged: (value) {
                    setState(() => _headwindSensitivity = value);
                  },
                ),
                Text(
                  'Receive an alert when headwind exceeds this speed during your commute.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crosswind Sensitivity (${_crosswindSensitivity.round()} km/h)',
                ),
                Slider(
                  value: _crosswindSensitivity,
                  min: 0,
                  max: 50,
                  divisions: 50,
                  label: '${_crosswindSensitivity.round()} km/h',
                  onChanged: (value) {
                    setState(() => _crosswindSensitivity = value);
                  },
                ),
                Text(
                  'Receive an alert when crosswind exceeds this speed during your commute.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildNumberField(
              controller: _rainIntensityController,
              label: 'Max rain intensity (mm/h)',
              helperText: '0 – 50 mm/h',
              min: 0,
              max: 50,
              allowDecimals: true,
            ),
            const SizedBox(height: 16),
            _buildNumberField(
              controller: _humidityController,
              label: 'Max humidity (%)',
              helperText: '0 – 100%',
              min: 0,
              max: 100,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    controller: _minTemperatureController,
                    label: 'Min temperature (°C)',
                    helperText: '-50 – 60°C',
                    min: -50,
                    max: 60,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberField(
                    controller: _maxTemperatureController,
                    label: 'Max temperature (°C)',
                    helperText: '-50 – 60°C',
                    min: -50,
                    max: 60,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentalRiskSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Environmental risk',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildNumberField(
              controller: _visibilityController,
              label: 'Min visibility (m)',
              helperText: '0 – 10000 m',
              min: 0,
              max: 10000,
            ),
            const SizedBox(height: 16),
            _buildNumberField(
              controller: _pollutionController,
              label: 'Max pollution (AQI)',
              helperText: '0 – 500 AQI',
              min: 0,
              max: 500,
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
      ),
    );
  }

  Widget _buildCommuteWindowsSection() {
    // Get current timezone name for display
    final now = DateTime.now();
    final timeZoneName = now.timeZoneName;
    final offsetHours = now.timeZoneOffset.inHours;
    final offsetMinutes = now.timeZoneOffset.inMinutes.remainder(60);
    final offsetString =
        '${offsetHours >= 0 ? '+' : ''}$offsetHours:${offsetMinutes.abs().toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Commute Schedule',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Set your route start and end times for personalized weather alerts',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Times shown in your local timezone ($timeZoneName, UTC$offsetString)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Route Start Time',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selectRouteStartTime,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _formatTimeOfDay(_routeStartTime),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Route End Time',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selectRouteEndTime,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _formatTimeOfDay(_routeEndTime),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommuteRouteSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Commute Route (Home to Office)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Home Location',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _homeLatController.text.isNotEmpty &&
                      _homeLonController.text.isNotEmpty
                  ? 'Lat: ${_homeLatController.text}, Lon: ${_homeLonController.text}'
                  : 'No home location selected',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickLocation(
                  latController: _homeLatController,
                  lonController: _homeLonController,
                  title: 'Select Home Location',
                ),
                icon: const Icon(Icons.map),
                label: const Text('Pick Home Location on Map'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isGettingLocation
                    ? null
                    : _useDeviceLocationForHome,
                icon: _isGettingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _isGettingLocation
                      ? 'Getting home location...'
                      : 'Use current location (Home)',
                ),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Office Location',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _officeLatController.text.isNotEmpty &&
                      _officeLonController.text.isNotEmpty
                  ? 'Lat: ${_officeLatController.text}, Lon: ${_officeLonController.text}'
                  : 'No office location selected',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickLocation(
                  latController: _officeLatController,
                  lonController: _officeLonController,
                  title: 'Select Office Location',
                ),
                icon: const Icon(Icons.map),
                label: const Text('Pick Office Location on Map'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isFetchingRoute ? null : _previewRoute,
                icon: _isFetchingRoute
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.map),
                label: Text(
                  _isFetchingRoute ? 'Fetching route...' : 'Preview Route',
                ),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
            const SizedBox(height: 16),
            if (_routePolylinePoints.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Route previewed. Ready to save.'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String helperText,
    required double min,
    required double max,
    bool allowDecimals = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        if (allowDecimals)
          FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
        else
          FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
      ],
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
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

        // Additional validation for temperature range
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

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed:
            (_isSubmitting ||
                _isGettingLocation ||
                _isFetchingRoute ||
                _routePolylinePoints.isEmpty)
            ? null
            : _submitPreferencesAndRoute,
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Save preferences and Route'),
      ),
    );
  }
}
