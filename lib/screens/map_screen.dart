import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final peerLocation = LatLng(latitude, longitude);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: Text(
          'PEER: $peerId',
          style: const TextStyle(
            color: Color(0xFF00FF88),
            fontFamily: 'monospace',
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF00FF88)),
      ),
      body: Column(
        children: [

          // ── Coordinates Bar ─────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: const Color(0xFF141928),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text('LAT',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 2)),
                    Text(
                      latitude.toStringAsFixed(6),
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
                    const Text('LNG',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 2)),
                    Text(
                      longitude.toStringAsFixed(6),
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

          // ── Map ──────────────────────────────────────────────────
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: peerLocation,
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.crowdlink',
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
                              peerId,
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

        ],
      ),
    );
  }
}