import '../utils/parsing.dart';

class GeoPoint {
  final double latitude;
  final double longitude;

  GeoPoint({required this.latitude, required this.longitude});

  Map<String, dynamic> toJson() => {
    "latitude": latitude,
    "longitude": longitude,
  };

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        latitude: parseDouble(json['latitude']),
        longitude: parseDouble(json['longitude']),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeoPoint &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() {
    return 'GeoPoint(latitude: $latitude, longitude: $longitude)';
  }
}
