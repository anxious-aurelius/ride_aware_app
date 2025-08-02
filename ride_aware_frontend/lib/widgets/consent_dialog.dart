import 'dart:io';
import 'package:flutter/material.dart';
import 'package:active_commuter_support/services/consent_service.dart';

class ConsentDialog extends StatelessWidget {
  final ConsentService consentService;

  const ConsentDialog({super.key, required this.consentService});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Before You Begin'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                  'This mobile app is part of a research study approved by the University of Strathclyde.'),
              SizedBox(height: 8),
              Text(
                  'It explores how personalised weather alerts can support cyclists in making more confident commuting decisions.'),
              SizedBox(height: 8),
              Text('Participation is voluntary, and users may stop at any time.'),
              SizedBox(height: 8),
              Text('No live GPS or background tracking is used.'),
              SizedBox(height: 8),
              Text('Users may manually set a location or enable location services (optional).'),
              SizedBox(height: 8),
              Text('The app does not collect names, emails, or any identifiable data.'),
              SizedBox(height: 8),
              Text('Survey data is collected anonymously and cannot be linked to the user.'),
              SizedBox(height: 8),
              Text('All data handling complies with UK GDPR and the University of Strathclyde’s ethics policies.'),
              SizedBox(height: 8),
              Text(
                  'For questions, users may contact Kripal Parsekar (kripal.parsekar.2024@uni.strath.ac.uk, +44 7823704105).'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => exit(0),
          child: const Text('I Do Not Consent'),
        ),
        ElevatedButton(
          onPressed: () async {
            await consentService.setConsented(true);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('I Consent and Wish to Continue'),
        ),
      ],
    );
  }
}
