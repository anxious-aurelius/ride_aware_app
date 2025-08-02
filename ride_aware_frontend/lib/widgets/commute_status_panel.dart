import 'package:flutter/material.dart';
import '../models/commute_status.dart';
import '../services/commute_status_service.dart';

class CommuteStatusPanel extends StatefulWidget {
  final String? deviceId;
  final VoidCallback? onRefresh;

  const CommuteStatusPanel({super.key, this.deviceId, this.onRefresh});

  @override
  State<CommuteStatusPanel> createState() => _CommuteStatusPanelState();
}

class _CommuteStatusPanelState extends State<CommuteStatusPanel> {
  final CommuteStatusApiService _apiService = CommuteStatusApiService();

  CommuteStatusResponse? _statusData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCommuteStatus();
  }

  Future<void> _loadCommuteStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statusData = await _apiService.getCommuteStatus();
      setState(() {
        _statusData = statusData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshStatus() async {
    await _loadCommuteStatus();
    if (widget.onRefresh != null) {
      widget.onRefresh!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.directions_bike,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Commute Status',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: _refreshStatus,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh Status',
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            if (_isLoading)
              _buildLoadingState()
            else if (_errorMessage != null)
              _buildErrorState()
            else if (_statusData != null)
              _buildStatusContent()
            else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading commute status...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t load commute status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('No commute status available'),
      ),
    );
  }

  Widget _buildStatusContent() {
    if (_statusData == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Morning Commute
        _buildCommuteCard(
          title: 'Morning Commute',
          icon: Icons.wb_sunny_outlined,
          data: _statusData!.morning,
        ),

        const SizedBox(height: 16),

        // Evening Commute
        _buildCommuteCard(
          title: 'Evening Commute',
          icon: Icons.nights_stay_outlined,
          data: _statusData!.evening,
        ),
      ],
    );
  }

  Widget _buildCommuteCard({
    required String title,
    required IconData icon,
    required CommuteStatusData data,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: data.statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: data.statusColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: data.statusColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.statusEmoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      data.statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Forecast details
          _buildForecastSection(data),

          // Violations (if any)
          if (data.violations.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildViolationsSection(data),
          ],

          // Recommendation (if any)
          if (data.recommendation != null) ...[
            const SizedBox(height: 12),
            _buildRecommendationSection(data),
          ],

          // Confidence indicator
          const SizedBox(height: 8),
          _buildConfidenceIndicator(data),
        ],
      ),
    );
  }

  Widget _buildForecastSection(CommuteStatusData data) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Forecast',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildForecastItem(
                  icon: Icons.thermostat,
                  label: 'Temperature',
                  value: '${data.forecast.temperature.toStringAsFixed(0)}°C',
                  threshold:
                      '${data.thresholds.temperatureMin.toStringAsFixed(0)} - ${data.thresholds.temperatureMax.toStringAsFixed(0)}°C',
                ),
              ),
              Expanded(
                child: _buildForecastItem(
                  icon: Icons.air,
                  label: 'Wind',
                  value: '${data.forecast.windSpeed.toStringAsFixed(0)} km/h',
                  threshold:
                      '${data.thresholds.windSpeed.toStringAsFixed(0)} km/h max',
                ),
              ),
              Expanded(
                child: _buildForecastItem(
                  icon: Icons.water_drop,
                  label: 'Rain',
                  value: '${data.forecast.rain.toStringAsFixed(1)} mm/h',
                  threshold:
                      '${data.thresholds.rain.toStringAsFixed(1)} mm/h max',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForecastItem({
    required IconData icon,
    required String label,
    required String value,
    required String threshold,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          threshold,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildViolationsSection(CommuteStatusData data) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: data.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: data.statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, size: 16, color: data.statusColor),
              const SizedBox(width: 6),
              Text(
                'Issues',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: data.statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...data.violations.map(
            (violation) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• $violation',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: data.statusColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationSection(CommuteStatusData data) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommendation',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(data.recommendation!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceIndicator(CommuteStatusData data) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Icons.analytics_outlined,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          'Forecast confidence: ${data.forecast.confidence.toUpperCase()}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
