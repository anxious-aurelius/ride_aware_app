import 'package:flutter/material.dart';
import 'standard_card.dart';

class RideFeedbackCard extends StatelessWidget {
  final bool feedbackGiven;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  const RideFeedbackCard({
    super.key,
    required this.feedbackGiven,
    this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StandardCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.feedback,
              color: feedbackGiven
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.error,
            ),
            title: Text(
              feedbackGiven
                  ? 'Feedback submitted for your last ride'
                  : 'Feedback available for your last ride',
            ),
            subtitle: feedbackGiven
                ? null
                : const Text(
                    'Tap to give feedback or close if your ride was fine.',
                  ),
            onTap: feedbackGiven ? null : onTap,
          ),
        ),
        if (!feedbackGiven)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Close'),
                onPressed: onClose,
              ),
            ),
          ),
      ],
    );
  }
}

