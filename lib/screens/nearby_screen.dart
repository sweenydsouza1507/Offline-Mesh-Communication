import 'package:flutter/material.dart';
import '../services/mesh_service.dart';
import '../models/peer.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final MeshService _mesh = MeshService();
  Map<String, Peer> _peers = {};

  @override
  void initState() {
    super.initState();
    _peers = Map.from(_mesh.peers);
    _mesh.peersStream.listen((peers) {
      if (mounted) setState(() => _peers = Map.from(peers));
    });

    // Listen for incoming friend requests
    _mesh.connectReqStream.listen((peer) {
      if (mounted) _showRequestDialog(peer);
    });

    // Listen for request responses
    _mesh.connectActStream.listen((peer) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF141928),
            content: Text(
              peer.status == PeerStatus.friend
                  ? '✅ ${peer.name} accepted your request!'
                  : '❌ ${peer.name} rejected your request.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    });
  }

  void _showRequestDialog(Peer peer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141928),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00FF88), width: 1),
        ),
        title: const Text(
          'FRIEND REQUEST',
          style: TextStyle(
            color: Color(0xFF00FF88),
            fontSize: 14,
            letterSpacing: 3,
          ),
        ),
        content: Text(
          '${peer.name} wants to connect with you.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _mesh.respondToRequest(peer.id, false);
            },
            child: const Text(
              'REJECT',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _mesh.respondToRequest(peer.id, true);
            },
            child: const Text(
              'ACCEPT',
              style: TextStyle(color: Color(0xFF00FF88)),
            ),
          ),
        ],
      ),
    );
  }

  List<Peer> get _nearbyPeers => _peers.values
      .where((p) =>
          p.status == PeerStatus.nearby ||
          p.status == PeerStatus.requestSent ||
          p.status == PeerStatus.requestReceived)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header ───────────────────────────────────────────
              const Text(
                'NEARBY',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF00FF88),
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'People running CrowdLink near you',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 24),

              // ── Scanning indicator ────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF141928),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00FF88),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Scanning for nearby devices...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Peers List ────────────────────────────────────────
              Expanded(
                child: _nearbyPeers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.radar,
                                color: Colors.white12, size: 64),
                            const SizedBox(height: 16),
                            const Text(
                              'No one nearby yet.',
                              style: TextStyle(
                                  color: Colors.white24, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ask your friends to open CrowdLink.',
                              style: TextStyle(
                                  color: Colors.white12, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _nearbyPeers.length,
                        itemBuilder: (_, i) {
                          final peer = _nearbyPeers[i];
                          return _PeerCard(
                            peer: peer,
                            onConnect: () =>
                                _mesh.sendConnectRequest(peer.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeerCard extends StatelessWidget {
  final Peer peer;
  final VoidCallback onConnect;

  const _PeerCard({required this.peer, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141928),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _borderColor(),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _avatarColor().withOpacity(0.15),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _avatarColor(), width: 1.2),
            ),
            child: Center(
              child: Text(
                peer.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: _avatarColor(),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusText(),
                  style: TextStyle(
                    color: _avatarColor().withOpacity(0.7),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          // Action button
          _actionButton(),
        ],
      ),
    );
  }

  Color _borderColor() {
    switch (peer.status) {
      case PeerStatus.requestSent:
        return Colors.orange.withOpacity(0.5);
      case PeerStatus.requestReceived:
        return const Color(0xFF00FF88).withOpacity(0.5);
      default:
        return Colors.white12;
    }
  }

  Color _avatarColor() {
    switch (peer.status) {
      case PeerStatus.requestSent:
        return Colors.orange;
      case PeerStatus.requestReceived:
        return const Color(0xFF00FF88);
      default:
        return const Color(0xFF0088FF);
    }
  }

  String _statusText() {
    switch (peer.status) {
      case PeerStatus.requestSent:
        return 'Request sent...';
      case PeerStatus.requestReceived:
        return 'Wants to connect!';
      default:
        return 'Nearby';
    }
  }

  Widget _actionButton() {
    switch (peer.status) {
      case PeerStatus.requestSent:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.4)),
          ),
          child: const Text(
            'PENDING',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case PeerStatus.requestReceived:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF00FF88).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFF00FF88).withOpacity(0.4)),
          ),
          child: const Text(
            'RESPOND',
            style: TextStyle(
              color: Color(0xFF00FF88),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      default:
        return GestureDetector(
          onTap: onConnect,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0088FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF0088FF).withOpacity(0.4)),
            ),
            child: const Text(
              'CONNECT',
              style: TextStyle(
                color: Color(0xFF0088FF),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
    }
  }
}