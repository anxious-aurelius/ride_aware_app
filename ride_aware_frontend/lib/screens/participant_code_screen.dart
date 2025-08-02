import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For FilteringTextInputFormatter
import '../services/device_id_service.dart';
import '../app_initializer.dart'; // To navigate back to initializer

class ParticipantCodeScreen extends StatefulWidget {
  const ParticipantCodeScreen({super.key});

  @override
  State<ParticipantCodeScreen> createState() => _ParticipantCodeScreenState();
}

class _ParticipantCodeScreenState extends State<ParticipantCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final DeviceIdService _deviceIdService = DeviceIdService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitParticipantCode() async {
    if (_codeController.text.isEmpty) {
      _showSnackBar('Please enter your participant code.', Colors.red);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _deviceIdService.setParticipantCode(_codeController.text);
      _showSnackBar('Participant code saved!', Colors.green);

      if (mounted) {
        // Navigate back to AppInitializer to re-evaluate the state
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AppInitializer()),
        );
      }
    } catch (e) {
      _showSnackBar('Failed to save code: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
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
              Text(
                'Welcome to Active Commuter!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Please enter your unique participant code to begin.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Participant Code',
                  hintText: 'e.g., your-unique-id-123',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(
                    RegExp(r'\s'),
                  ), // Prevent spaces
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submitParticipantCode,
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
                      : const Text('Submit Code'),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
