import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();

  /// Raw history grouped by calendar day (local) for TableCalendar.
  Map<DateTime, List<Map<String, dynamic>>> _history = {};
  bool _loading = true;
  String? _error;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _apiService.fetchRideHistoryRaw(lastDays: 60);

      final map = <DateTime, List<Map<String, dynamic>>>{};
      for (final ride in raw) {
        final start = _composeLocalDateTime(ride['date'], ride['start_time']);
        final key = DateTime(start.year, start.month, start.day);
        map.putIfAbsent(key, () => []).add(ride);
      }
      // sort per-day by start time
      for (final k in map.keys) {
        map[k]!.sort((a, b) {
          final sa = _composeLocalDateTime(a['date'], a['start_time']);
          final sb = _composeLocalDateTime(b['date'], b['start_time']);
          return sa.compareTo(sb);
        });
      }

      setState(() {
        _history = map;
        _selectedDay ??=
            DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load ride history';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ride history fetch error: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _entriesFor(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _history[key] ?? const [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _selectedDay != null
        ? _entriesFor(_selectedDay!)
        : const <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride History'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 8),
            Text(_error!, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Calendar
          TableCalendar<Map<String, dynamic>>(
            firstDay:
            DateTime.now().subtract(const Duration(days: 365)),
            lastDay:
            DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) =>
                isSameDay(_selectedDay, day),
            eventLoader: _entriesFor,
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color:
                theme.colorScheme.primary.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: theme.colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // List of rides for selected day
          Expanded(
            child: entries.isEmpty
                ? const Center(
              child: Text('No rides on this day'),
            )
                : ListView.separated(
              padding:
              const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: entries.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final ride = entries[i];
                return _RideCard(
                  ride: ride,
                  onTap: () => _showRideDetails(ride),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- detail sheet --------------------

  void _showRideDetails(Map<String, dynamic> ride) {
    final start = _composeLocalDateTime(ride['date'], ride['start_time']);
    final end = _composeLocalDateTime(ride['date'], ride['end_time']);
    final status = (ride['status'] ?? '').toString();
    final feedback = (ride['feedback'] ?? '').toString();
    final summary = (ride['summary'] ?? {}) as Map<String, dynamic>;
    final threshold = (ride['threshold'] ?? {}) as Map<String, dynamic>;
    final weatherHistory =
    (ride['weather_history'] ?? []) as List<dynamic>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) {
        return DefaultTabController(
          length: 3,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Text(
                        '${_hm(start)}–${_hm(end)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(status: status),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (feedback.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        feedback,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),

                  const TabBar(
                    tabs: [
                      Tab(text: 'Overview', icon: Icon(Icons.list_alt)),
                      Tab(text: 'Threshold', icon: Icon(Icons.tune)),
                      Tab(text: 'Weather', icon: Icon(Icons.wb_cloudy)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: TabBarView(
                      children: [
                        // Overview
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _kv('Status', status.isEmpty ? '—' : status),
                              _kv('Date', (ride['date'] ?? '—').toString()),
                              _kv('Start', _hm(start)),
                              _kv('End', _hm(end)),
                              const SizedBox(height: 12),
                              if (summary.isNotEmpty) ...[
                                Text('Summary',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 6),
                                _PrettyMap(summary),
                              ] else
                                Text('No summary.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium),
                            ],
                          ),
                        ),

                        // Threshold
                        SingleChildScrollView(
                          child: threshold.isEmpty
                              ? Text('No threshold snapshot.',
                              style:
                              Theme.of(context).textTheme.bodyMedium)
                              : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionCard(
                                title: 'Snapshot',
                                children: [
                                  _kv('Device ID',
                                      (threshold['device_id'] ?? '—')
                                          .toString()),
                                  _kv('Date',
                                      (threshold['date'] ?? '—')
                                          .toString()),
                                  _kv('Start',
                                      (threshold['start_time'] ?? '—')
                                          .toString()),
                                  _kv('End',
                                      (threshold['end_time'] ?? '—')
                                          .toString()),
                                  _kv('Timezone',
                                      (threshold['timezone'] ?? '—')
                                          .toString()),
                                  _kv('Presence radius (m)',
                                      (threshold['presence_radius_m'] ??
                                          '—')
                                          .toString()),
                                  _kv('Speed cutoff (km/h)',
                                      (threshold['speed_cutoff_kmh'] ??
                                          '—')
                                          .toString()),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (threshold['weather_limits']
                              is Map<String, dynamic>)
                                _sectionCard(
                                  title: 'Weather Limits',
                                  children: _kvList(
                                      Map<String, dynamic>.from(
                                          threshold['weather_limits'])),
                                ),
                              const SizedBox(height: 10),
                              if (threshold['office_location']
                              is Map<String, dynamic>)
                                _sectionCard(
                                  title: 'Office Location',
                                  children: _kvList(
                                      Map<String, dynamic>.from(
                                          threshold['office_location'])),
                                ),
                            ],
                          ),
                        ),

                        // Weather
                        weatherHistory.isEmpty
                            ? Center(
                          child: Text(
                            'No weather snapshots collected.',
                            style:
                            Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                            : ListView.separated(
                          itemCount: weatherHistory.length,
                          separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final snap = Map<String, dynamic>.from(
                                weatherHistory[i] as Map);
                            final tsStr =
                            (snap['timestamp'] ?? '').toString();
                            DateTime? ts;
                            try {
                              ts = DateTime.parse(tsStr).toLocal();
                            } catch (_) {}
                            final w = (snap['weather'] ??
                                {}) as Map<String, dynamic>;

                            final temp = w['temp_c'] ??
                                w['temp'] ??
                                w['temperature'];
                            final wind = w['wind_ms'] ??
                                w['wind_speed'] ??
                                w['wind'];
                            final cond = w['cond'] ??
                                w['condition'] ??
                                w['summary'];

                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                child: Text(
                                  ts != null
                                      ? '${ts.hour.toString().padLeft(2, '0')}\n${ts.minute.toString().padLeft(2, '0')}'
                                      : '--\n--',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              title: Text(
                                'Temp: ${temp ?? '—'}   Wind: ${wind ?? '—'}',
                              ),
                              subtitle: cond != null
                                  ? Text(cond.toString())
                                  : null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------- small UI helpers --------------------

  static DateTime _composeLocalDateTime(dynamic dateIso, dynamic hhmm) {
    final d = (dateIso ?? '').toString();
    final t = (hhmm ?? '00:00').toString();
    final dd = d.split('-');
    final tt = t.split(':');
    if (dd.length == 3 && tt.length >= 2) {
      final y = int.tryParse(dd[0]) ?? DateTime.now().year;
      final m = int.tryParse(dd[1]) ?? DateTime.now().month;
      final day = int.tryParse(dd[2]) ?? DateTime.now().day;
      final h = int.tryParse(tt[0]) ?? 0;
      final min = int.tryParse(tt[1]) ?? 0;
      return DateTime(y, m, day, h, min);
    }
    return DateTime.now();
  }

  String _hm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            k,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(flex: 3, child: Text(v)),
      ],
    ),
  );

  List<Widget> _kvList(Map<String, dynamic> m) {
    final entries = m.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map((e) => _kv(e.key, (e.value ?? '—').toString()))
        .toList();
  }

  Widget _sectionCard(
      {required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Pretty key–value listing for a flat map.
class _PrettyMap extends StatelessWidget {
  final Map<String, dynamic> map;
  const _PrettyMap(this.map);

  @override
  Widget build(BuildContext context) {
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: entries
              .map((e) => Row(
            children: [
              Expanded(
                  flex: 2,
                  child: Text(e.key,
                      style:
                      const TextStyle(fontWeight: FontWeight.w600))),
              Expanded(
                  flex: 3,
                  child: Text((e.value ?? '—').toString())),
            ],
          ))
              .toList(),
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final VoidCallback onTap;

  const _RideCard({required this.ride, required this.onTap});

  // local time formatter for this widget
  String _hmLocal(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final start = _HistoryScreenState._composeLocalDateTime(ride['date'], ride['start_time']);
    final end   = _HistoryScreenState._composeLocalDateTime(ride['date'], ride['end_time']);
    final status = (ride['status'] ?? '').toString();
    final feedback = (ride['feedback'] ?? '').toString();
    final threshold = (ride['threshold'] ?? {}) as Map<String, dynamic>;
    final weatherHistory = (ride['weather_history'] ?? []) as List<dynamic>;

    final color = _statusColor(status);
    final borderColor = color.withOpacity(0.35);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.15), Theme.of(context).colorScheme.surface],
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bike, color: color),
                const SizedBox(width: 8),
                Text(
                  '${_hmLocal(start)}–${_hmLocal(end)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: status),
                const Spacer(),
                Icon(
                  feedback.isNotEmpty ? Icons.check_circle : Icons.feedback,
                  color: feedback.isNotEmpty
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              feedback.isNotEmpty
                  ? feedback
                  : 'No feedback provided. Tap to see details.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (threshold.isNotEmpty)
                  _metaChip('Radius ${threshold['presence_radius_m'] ?? '—'} m'),
                if (threshold.isNotEmpty)
                  _metaChip('Speed ${threshold['speed_cutoff_kmh'] ?? '—'} km/h'),
                _metaChip(
                  weatherHistory.isEmpty
                      ? '0 weather snapshots'
                      : '${weatherHistory.length} weather snapshots',
                  icon: Icons.wb_cloudy,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'alert': return Colors.red;
      case 'warning': return Colors.orange;
      case 'ok': return Colors.green;
      case 'pending': return Colors.grey;
      default: return Colors.blueGrey;
    }
  }

  Widget _metaChip(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: 6),
          ],
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}


class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = () {
      switch (status) {
        case 'alert':
          return Colors.red;
        case 'warning':
          return Colors.orange;
        case 'ok':
          return Colors.green;
        case 'pending':
          return Colors.grey;
        default:
          return Theme.of(context).colorScheme.primary;
      }
    }();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.isNotEmpty ? status : '—',
        style:
        TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
