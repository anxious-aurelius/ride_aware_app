import 'package:active_commuter_support/screens/dashboard_screen.dart';
import 'package:active_commuter_support/screens/participant_code_screen.dart';
import 'package:active_commuter_support/screens/preferences_screen.dart';
import 'package:active_commuter_support/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:active_commuter_support/services/device_id_service.dart';
import 'package:active_commuter_support/services/consent_service.dart';
import 'package:active_commuter_support/widgets/consent_dialog.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() {
    return _AppInitializerState();
  }
}

class _AppInitializerState extends State<AppInitializer> {
  final _preferencesService = PreferencesService();
  final _deviceIdService = DeviceIdService();
  final _consentService = ConsentService();
  bool _isLoading = true;
  bool _hasParticipantId = false;
  bool _thresholdsSet = false;

  @override
  void initState() {
    super.initState();
    _checkAppState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _showConsentDialogIfNeeded());
  }

  Future<void> _checkAppState() async {
    try {
      // 1. Check if participant ID hash exists
      final hasParticipantId = await _deviceIdService.hasParticipantIdHash();

      if (hasParticipantId) {
        // 2. If participant ID exists, check if preferences are set
        final thresholdsSet = await _preferencesService.arePreferencesSet();
        setState(() {
          _hasParticipantId = true;
          _thresholdsSet = thresholdsSet;
          _isLoading = false;
        });
      } else {
        // 3. If no participant ID, go to participant code entry
        setState(() {
          _hasParticipantId = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle any errors during initialization
      setState(() {
        _isLoading = false;
        _hasParticipantId = false; // Assume no ID if error
        _thresholdsSet = false;
      });
      // Optionally show an error message
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('App initialization failed: $e')),
      // );
    }
  }

  Future<void> _showConsentDialogIfNeeded() async {
    final hasConsented = await _consentService.hasConsented();
    if (!hasConsented && mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ConsentDialog(consentService: _consentService),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasParticipantId) {
      return const ParticipantCodeScreen();
    } else {
      return _thresholdsSet
          ? const DashboardScreen()
          : const PreferencesScreen();
    }
  }
}
