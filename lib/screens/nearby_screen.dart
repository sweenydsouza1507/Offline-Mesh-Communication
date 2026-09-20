import 'package:flutter/material.dart';
import '../services/mesh_service.dart';
import '../models/peer.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen>
    with SingleTickerProviderStateMixin {
  final MeshService _mesh = MeshService();
  Map<String, Peer> _peers = {};
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _peers = Map.from(_mesh.peers);
    _mesh.peersStream.listen((peers) {
      if (mounted) setState(() => _peers = Map.from(peers));
    });

   
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  

  // Nearby peers sorted by most recently seen
  List<Peer> get _nearbyPeers {
    final list = _peers.values
        .where((p) =>
            p.status == PeerStatus.nearby &&
            (p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                _searchQuery.isEmpty))
        .toList();
    list.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return list;
  }

  // Pending requests sent by me
  List<Peer> get _sentRequests => _peers.values
      .where((p) => p.status == PeerStatus.requestSent)
      .toList();

  // Incoming requests
  List<Peer> get _receivedRequests => _peers.values
      .where((p) => p.status == PeerStatus.requestReceived)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 16),

                  // ── Search bar ────────────────────────────────
                  TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by name...',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 13),
                      prefixIcon: const Icon(Icons.search,
                          color: Colors.white38, size: 20),
                      filled: true,
                      fillColor: const Color(0xFF141928),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── Tabs ─────────────────────────────────────────────
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF00FF88),
              labelColor: const Color(0xFF00FF88),
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              tabs: [
                const Tab(text: 'NEARBY'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('REQUESTS'),
                      if (_sentRequests.isNotEmpty ||
                          _receivedRequests.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00FF88),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_sentRequests.length + _receivedRequests.length}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // ── Tab Content ───────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Tab 1: Nearby people ─────────────────────
                  _buildNearbyTab(),

                  // ── Tab 2: Requests ───────────────────────────
                  _buildRequestsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyTab() {
    return Column(
      children: [
        // Scanning indicator
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Container(
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
                  'Scanning... ${_nearbyPeers.length} found',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: _nearbyPeers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.radar,
                          color: Colors.white12, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No results for "$_searchQuery"'
                            : 'No one nearby yet.',
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ask friends to open CrowdLink.',
                        style: TextStyle(
                            color: Colors.white12, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _nearbyPeers.length,
                  itemBuilder: (_, i) {
                    final peer = _nearbyPeers[i];
                    return _NearbyCard(
                      peer: peer,
                      rank: i + 1,
                      onConnect: () =>
                          _mesh.sendConnectRequest(peer.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRequestsTab() {
    final all = [..._receivedRequests, ..._sentRequests];

    if (all.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_outlined,
                color: Colors.white12, size: 64),
            SizedBox(height: 16),
            Text(
              'No pending requests.',
              style: TextStyle(color: Colors.white24, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Incoming requests
        if (_receivedRequests.isNotEmpty) ...[
          const Text(
            'INCOMING',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          ..._receivedRequests.map((peer) => _RequestCard(
                peer: peer,
                isIncoming: true,
                onAccept: () => _mesh.respondToRequest(peer.id, true),
                onReject: () => _mesh.respondToRequest(peer.id, false),
              )),
          const SizedBox(height: 16),
        ],

        // Sent requests
        if (_sentRequests.isNotEmpty) ...[
          const Text(
            'SENT',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          ..._sentRequests.map((peer) => _RequestCard(
                peer: peer,
                isIncoming: false,
                onAccept: () {},
                onReject: () {},
              )),
        ],
      ],
    );
  }
}

// ── Nearby Card ───────────────────────────────────────────────────────────────

class _NearbyCard extends StatelessWidget {
  final Peer peer;
  final int rank;
  final VoidCallback onConnect;

  const _NearbyCard({
    required this.peer,
    required this.rank,
    required this.onConnect,
  });

  String _lastSeenText() {
    final diff = DateTime.now().difference(peer.lastSeen);
    if (diff.inSeconds < 15) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141928),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rank == 1
              ? const Color(0xFF00FF88).withOpacity(0.5)
              : Colors.white12,
          width: rank == 1 ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank number
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: rank == 1
                  ? const Color(0xFF00FF88).withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rank == 1
                      ? const Color(0xFF00FF88)
                      : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0088FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF0088FF), width: 1.2),
            ),
            child: Center(
              child: Text(
                peer.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF0088FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Name + last seen
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
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _lastSeenText(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Connect button
          GestureDetector(
            onTap: onConnect,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
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
          ),
        ],
      ),
    );
  }
}

// ── Request Card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final Peer peer;
  final bool isIncoming;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestCard({
    required this.peer,
    required this.isIncoming,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141928),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isIncoming
              ? const Color(0xFF00FF88).withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isIncoming
                  ? const Color(0xFF00FF88).withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isIncoming
                    ? const Color(0xFF00FF88)
                    : Colors.orange,
                width: 1.2,
              ),
            ),
            child: Center(
              child: Text(
                peer.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: isIncoming
                      ? const Color(0xFF00FF88)
                      : Colors.orange,
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
                  isIncoming
                      ? 'Wants to connect with you'
                      : 'Request sent • Waiting...',
                  style: TextStyle(
                    color: isIncoming
                        ? const Color(0xFF00FF88).withOpacity(0.7)
                        : Colors.orange.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          if (isIncoming) ...[
            GestureDetector(
              onTap: onReject,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: const Text(
                  'REJECT',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAccept,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF00FF88).withOpacity(0.4)),
                ),
                child: const Text(
                  'ACCEPT',
                  style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: const Text(
                'PENDING',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}