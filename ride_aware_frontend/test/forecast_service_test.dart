import 'dart:convert';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:active_commuter_support/services/forecast_service.dart';
import 'package:active_commuter_support/services/device_id_service.dart';
import 'package:active_commuter_support/models/geo_point.dart';
import 'package:active_commuter_support/models/user_preferences.dart';

class _FakeDeviceIdService extends DeviceIdService {
  @override
  Future<String?> getParticipantIdHash() async => 'test-device';
}

void main() {
  test('getForecast parses numeric strings to doubles', () async {
    final mockResponse = {
      'wind_speed': '5.5',
      'wind_deg': '180',
      'rain': '0.1',
      'humidity': '70',
      'temp': '15',
      'visibility': '10000',
      'uvi': '3',
      'clouds': '75',
    };

    final mockClient = MockClient((request) async {
      return http.Response(jsonEncode(mockResponse), 200);
    });

    final service = ForecastService(
      client: mockClient,
      deviceIdService: _FakeDeviceIdService(),
    );

    final result = await service.getForecast(0, 0, DateTime.now());

    expect(result['wind_speed'], isA<double>());
    expect(result['wind_deg'], isA<double>());
    expect(result['rain'], isA<double>());
    expect(result['humidity'], isA<double>());
    expect(result['temp'], isA<double>());
    expect(result['visibility'], isA<double>());
    expect(result['uvi'], isA<double>());
    expect(result['clouds'], isA<double>());
  });

  test('evaluateRoute posts points and returns data', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, equals('POST'));
      expect(request.url.path, contains('/api/forecast/route'));
      return http.Response(
          jsonEncode({
            'status': 'ok',
            'issues': [],
            'borderline': [],
            'summary': {'max_wind_speed': 5}
          }),
          200);
    });

    final service = ForecastService(
      client: mockClient,
      deviceIdService: _FakeDeviceIdService(),
    );

    final res = await service.evaluateRoute(
      [GeoPoint(latitude: 0, longitude: 0)],
      DateTime.now(),
      WeatherLimits.defaultValues(),
    );
    expect(res['summary']['max_wind_speed'], 5);
  });
}
