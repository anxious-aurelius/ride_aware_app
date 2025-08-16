import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // For kDebugMode
import '../models/geo_point.dart';
import '../utils/parsing.dart';

class RoutingService {
  static const String _openRouteServiceApiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjQyM2VmNTJhZTQzYzRkOWFhMGM5M2MyOGM0MTdhNDEwIiwiaCI6Im11cm11cjY0In0=';
  static const String _openRouteServiceBaseUrl =
      'https://api.openrouteservice.org/v2/directions/cycling-road'; // Using cycling-road profile


  Future<List<GeoPoint>> fetchRoutePoints(GeoPoint start, GeoPoint end) async {
    if (_openRouteServiceApiKey == 'YOUR_OPENROUTESERVICE_API_KEY' ||
        _openRouteServiceApiKey.isEmpty) {
      throw Exception(
        'OpenRouteService API Key is not set. Please replace "YOUR_OPENROUTESERVICE_API_KEY" in services/routing_service.dart',
      );
    }


    final String coordinates =
        'start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}';
    final Uri uri = Uri.parse(
      '$_openRouteServiceBaseUrl?api_key=$_openRouteServiceApiKey&$coordinates',
    );

    if (kDebugMode) {
      print('   Routing API Request Debug:');
      print('   Endpoint: $uri');
      print('   Start Point: ${start.latitude}, ${start.longitude}');
      print('   End Point: ${end.latitude}, ${end.longitude}');
    }

    try {
      final response = await http.get(uri);

      if (kDebugMode) {
        print('   Routing API Response: ${response.statusCode}');
        print('   Response Headers: ${response.headers}');
        if (response.body.isNotEmpty) {
          final bodyPreview = response.body.length > 500
              ? '${response.body.substring(0, 500)}...[truncated]'
              : response.body;
          print('   Response Body: $bodyPreview');
        }
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> coordinatesList =
            data['features'][0]['geometry']['coordinates'];

        if (kDebugMode) {
          print('   Route Processing:');
          print('   Raw coordinates count: ${coordinatesList.length}');
          if (coordinatesList.isNotEmpty) {
            print('   First coordinate: ${coordinatesList.first}');
            print('   Last coordinate: ${coordinatesList.last}');
          }
        }

        final routePoints = coordinatesList.map((coord) {
          return GeoPoint(
            latitude: parseDouble(coord[1]),
            longitude: parseDouble(coord[0]),
          );
        }).toList();

        if (kDebugMode) {
          print('   Converted to ${routePoints.length} GeoPoints');
          print('   Route generation completed successfully');
        }

        return routePoints;
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage =
            'Failed to fetch route: ${response.statusCode} - ${errorBody['error']['message'] ?? 'Unknown error'}';

        if (kDebugMode) {
          print('   Routing API Error Response:');
          print('   Status Code: ${response.statusCode}');
          print('   Error Body: ${response.body}');
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        print('   Routing API Exception:');
        print('   Error Type: ${e.runtimeType}');
        print('   Error Message: $e');
        print(
          '   This could be a network issue, API key problem, or invalid coordinates',
        );
      }
      throw Exception('Network error or invalid route: $e');
    }
  }
}
