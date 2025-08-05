class CommuteStatusResponse {
  final String deviceId;
  final CommuteStatusData start;
  final CommuteStatusData end;

  const CommuteStatusResponse({
    required this.deviceId,
    required this.start,
    required this.end,
  });

  factory CommuteStatusResponse.fromJson(Map<String, dynamic> json) {
    return CommuteStatusResponse(
      deviceId: json['device_id'] as String? ?? '',
      start: CommuteStatusData.fromJson(
        json['start_status'] as Map<String, dynamic>? ?? {},
      ),
      end: CommuteStatusData.fromJson(
        json['end_status'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class CommuteStatusData {
  final List<String> violations;

  const CommuteStatusData({required this.violations});

  factory CommuteStatusData.fromJson(Map<String, dynamic> json) {
    final violations = (json['exceeded'] as List<dynamic>? ?? []).cast<String>();
    return CommuteStatusData(violations: violations);
  }
}
