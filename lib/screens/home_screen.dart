import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/mesh_service.dart';
import '../services/map_service.dart';
import '../models/packet.dart';
import 'chat_screen.dart';
import 'map_screen.dart';
import '../models/peer.dart';
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
  int _peerCount = 0;

  @override
  void initState() {
    super.initState();
    _listenForPeers();
      }

  void _listenForPeers() {
    _mesh.peersStream.listen((peers) {
      setState(() => _peerCount = peers.length);
    });
  }

  
  void _showSendToFriendDialog() {
  final friends = _mesh.peers.values
      .where((p) => p.status == PeerStatus.friend)
      .toList();

  if (friends.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF141928),
        content: Text(
          'No friends yet. Connect with someone in the Nearby tab first.',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
    return;
  }

  // Track selected friends
  final Set<String> selected = {};

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF141928),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SEND TO FRIENDS',
              style: TextStyle(
                color: Color(0xFF00FF88),
                fontSize: 13,
                letterSpacing: 3,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_myLat!.toStringAsFixed(6)}, ${_myLng!.toStringAsFixed(6)}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 20),
            ...friends.map((friend) => GestureDetector(
                  onTap: () {
                    setSheetState(() {
                      if (selected.contains(friend.id)) {
                        selected.remove(friend.id);
                      } else {
                        selected.add(friend.id);
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected.contains(friend.id)
                          ? const Color(0xFF00FF88).withOpacity(0.1)
                          : const Color(0xFF0A0E1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected.contains(friend.id)
                            ? const Color(0xFF00FF88)
                            : const Color(0xFF00FF88).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00FF88).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: const Color(0xFF00FF88), width: 1),
                          ),
                          child: Center(
                            child: Text(
                              friend.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF00FF88),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          friend.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          selected.contains(friend.id)
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: selected.contains(friend.id)
                              ? const Color(0xFF00FF88)
                              : Colors.white24,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 12),
            // Send button
            GestureDetector(
              onTap: selected.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);
                      setState(() {
                        _isSending = true;
                        _status = 'Sending to ${selected.length} friend(s)...';
                      });
                      for (final friendId in selected) {
                        await _mesh.broadcastLocation(
                          _myLat!,
                          _myLng!,
                          targetId: friendId,
                        );
                      }
                      setState(() {
                        _isSending = false;
                        _status = 'Location sent to ${selected.length} friend(s) ✓';
                      });
                    },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: selected.isEmpty
                      ? const Color(0xFF00FF88).withOpacity(0.3)
                      : const Color(0xFF00FF88),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    selected.isEmpty
                        ? 'SELECT FRIENDS'
                        : 'SEND TO ${selected.length} FRIEND${selected.length > 1 ? 'S' : ''}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
    onTap: _isSending ? null : () => _showSendToFriendDialog(),
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
            'SEND COORDINATES TO FRIEND',
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