import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/mesh_service.dart';
import '../services/map_service.dart';
import '../models/packet.dart';
import 'chat_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MeshService _mesh = MeshService();

  double? _myLat, _myLng;
  bool _isSending = false;
  String _status = 'IDLE';
  final Map<String, List<double>> _peerLocations = {};
  int _peerCount = 0;

  @override
  void initState() {
    super.initState();
    _listenForPeers();
    _listenForLocations();
  }

  void _listenForPeers() {
    _mesh.peersStream.listen((peers) {
      setState(() => _peerCount = peers.length);
    });
  }

  void _listenForLocations() {
    _mesh.locationStream.listen((packet) {
      final coords = packet.parseLocation();
      if (coords != null) {
        setState(() {
          _peerLocations[packet.senderId] = coords;
          _status = 'Received location from ${packet.senderId}';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF141928),
              content: Text(
                '📍 ${packet.senderId}: ${coords[0].toStringAsFixed(4)}, ${coords[1].toStringAsFixed(4)}',
                style: const TextStyle(color: Color(0xFF00FF88)),
              ),
              action: SnackBarAction(
                label: 'VIEW MAP',
                textColor: const Color(0xFF00FF88),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapScreen(
                      latitude: coords[0],
                      longitude: coords[1],
                      peerId: packet.senderId,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
    });
  }

  Future<void> _getAndBroadcastLocation() async {
    setState(() {
      _isSending = true;
      _status = 'Fetching GPS...';
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _myLat = position.latitude;
        _myLng = position.longitude;
        _status = 'Broadcasting...';
      });

      await _mesh.broadcastLocation(position.latitude, position.longitude);
      setState(() => _status = 'Location broadcasted ✓');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CROWD',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00FF88),
                          letterSpacing: 6,
                          height: 1,
                        ),
                      ),
                      const Text(
                        'LINK',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 6,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${_mesh.deviceId}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  // Peer count badge
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _peerCount > 0
                            ? const Color(0xFF00FF88)
                            : Colors.white24,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$_peerCount',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _peerCount > 0
                                ? const Color(0xFF00FF88)
                                : Colors.white38,
                          ),
                        ),
                        Text(
                          'PEERS',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.4),
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Status Bar ────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF141928),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  '▶  $_status',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFF00FF88),
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── My Location Card ──────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF141928),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _myLat != null
                        ? const Color(0xFF00FF88).withOpacity(0.4)
                        : Colors.white12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MY LOCATION',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_myLat != null) ...[
                      Text(
                        'LAT  ${_myLat!.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFF00FF88),
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'LNG  ${_myLng!.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFF00FF88),
                          fontSize: 16,
                        ),
                      ),
                    ] else
                      const Text(
                        '— — not fetched yet — —',
                        style: TextStyle(
                          color: Colors.white24,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Peer Locations List ───────────────────────────────
              if (_peerLocations.isNotEmpty) ...[
                const Text(
                  'RECEIVED LOCATIONS',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                ..._peerLocations.entries.map((entry) => GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MapScreen(
                            latitude: entry.value[0],
                            longitude: entry.value[1],
                            peerId: entry.key,
                          ),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141928),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF0088FF).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_pin_circle,
                                color: Color(0xFF0088FF), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.key,
                                      style: const TextStyle(
                                          color: Color(0xFF0088FF),
                                          fontFamily: 'monospace',
                                          fontSize: 12)),
                                  Text(
                                    '${entry.value[0].toStringAsFixed(4)}, ${entry.value[1].toStringAsFixed(4)}',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                color: Colors.white24, size: 14),
                          ],
                        ),
                      ),
                    )),
              ],

              const Spacer(),

              // ── Action Buttons ────────────────────────────────────
              // ── Action Buttons ────────────────────────────────────────────────────
Column(
  children: [
    // Row 1 — Broadcast Location + Chat
    Row(
      children: [
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: _isSending ? null : _getAndBroadcastLocation,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              decoration: BoxDecoration(
                color: _isSending
                    ? const Color(0xFF00FF88).withOpacity(0.3)
                    : const Color(0xFF00FF88),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'BROADCAST LOCATION',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          ),
          child: Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF141928),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0088FF)),
            ),
            child: const Icon(Icons.chat_bubble_outline,
                color: Color(0xFF0088FF)),
          ),
        ),
      ],
    ),

    const SizedBox(height: 12),

    // Row 2 — Send Coordinates button (only shows when location is fetched)
    if (_myLat != null)
      GestureDetector(
        onTap: _isSending
            ? null
            : () async {
                setState(() {
                  _isSending = true;
                  _status = 'Sending coordinates...';
                });
                await _mesh.broadcastLocation(_myLat!, _myLng!);
                setState(() {
                  _isSending = false;
                  _status = 'Coordinates sent ✓';
                });
              },
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF141928),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00FF88).withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.send_to_mobile,
                  color: Color(0xFF00FF88), size: 18),
              const SizedBox(width: 10),
              Text(
                'SEND MY COORDINATES  ${_myLat!.toStringAsFixed(4)}, ${_myLng!.toStringAsFixed(4)}',
                style: const TextStyle(
                  color: Color(0xFF00FF88),
                  fontSize: 12,
                  letterSpacing: 1,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
  ],
),

            ],
          ),
        ),
      ),
    );
  }
}