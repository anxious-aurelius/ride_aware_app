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

    final summaryMap = _asStringMap(ride['summary']);
    final thresholdMap = _asStringMap(ride['threshold']);
    final weatherList = _asListOfMaps(ride['weather_history']);

    // threshold values (only these are shown)
    final limits = _asStringMap(thresholdMap['weather_limits']);
    final minTemp = limits['min_temperature'];
    final maxTemp = limits['max_temperature'];
    final windMax = limits['max_wind_speed'];
    final headSens = limits['headwind_sensitivity'];
    final crossSens = limits['crosswind_sensitivity'];
    final rainMax = limits['max_rain_intensity'];
    final humidMax = limits['max_humidity'];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('Ride Details')),
        body: Column(
          children: [
            // header strip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  Text(
                    '$start–$end',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusChip(status: status),
                  const Spacer(),
                  if (feedback.isNotEmpty)
                    Icon(Icons.check_circle,
                        size: 18, color: theme.colorScheme.secondary),
                ],
              ),
            ),
            if (feedback.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(feedback, style: theme.textTheme.bodyMedium),
              ),

            const TabBar(
              tabs: [
                Tab(text: 'Overview', icon: Icon(Icons.list_alt)),
                Tab(text: 'Threshold', icon: Icon(Icons.tune)),
                Tab(text: 'Weather', icon: Icon(Icons.wb_cloudy)),
              ],
            ),
            const SizedBox(height: 6),

            Expanded(
              child: TabBarView(
                children: [
                  // ---------------- OVERVIEW ----------------
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            _infoRow(context, 'Date', dateStr),
                            _infoRow(context, 'Start', start),
                            _infoRow(context, 'End', end),
                            _infoRow(context, 'Status', status),
                            const SizedBox(height: 10),
                            if (summaryMap.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Summary',
                                      style: theme.textTheme.titleMedium),
                                  const SizedBox(height: 6),
                                  ..._sorted(summaryMap)
                                      .map((e) => _infoRow(context,
                                      _labelize(e.key), _toText(e.value))),
                                ],
                              )
                            else
                              Text(
                                'No summary.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color:
                                  theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ---------------- THRESHOLD ----------------
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: _kvTable(context, rows: [
                          _KV(
                            'Temperature range',
                            (_hasValue(minTemp) || _hasValue(maxTemp))
                                ? '${_toText(minTemp)} – ${_toText(maxTemp)} °C'
                                : '—',
                          ),
                          _KV(
                            'Wind speed limit',
                            _hasValue(windMax)
                                ? '${_toText(windMax)} m/s'
                                : '—',
                          ),
                          _KV(
                            'Wind direction limit',
                            (_hasValue(headSens) || _hasValue(crossSens))
                                ? 'Head ${_toText(headSens)} • Cross ${_toText(crossSens)}'
                                : '—',
                          ),
                          _KV('Rain limit',
                              _hasValue(rainMax) ? _toText(rainMax) : '—'),
                          _KV(
                            'Humidity (max)',
                            _hasValue(humidMax)
                                ? '${_toText(humidMax)} %'
                                : '—',
                          ),
                        ]),
                      ),
                    ),
                  ),

                  // ---------------- WEATHER ----------------
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: weatherList.isEmpty
                        ? Center(
                      child: Text(
                        'No weather snapshots collected.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                        : Column(
                      children: [
                        _weatherHeader(context),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.separated(
                            itemCount: weatherList.length,
                            separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final snap = weatherList[i];
                              final ts =
                              (snap['timestamp'] ?? '').toString();
                              final w =
                              _asStringMap(snap['weather']);

                              final time = _fmtIsoToHm(ts);
                              final temp = _firstNonNull(
                                w['temp'],
                                w['temperature'],
                                w['temp_c'],
                              );
                              final wind = _firstNonNull(
                                w['wind_speed'],
                                w['wind_ms'],
                                w['wind'],
                              );

                              return InkWell(
                                onTap: () =>
                                    _showWeatherDetails(context, snap),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          time,
                                          style: theme
                                              .textTheme.bodyMedium,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          _fmtNumOrText(temp, '°C'),
                                          textAlign: TextAlign.center,
                                          style: theme
                                              .textTheme.bodyMedium,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          _fmtNumOrText(wind, ' m/s'),
                                          textAlign: TextAlign.right,
                                          style: theme
                                              .textTheme.bodyMedium,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(Icons.chevron_right,
                                          color: theme.colorScheme
                                              .onSurfaceVariant),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- helpers & small widgets ----------

  static Map<String, dynamic> _asStringMap(dynamic v) {
    if (v is Map) {
      return Map<String, dynamic>.from(
          v.map((k, vv) => MapEntry(k.toString(), vv)));
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _asListOfMaps(dynamic v) {
    if (v is List) {
      return v
          .map((e) =>
      e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  static bool _hasValue(dynamic v) {
    if (v == null) return false;
    if (v is String && v.trim().isEmpty) return false;
    if (v is String && v.trim().toLowerCase() == 'null') return false;
    return true;
  }

  static String _toText(dynamic v) => _hasValue(v) ? v.toString() : '—';

  static String _labelize(String key) {
    return key
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\btemp\b', caseSensitive: false), 'Temperature')
        .replaceAll(RegExp(r'\buvi?\b', caseSensitive: false), 'UV index')
        .replaceAll(RegExp(r'\bdeg\b', caseSensitive: false), 'Direction')
        .trim()
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static String _fmtIsoToHm(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return iso.isNotEmpty ? iso : '—';
    }
  }

  static T? _firstNonNull<T>(dynamic a, [dynamic b, dynamic c]) {
    for (final v in [a, b, c]) {
      if (v != null && (v is! String || v.trim().isNotEmpty)) {
        return v as T?;
      }
    }
    return null;
  }

  // format numbers nicely; keep non-numeric as-is
  static String _fmtNumOrText(dynamic v, String suffix) {
    if (!_hasValue(v)) return '—';
    final n = double.tryParse(v.toString());
    if (n == null) return v.toString();
    return '${n.toStringAsFixed(2)}$suffix';
  }

  List<MapEntry<String, dynamic>> _sorted(Map<String, dynamic> map) {
    final entries = map.entries.toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  // aligned key/value row (used in overview)
  Widget _infoRow(BuildContext context, String k, String v) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            v,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // nice, aligned 2-column table for threshold values
  Widget _kvTable(BuildContext context, {required List<_KV> rows}) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyMedium
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final valueStyle =
    theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (final r in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(r.k, style: labelStyle),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(r.v, style: valueStyle),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // weather list header (aligned with rows)
  Widget _weatherHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('Time',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: Text('Temp (°C)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('Wind (m/s)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ),
          ),
          const SizedBox(width: 22), // space for chevron alignment
        ],
      ),
    );
  }

  void _showWeatherDetails(BuildContext context, Map<String, dynamic> snap) {
    final ts = (snap['timestamp'] ?? '').toString();
    final w = _asStringMap(snap['weather']);

    const preferred = [
      'temp',
      'temperature',
      'temp_c',
      'wind_speed',
      'wind_deg',
      'humidity',
      'rain',
      'visibility',
      'uvi',
      'uv',
      'clouds',
      'pressure'
    ];
    final keys = <String>[
      ...preferred.where(w.containsKey),
      ...w.keys.where((k) => !preferred.contains(k)).toList()..sort(),
    ];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Snapshot ${_fmtIsoToHm(ts)}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: keys.length + 1,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return _infoRow(context, 'Time', _fmtIsoToHm(ts));
                      }
                      final k = keys[i - 1];
                      return _infoRow(context, _labelize(k), _toText(w[k]));
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// simple data holder for table rows
class _KV {
  final String k;
  final String v;
  const _KV(this.k, this.v);
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color color = () {
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
          return theme.colorScheme.primary;
      }
    }();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        status.isNotEmpty ? status : '—',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
