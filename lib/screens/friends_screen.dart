import 'package:flutter/material.dart';
import '../services/mesh_service.dart';
import '../models/peer.dart';
import 'dm_screen.dart';
import '../services/storage_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final MeshService _mesh = MeshService();
  Map<String, Peer> _peers = {};
  Map<String, int> _unreadCounts = {};
  Map<String, DateTime> _lastMessageTimes = {};

@override
void initState() {
  super.initState();
  _peers = Map.from(_mesh.peers);
  
  _mesh.peersStream.listen((peers) {
    if (mounted) {
      setState(() => _peers = Map.from(peers));
      _loadUnreadCounts();
      _loadLastMessageTimes();
    }
  });

  // Refresh unread counts when new message arrives
  _mesh.messageStream.listen((packet) {
    if (mounted) {
      _loadUnreadCounts();
      _loadLastMessageTimes();
    }
  });

  _loadUnreadCounts();
  _loadLastMessageTimes();
}

  Future<void> _loadUnreadCounts() async {
    final friends = _peers.values
        .where((p) => p.status == PeerStatus.friend)
        .toList();
    final counts = await StorageService().getAllUnreadCounts(
      friends.map((f) => f.id).toList(),
    );
    if (mounted) setState(() => _unreadCounts = counts);
  }

  Future<void> _loadLastMessageTimes() async {
    final storage = StorageService();
    final Map<String, DateTime> times = {};
    for (final peer in _peers.values.where((p) => p.status == PeerStatus.friend)) {
      final time = await storage.getLastMessageTime(peer.id);
      if (time != null) times[peer.id] = time;
    }
    if (mounted) setState(() => _lastMessageTimes = times);
  }

  // Sorted by most recent message
  List<Peer> get _friends {
    final list = _peers.values
        .where((p) => p.status == PeerStatus.friend)
        .toList();
    list.sort((a, b) {
      final aTime = _lastMessageTimes[a.id] ?? DateTime(0);
      final bTime = _lastMessageTimes[b.id] ?? DateTime(0);
      return bTime.compareTo(aTime);
    });
    return list;
  }

  void _showRemoveDialog(Peer peer) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141928),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        title: const Text(
          'REMOVE FRIEND',
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 14,
            letterSpacing: 3,
          ),
        ),
        content: Text(
          'Remove ${peer.name} from your friends?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _mesh.removeFriend(peer.id);
            },
            child: const Text(
              'REMOVE',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

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
                'FRIENDS',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF00FF88),
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_friends.length} connected',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 24),

              // ── Friends List ──────────────────────────────────────
              Expanded(
                child: _friends.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline,
                                color: Colors.white12, size: 64),
                            const SizedBox(height: 16),
                            const Text(
                              'No friends yet.',
                              style: TextStyle(
                                  color: Colors.white24, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Go to Nearby tab to connect with people.',
                              style: TextStyle(
                                  color: Colors.white12, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _friends.length,
                        itemBuilder: (_, i) {
                          final friend = _friends[i];
                          return _FriendCard(
                            peer: friend,
                            unreadCount: _unreadCounts[friend.id] ?? 0,
                            lastMessageTime: _lastMessageTimes[friend.id],
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => DmScreen(peer: friend)),
                              );
                              _loadUnreadCounts();
                              _loadLastMessageTimes();
                            },
                            onRemove: () => _showRemoveDialog(friend),
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

class _FriendCard extends StatelessWidget {
  final Peer peer;
  final int unreadCount;
  final DateTime? lastMessageTime;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FriendCard({
    required this.peer,
    required this.unreadCount,
    required this.lastMessageTime,
    required this.onTap,
    required this.onRemove,
  });

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141928),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unreadCount > 0
                ? const Color(0xFF00FF88).withOpacity(0.6)
                : const Color(0xFF00FF88).withOpacity(0.2),
            width: unreadCount > 0 ? 1.5 : 1.2,
          ),
        ),
        child: Row(
          children: [

            // ── Avatar ────────────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.15),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: const Color(0xFF00FF88), width: 1.2),
              ),
              child: Center(
                child: Text(
                  peer.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF00FF88),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // ── Name + subtitle ───────────────────────────────────
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
                    unreadCount > 0
                        ? '$unreadCount unread message${unreadCount > 1 ? 's' : ''}'
                        : lastMessageTime != null
                            ? _formatTime(lastMessageTime)
                            : 'ID: ${peer.id}',
                    style: TextStyle(
                      color: unreadCount > 0
                          ? const Color(0xFF00FF88)
                          : Colors.white.withOpacity(0.3),
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: unreadCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // ── Unread badge ──────────────────────────────────────
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // ── DM icon ───────────────────────────────────────────
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline,
                  color: Color(0xFF00FF88), size: 20),
              onPressed: onTap,
            ),

            // ── Remove icon ───────────────────────────────────────
            IconButton(
              icon: const Icon(Icons.person_remove_outlined,
                  color: Colors.redAccent, size: 20),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}