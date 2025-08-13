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
      final day = DateTime(e.date.year, e.date.month, e.date.day);
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
            firstDay: DateTime.now().subtract(const Duration(days: 30)),
            lastDay: DateTime.now(),
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
                color: Theme.of(context).colorScheme.secondary,
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
                      return Card(
                        color: _statusColor(e.status),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          leading: _feedbackIcon(e),
                          title: Text(
                            '${_formatTime(e.startTime)}–${_formatTime(e.endTime)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.feedback ??
                                    'Next time you should give feedback to improve your experience.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (e.weatherHistory.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  children: e.weatherHistory.map((w) {
                                    final temp = w['weather']['temp'];
                                    final wind = w['weather']['wind_speed'];
                                    return Chip(
                                        label: Text('${temp ?? '?'}°C / ${wind ?? '?'}m/s'));
                                  }).toList(),
                                ),
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

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _feedbackIcon(RideHistoryEntry entry) {
    if (entry.feedback != null && entry.feedback!.isNotEmpty) {
      return Icon(Icons.check_circle,
          color: Theme.of(context).colorScheme.secondary);
    }
    return Icon(Icons.info,
        color: Theme.of(context).colorScheme.onSurfaceVariant);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'alert':
        return Colors.red.shade100;
      case 'warning':
        return Colors.orange.shade100;
      default:
        return Colors.green.shade100;
    }
  }
}
