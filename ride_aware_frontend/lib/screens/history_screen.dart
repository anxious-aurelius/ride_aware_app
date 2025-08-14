import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';
import '../models/ride_history_entry.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  Map<DateTime, List<RideHistoryEntry>> _history = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final entries = await _apiService.fetchRideHistory();
    final map = <DateTime, List<RideHistoryEntry>>{};
    for (final e in entries) {
      final local = e.localDate;
      final day = DateTime(local.year, local.month, local.day);
      map.putIfAbsent(day, () => []).add(e);
    }
    setState(() {
      _history = map;
    });
  }

  List<RideHistoryEntry> _getEntriesForDay(DateTime day) {
    return _history[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _selectedDay != null ? _getEntriesForDay(_selectedDay!) : [];
    return Scaffold(
      appBar: AppBar(title: const Text('Ride History')),
      body: Column(
        children: [
          TableCalendar<RideHistoryEntry>(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEntriesForDay,
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              _loadHistory();
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.primary.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No rides on this day'))
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final e = entries[index];
                      final start = e.start;
                      final end = e.end;
                      return Card(
                        color: _statusColor(e.status),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          leading: _feedbackIcon(e),
                          title: Text(
                            '${_formatTime(start)}–${_formatTime(end)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.feedback ??
                                    'No feedback provided. Add your feedback next time!',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              _thresholdRow(e),
                              const SizedBox(height: 4),
                              _weatherChips(e),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _feedbackIcon(RideHistoryEntry entry) {
    if (entry.feedback != null && entry.feedback!.isNotEmpty) {
      return Icon(Icons.check_circle,
          color: Theme.of(context).colorScheme.secondary);
    }
    return Icon(Icons.info,
        color: Theme.of(context).colorScheme.onSurfaceVariant);
  }

  Widget _weatherChips(RideHistoryEntry e) {
    if (e.weather.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: e.weather.map((w) {
        final t = w.tempC != null ? '${w.tempC}°C' : '?°C';
        final wind = w.windMs != null ? '${w.windMs} m/s' : '? m/s';
        final hhmm = TimeOfDay.fromDateTime(w.timestamp.toLocal());
        final stamp =
            '${hhmm.hour.toString().padLeft(2, "0")}:${hhmm.minute.toString().padLeft(2, "0")}';
        final cond = w.cond != null ? ' • ${w.cond}' : '';
        return Chip(label: Text('$stamp • $t • $wind$cond'));
      }).toList(),
    );
  }

  Widget _thresholdRow(RideHistoryEntry e) {
    if (e.threshold == null || e.threshold!.isEmpty) {
      return const SizedBox.shrink();
    }
    final r = e.threshold!['presence_radius_m'];
    final sp = e.threshold!['speed_cutoff_kmh'];
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        'Thresholds: radius ${r ?? '?'} m, speed ${sp ?? '?'} km/h',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'alert':
        return Colors.red.shade300;
      case 'warning':
        return Colors.orange.shade300;
      default:
        return Colors.green.shade300;
    }
  }
}
