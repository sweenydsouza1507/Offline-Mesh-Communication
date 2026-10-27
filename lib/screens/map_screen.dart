import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String peerId;
  final double? myLatitude;
  final double? myLongitude;

  const MapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.peerId,
    this.myLatitude,
    this.myLongitude,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  // Calculate distance between two coordinates in metres
  double _distanceInMetres(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  String _formatDistance(double metres) {
    if (metres < 1000) return '${metres.toStringAsFixed(0)}m away';
    return '${(metres / 1000).toStringAsFixed(2)}km away';
  }

  // Midpoint between two coordinates
  LatLng _midpoint(LatLng a, LatLng b) {
    return LatLng(
      (a.latitude + b.latitude) / 2,
      (a.longitude + b.longitude) / 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendLocation = LatLng(widget.latitude, widget.longitude);
    final bool hasMyLocation =
        widget.myLatitude != null && widget.myLongitude != null;
    final myLocation = hasMyLocation
        ? LatLng(widget.myLatitude!, widget.myLongitude!)
        : null;

    // Calculate distance if both locations available
    double? distance;
    if (hasMyLocation) {
      distance = _distanceInMetres(
        widget.myLatitude!,
        widget.myLongitude!,
        widget.latitude,
        widget.longitude,
      );
    }

    // Center map — if both locations, show midpoint; else friend's location
    final initialCenter = (hasMyLocation && myLocation != null)
        ? _midpoint(friendLocation, myLocation)
        : friendLocation;

    // Zoom — if both locations, zoom out a bit to show both
    final initialZoom = hasMyLocation ? 15.0 : 16.0;

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
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF00FF88)),
            onPressed: () => _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom + 1,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove, color: Color(0xFF00FF88)),
            onPressed: () => _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom - 1,
            ),
          ),
          // Re-center to show both markers
          IconButton(
            icon: const Icon(Icons.fit_screen, color: Color(0xFF00FF88)),
            onPressed: () => _mapController.move(
              initialCenter,
              initialZoom,
            ),
          ),
        ],
      ),
      body: Column(
        children: [

          // ── Distance + coordinates bar ────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            color: const Color(0xFF141928),
            child: Column(
              children: [
                // Distance badge
                if (distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF00FF88).withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.straighten,
                            color: Color(0xFF00FF88), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _formatDistance(distance),
                          style: const TextStyle(
                            color: Color(0xFF00FF88),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),

                // Coordinates row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Friend's location
                    Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_pin,
                                color: Color(0xFF00FF88), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              widget.peerId,
                              style: const TextStyle(
                                color: Color(0xFF00FF88),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontFamily: 'monospace',
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),

                    if (hasMyLocation) ...[
                      Container(
                          width: 1, height: 30, color: Colors.white12),
                      // My location
                      Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.my_location,
                                  color: Color(0xFF0088FF), size: 12),
                              SizedBox(width: 4),
                              Text(
                                'YOU',
                                style: TextStyle(
                                  color: Color(0xFF0088FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${widget.myLatitude!.toStringAsFixed(5)}, ${widget.myLongitude!.toStringAsFixed(5)}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontFamily: 'monospace',
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                initialCenter: initialCenter,
                initialZoom: initialZoom,
                minZoom: 13,
                maxZoom: 18,
              ),
              children: [
                // Tile layer
                TileLayer(
                  urlTemplate: 'assets/tiles/{z}/{x}/{y}.png',
                  tileProvider: AssetTileProvider(),
                  errorTileCallback: (tile, error, stackTrace) {},
                ),

                // Line between you and friend
                if (hasMyLocation && myLocation != null)
                  PolylineLayer(
                    polylines: [
                     Polyline(
                        points: [myLocation, friendLocation],
                        color: const Color(0xFF00FF88).withOpacity(0.7),
                        strokeWidth: 2.5,
                      ),
                    ],
                  ),

                // Markers
                MarkerLayer(
                  markers: [
                    // Friend marker (green)
                    Marker(
                      point: friendLocation,
                      width: 100,
                      height: 65,
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

                    // My marker (blue) — only if location available
                    if (hasMyLocation && myLocation != null)
                      Marker(
                        point: myLocation,
                        width: 80,
                        height: 65,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0088FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'YOU',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.location_pin,
                              color: Color(0xFF0088FF),
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

          // ── Bottom bar ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            color: const Color(0xFF141928),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.circle,
                    color: Color(0xFF00FF88), size: 8),
                const SizedBox(width: 6),
                Text(
                  widget.peerId,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(width: 16),
                if (hasMyLocation) ...[
                  const Icon(Icons.circle,
                      color: Color(0xFF0088FF), size: 8),
                  const SizedBox(width: 6),
                  const Text(
                    'You',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.more_horiz,
                      color: Color(0xFF00FF88), size: 12),
                  const SizedBox(width: 6),
                  const Text(
                    'Straight line path',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}