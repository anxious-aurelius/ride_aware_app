import 'package:flutter/material.dart';
import '../utils/i18n.dart';

class CommuteSummary extends StatelessWidget {
  final String dateLabel;
  final String routeName;

  const CommuteSummary({
    super.key,
    required this.dateLabel,
    required this.routeName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.calendar_today, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            t('Next Commute: $dateLabel – Route: "$routeName"'),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
