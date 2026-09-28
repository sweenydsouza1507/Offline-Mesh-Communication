import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String peerId;

  const MapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.peerId,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final peerLocation = LatLng(widget.latitude, widget.longitude);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: Text(
          'PEER: ${widget.peerId}',
          style: const TextStyle(
            color: Color(0xFF00FF88),
            fontFamily: 'monospace',
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF00FF88)),
        actions: [
          // Zoom in
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF00FF88)),
            onPressed: () => _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom + 1,
            ),
          ),
          // Zoom out
          IconButton(
            icon: const Icon(Icons.remove, color: Color(0xFF00FF88)),
            onPressed: () => _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom - 1,
            ),
          ),
          // Re-center on received location
          IconButton(
            icon: const Icon(Icons.my_location, color: Color(0xFF00FF88)),
            onPressed: () => _mapController.move(peerLocation, 16),
          ),
        ],
      ),
      body: Column(
        children: [

          // ── Coordinates Bar ──────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            color: const Color(0xFF141928),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text(
                      'LAT',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      widget.latitude.toStringAsFixed(6),
                      style: const TextStyle(
                        color: Color(0xFF00FF88),
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 30, color: Colors.white12),
                Column(
                  children: [
                    const Text(
                      'LNG',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      widget.longitude.toStringAsFixed(6),
                      style: const TextStyle(
                        color: Color(0xFF00FF88),
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Map ──────────────────────────────────────────────
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: peerLocation,
                initialZoom: 16,
                minZoom: 13,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'assets/tiles/{z}/{x}/{y}.png',
                  tileProvider: AssetTileProvider(),
                  errorTileCallback: (tile, error, stackTrace) {
                    // Silently ignore missing tiles
                  },
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: peerLocation,
                      width: 80,
                      height: 60,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FF88),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.peerId,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF0A0E1A),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.location_pin,
                            color: Color(0xFF00FF88),
                            size: 32,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Bottom Bar ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            color: const Color(0xFF141928),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline,
                    color: Colors.white24, size: 12),
                SizedBox(width: 6),
                Text(
                  'Offline map — tap 📍 to re-center on location',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}