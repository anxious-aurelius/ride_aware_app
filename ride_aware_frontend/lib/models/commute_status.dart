class CommuteStatusResponse {
  final String deviceId;
  final CommuteStatusData morning;
  final CommuteStatusData evening;

  const CommuteStatusResponse({
    required this.deviceId,
    required this.morning,
    required this.evening,
  });

  factory CommuteStatusResponse.fromJson(Map<String, dynamic> json) {
    return CommuteStatusResponse(
      deviceId: json['device_id'] as String? ?? '',
      morning: CommuteStatusData.fromJson(
        json['morning_status'] as Map<String, dynamic>? ?? {},
      ),
      evening: CommuteStatusData.fromJson(
        json['evening_status'] as Map<String, dynamic>? ?? {},
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
