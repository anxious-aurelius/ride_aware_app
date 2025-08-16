import 'package:flutter/foundation.dart';
import 'geo_point.dart';

class RouteModel {
  final String deviceId;
  final String routeName;
  final GeoPoint startLocation;
  final GeoPoint endLocation;
  final List<GeoPoint> routePoints;

  RouteModel({
    required this.deviceId,
    required this.routeName,
    required this.startLocation,
    required this.endLocation,
    required this.routePoints,
  });

  Map<String, dynamic> toJson() => {
    "device_id": deviceId,
    "route_name": routeName,
    "start_location": startLocation.toJson(),
    "end_location": endLocation.toJson(),
    "route_points": routePoints.map((p) => p.toJson()).toList(),
  };

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      deviceId: json['device_id'] as String,
      routeName: json['route_name'] as String,
      startLocation: GeoPoint.fromJson(json['start_location']),
      endLocation: GeoPoint.fromJson(json['end_location']),
      routePoints: (json['route_points'] as List)
          .map((e) => GeoPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  RouteModel copyWith({
    String? deviceId,
    String? routeName,
    GeoPoint? startLocation,
    GeoPoint? endLocation,
    List<GeoPoint>? routePoints,
  }) {
    return RouteModel(
      deviceId: deviceId ?? this.deviceId,
      routeName: routeName ?? this.routeName,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      routePoints: routePoints ?? this.routePoints,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteModel &&
        other.deviceId == deviceId &&
        other.routeName == routeName &&
        other.startLocation == startLocation &&
        other.endLocation == endLocation &&
        listEquals(
          other.routePoints,
          routePoints,
        );
  }

  @override
  int get hashCode =>
      deviceId.hashCode ^
      routeName.hashCode ^
      startLocation.hashCode ^
      endLocation.hashCode ^
      Object.hashAll(routePoints);

  @override
  String toString() {
    return 'RouteModel(deviceId: $deviceId, routeName: $routeName, startLocation: $startLocation, endLocation: $endLocation, routePoints: ${routePoints.length} points)';
  }
}
