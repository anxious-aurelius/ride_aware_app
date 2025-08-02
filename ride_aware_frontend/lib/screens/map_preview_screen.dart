import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPreviewScreen extends StatefulWidget {
  final List<LatLng> routePoints;
  final LatLng mapCenter;
  final LatLng startPoint;
  final LatLng endPoint;

  const MapPreviewScreen({
    super.key,
    required this.routePoints,
    required this.mapCenter,
    required this.startPoint,
    required this.endPoint,
  });

  @override
  State<MapPreviewScreen> createState() => _MapPreviewScreenState();
}

class _MapPreviewScreenState extends State<MapPreviewScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Move map to center and zoom level after the map is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(widget.mapCenter, 13.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commute Route Preview'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.mapCenter,
              initialZoom: 13.0, // A good default zoom for a route
              interactionOptions: const InteractionOptions(
                flags:
                    InteractiveFlag.all &
                    ~InteractiveFlag
                        .rotate, // Allow pan and zoom, but not rotate
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.active_commuter_support',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints,
                    color: Colors.blue,
                    strokeWidth: 5.0,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Start Marker (Home)
                  Marker(
                    point: widget.startPoint,
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.home,
                      color: Colors.green,
                      size: 40,
                    ),
                  ),
                  // End Marker (Office)
                  Marker(
                    point: widget.endPoint,
                    width: 80,
                    height: 80,
                    child: const Icon(Icons.work, color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
          // Custom Zoom Buttons
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoomInBtn', // Unique tag for hero animation
                  mini: true,
                  onPressed: () {
                    _mapController.move(
                      _mapController.center,
                      _mapController.zoom + 1,
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'zoomOutBtn', // Unique tag for hero animation
                  mini: true,
                  onPressed: () {
                    _mapController.move(
                      _mapController.center,
                      _mapController.zoom - 1,
                    );
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
