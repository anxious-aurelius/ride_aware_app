import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import '../models/geo_point.dart';

class WindMapScreen extends StatefulWidget {
  final List<GeoPoint> routePoints;

  const WindMapScreen({super.key, required this.routePoints});

  @override
  State<WindMapScreen> createState() => _WindMapScreenState();
}

class _WindMapScreenState extends State<WindMapScreen> {
  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _fetchAndDisplayWindData();
          },
        ),
      );
    _loadInitialHtml();
  }

  Future<void> _loadInitialHtml() async {
    String html = await rootBundle.loadString('assets/wind_map.html');
    List<List<double>> coords = widget.routePoints
        .map((p) => [p.latitude, p.longitude])
        .toList();
    html = html.replaceFirst('ROUTE_COORDS_PLACEHOLDER', jsonEncode(coords));
    await _webViewController.loadHtmlString(html);
  }

  Future<void> _fetchAndDisplayWindData() async {
    List<Map<String, double>> coords = widget.routePoints
        .map((p) => {'lat': p.latitude, 'lon': p.longitude})
        .toList();
    try {
      final uri = Uri.parse('http://81.17.60.64:8888/wind-directions');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'points': coords}),
      );
      if (response.statusCode == 200) {
        List<dynamic> windDataList = jsonDecode(response.body);
        for (var item in windDataList) {
          double lat = item['lat'];
          double lon = item['lon'];
          double windDeg = item['wind_deg'];
          _addWindArrow(lat, lon, windDeg);
        }
      } else {
        debugPrint('Failed to fetch wind data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error during wind data fetch: $e');
    }
  }

  void _addWindArrow(double lat, double lon, double windDeg) {
    final jsCommand =
        '''
      L.marker([$lat, $lon], {
        icon: L.divIcon({
          className: 'leaflet-div-icon wind-arrow',
          html: "<div class='arrow-container' style='transform: rotate(${windDeg}deg);'><div class='arrow'>&#8593;</div></div>",
          iconSize: [60, 60],
          iconAnchor: [30, 30]
        })
      }).addTo(map);
    ''';
    _webViewController.runJavaScript(jsCommand);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wind Visualization')),
      body: SizedBox.expand(
        child: WebViewWidget(controller: _webViewController),
      ),
    );
  }
}
