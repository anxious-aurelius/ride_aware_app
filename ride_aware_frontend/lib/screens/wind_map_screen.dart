import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/geo_point.dart';

class WindMapScreen extends StatefulWidget {
  final List<GeoPoint> routePoints;
  final Map<String, dynamic>? windData;

  const WindMapScreen({super.key, required this.routePoints, this.windData});

  @override
  State<WindMapScreen> createState() => _WindMapScreenState();
}

class _WindMapScreenState extends State<WindMapScreen> {
  late WebViewController _webViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wind Visualization')),
      body: WebView(
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (controller) async {
          _webViewController = controller;
          String html = await rootBundle.loadString('assets/wind_map.html');
          List<List<double>> coords = widget.routePoints
              .map((p) => [p.latitude, p.longitude])
              .toList();
          html = html.replaceFirst('ROUTE_COORDS_PLACEHOLDER', jsonEncode(coords));
          String windDataJs = widget.windData != null
              ? jsonEncode(widget.windData)
              : 'null';
          html = html.replaceFirst('WIND_DATA_PLACEHOLDER', windDataJs);
          await _webViewController.loadHtmlString(html);
        },
      ),
    );
  }
}
