import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/mesh_service.dart';
import '../services/storage_service.dart';
import '../models/peer.dart';
import '../models/chat_message.dart';
import 'map_screen.dart';

class DmScreen extends StatefulWidget {
  final Peer peer;
  const DmScreen({super.key, required this.peer});

  @override
  State<DmScreen> createState() => _DmScreenState();
}

class _DmScreenState extends State<DmScreen> {
  final MeshService _mesh = MeshService();
  final StorageService _storage = StorageService();
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  StreamSubscription? _messageSub;
  StreamSubscription? _seenSub;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _subscribeToMessages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeToMessages();
  }

  void _subscribeToMessages() {
    _messageSub?.cancel();
    _seenSub?.cancel();

    _messageSub = _mesh.messageStream.listen((packet) {
      if (packet.senderId == widget.peer.id ||
          packet.targetId == widget.peer.id) {
        final text = packet.parseMessage();
        if (text != null && mounted) {
          final alreadyExists = _messages.any((m) => m.id == packet.id);
          if (!alreadyExists) {
            final msg = ChatMessage(
              id: packet.id,
              senderId: packet.senderId,
              text: text,
              timestamp: packet.timestamp,
              isOwn: packet.senderId == _mesh.deviceId,
              seen: true,
            );
            if (packet.senderId != _mesh.deviceId) {
              _storage.markAllSeen(widget.peer.id);
            }
            setState(() => _messages.add(msg));
            _scrollToBottom();
          }
        }
      }
    });

    _seenSub = _mesh.seenStream.listen((messageId) {
      if (mounted) {
        setState(() {
          for (final msg in _messages) {
            if (msg.id == messageId && msg.isOwn) {
              msg.seen = true;
            }
          }
        });
      }
    });
  }

  Future<void> _loadHistory() async {
    final msgs = await _storage.loadMessages(widget.peer.id);
    await _storage.markAllSeen(widget.peer.id);
    if (mounted) {
      setState(() {
        _messages.clear();
        _messages.addAll(msgs);
        _loading = false;
      });
      _scrollToBottom();
    }
    for (final msg in msgs) {
      if (!msg.isOwn && !msg.seen) {
        await _mesh.sendSeen(msg.senderId, msg.id);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    await _mesh.broadcastMessage(text, targetId: widget.peer.id);

    final msg = ChatMessage(
      id: DateTime.now().toIso8601String(),
      senderId: _mesh.deviceId,
      text: text,
      timestamp: DateTime.now(),
      isOwn: true,
      seen: false,
    );

    await _storage.saveMessage(widget.peer.id, msg);
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _seenSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141928),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00FF88)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00FF88)),
              ),
              child: Center(
                child: Text(
                  widget.peer.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF00FF88),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.peer.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [

          // ── Messages ──────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00FF88),
                      strokeWidth: 2,
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_outline,
                                color: Colors.white12, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              'Private chat with ${widget.peer.name}',
                              style: const TextStyle(
                                  color: Colors.white24, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Messages travel through the mesh.',
                              style: TextStyle(
                                  color: Colors.white12, fontSize: 11),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) =>
                            _MessageBubble(msg: _messages[i]),
                      ),
          ),

          // ── Input ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            decoration: const BoxDecoration(
              color: Color(0xFF141928),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Message ${widget.peer.name}...',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: const Color(0xFF0A0E1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.send,
                        color: Colors.black, size: 20),
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

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  const _MessageBubble({required this.msg});

  bool get _isLocation => msg.text.startsWith('LOCATION|');

  List<double>? get _coords {
    if (!_isLocation) return null;
    final parts = msg.text.split('|');
    if (parts.length != 3) return null;
    return [double.parse(parts[1]), double.parse(parts[2])];
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: msg.isOwn
              ? const Color(0xFF00FF88).withOpacity(0.15)
              : const Color(0xFF0088FF).withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: msg.isOwn
                ? const Color(0xFF00FF88).withOpacity(0.4)
                : const Color(0xFF0088FF).withOpacity(0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: msg.isOwn
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // ── Location bubble ──────────────────────────────
            if (_isLocation) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_pin,
                      color: msg.isOwn
                          ? const Color(0xFF00FF88)
                          : const Color(0xFF0088FF),
                      size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'Location Shared',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_coords![0].toStringAsFixed(6)}, ${_coords![1].toStringAsFixed(6)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  Position? myPos;
                  try {
                    myPos = await Geolocator.getCurrentPosition(
                      desiredAccuracy: LocationAccuracy.high,
                    );
                  } catch (e) {
                    myPos = null;
                  }
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapScreen(
                          latitude: _coords![0],
                          longitude: _coords![1],
                          peerId: msg.senderId,
                          myLatitude: myPos?.latitude,
                          myLongitude: myPos?.longitude,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: msg.isOwn
                        ? const Color(0xFF00FF88).withOpacity(0.2)
                        : const Color(0xFF0088FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: msg.isOwn
                          ? const Color(0xFF00FF88)
                          : const Color(0xFF0088FF),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined,
                          size: 14,
                          color: msg.isOwn
                              ? const Color(0xFF00FF88)
                              : const Color(0xFF0088FF)),
                      const SizedBox(width: 6),
                      Text(
                        'VIEW ON MAP',
                        style: TextStyle(
                          color: msg.isOwn
                              ? const Color(0xFF00FF88)
                              : const Color(0xFF0088FF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // ── Normal text message ───────────────────────
              Text(
                msg.text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14),
              ),
            ],

            const SizedBox(height: 4),

            // ── Timestamp + tick ──────────────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 10,
                  ),
                ),
                if (msg.isOwn) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.seen ? Icons.done_all : Icons.done,
                    size: 14,
                    color: msg.seen
                        ? const Color(0xFF0088FF)
                        : Colors.white38,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}