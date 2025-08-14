import 'package:flutter/material.dart';

class RideDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> ride; // raw ride map from API

  const RideDetailsScreen({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dateStr = (ride['date'] ?? '').toString();
    final start = (ride['start_time'] ?? '').toString();
    final end = (ride['end_time'] ?? '').toString();
    final status = (ride['status'] ?? 'ok').toString();
    final feedback = (ride['feedback'] ?? '').toString();
    final summary = (ride['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
    final threshold = (ride['threshold'] as Map?)?.cast<String, dynamic>() ?? const {};
    final weatherHistory = (ride['weather_history'] as List?)?.cast<Map>() ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            context,
            title: 'Overview',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Date', dateStr),
                _kv('Start – End', '$start – $end'),
                _kv('Status', status.toUpperCase()),
              ],
            ),
          ),
          if (feedback.isNotEmpty)
            _sectionCard(
              context,
              title: 'Feedback',
              child: Text(feedback, style: theme.textTheme.bodyLarge),
            )
          else
            _sectionCard(
              context,
              title: 'Feedback',
              child: Text(
                'No feedback provided.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          _sectionCard(
            context,
            title: 'Summary',
            child: summary.isEmpty
                ? Text('No summary recorded.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                : Column(
              children: summary.entries
                  .map((e) => _kv(e.key.replaceAll('_', ' '), '${e.value}'))
                  .toList(),
            ),
          ),
          _sectionCard(
            context,
            title: 'Threshold Snapshot',
            child: _thresholdView(context, threshold),
          ),
          _sectionCard(
            context,
            title: 'Weather History',
            child: weatherHistory.isEmpty
                ? Text('No weather snapshots found for this ride.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                : Column(
              children: weatherHistory.map((snap) {
                final m = snap.cast<String, dynamic>();
                final ts = (m['timestamp'] ?? '').toString();
                final w = (m['weather'] as Map?)?.cast<String, dynamic>() ?? const {};
                // Defensive extraction — adapt to your real payload
                final temp = w['temp'] ?? w['temperature'] ?? w['temp_c'] ?? '—';
                final windSpeed = w['wind_speed'] ?? w['wind_ms'] ?? '—';
                final windDir = w['wind_deg'] ?? w['wind_dir'] ?? '—';
                final humidity = w['humidity'] ?? '—';
                final rain = w['rain'] ?? w['rain_mm'] ?? '—';
                final cond = w['description'] ?? w['cond'] ?? '';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text(ts),
                  subtitle: Text(
                    'Temp: $temp  •  Wind: $windSpeed ${windDir != '—' ? '($windDir°)' : ''}  •  Humidity: $humidity  •  Rain: $rain${cond != '' ? '  •  $cond' : ''}',
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          child,
        ]),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _thresholdView(BuildContext context, Map<String, dynamic> t) {
    final wl = (t['weather_limits'] as Map?)?.cast<String, dynamic>() ?? const {};
    final office = (t['office_location'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rows = <Widget>[
      _kv('Date', (t['date'] ?? '').toString()),
      _kv('Start – End', '${t['start_time'] ?? ''} – ${t['end_time'] ?? ''}'),
      _kv('Timezone', (t['timezone'] ?? '').toString()),
      _kv('Presence Radius (m)', '${t['presence_radius_m'] ?? '—'}'),
      _kv('Speed Cutoff (km/h)', '${t['speed_cutoff_kmh'] ?? '—'}'),
      const Divider(height: 20),
      const Text('Weather Limits', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      ...wl.entries.map((e) => _kv(e.key.replaceAll('_', ' '), '${e.value}')),
      if (office.isNotEmpty) ...[
        const Divider(height: 20),
        const Text('Office Location', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _kv('Latitude', '${office['latitude'] ?? '—'}'),
        _kv('Longitude', '${office['longitude'] ?? '—'}'),
      ],
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}
