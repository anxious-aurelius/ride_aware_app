import 'dart:io';
import 'package:flutter/material.dart';
import 'package:active_commuter_support/services/consent_service.dart';

class ConsentDialog extends StatelessWidget {
  final ConsentService consentService;

  static const List<String> _points = [
    'This mobile app is part of a research study approved by the University of Strathclyde.',
    'It explores how personalised weather alerts can support cyclists in making more confident commuting decisions.',
    'Participation is voluntary, and users may stop at any time.',
    'No live GPS or background tracking is used.',
    'Users may manually set a location or enable location services (optional).',
    'The app does not collect names, emails, or any identifiable data.',
    'Survey data is collected anonymously and cannot be linked to the user.',
    'All data handling complies with UK GDPR and the University of Strathclyde’s ethics policies.',
    'For questions, users may contact Kripal Parsekar (kripal.parsekar.2024@uni.strath.ac.uk, +44 7823704105).',
  ];


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
            children: [
              for (final point in _points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•'),
                      const SizedBox(width: 6),
                      Expanded(child: Text(point)),
                    ],
                  ),
                ),
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
