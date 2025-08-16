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
      final hasParticipantId = await _deviceIdService.hasParticipantIdHash();

      if (hasParticipantId) {
        final thresholdsSet = await _preferencesService.arePreferencesSet();
        setState(() {
          _hasParticipantId = true;
          _thresholdsSet = thresholdsSet;
          _isLoading = false;
        });
      } else {

        setState(() {
          _hasParticipantId = false;
          _isLoading = false;
        });
      }
    } catch (e) {

      setState(() {
        _isLoading = false;
        _hasParticipantId = false;
        _thresholdsSet = false;
      });
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
