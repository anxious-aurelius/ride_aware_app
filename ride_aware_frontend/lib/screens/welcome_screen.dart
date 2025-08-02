import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import 'dashboard_screen.dart';
import 'preferences_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _handleContinue(BuildContext context) async {
    final preferencesService = PreferencesService();
    final thresholdsSet = await preferencesService.arePreferencesSet();

    if (!context.mounted) return;

    if (thresholdsSet) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PreferencesScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // App Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(
                  Icons.directions_bike,
                  size: 60,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(height: 32),

              // App Title
              Text(
                'Active Commuter',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Value Proposition
              Text(
                'Personalised commute weather alerts',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              // Continue Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _handleContinue(context),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: const Text('Continue'),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
