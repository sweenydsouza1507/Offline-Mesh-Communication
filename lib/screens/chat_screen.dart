import 'package:flutter/material.dart';
import '../services/mesh_service.dart';
import '../models/packet.dart';
import '../models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MeshService _mesh = MeshService();
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _mesh.messageStream.listen((packet) {
      final text = packet.parseMessage();
      if (text != null) {
        setState(() {
          _messages.add(ChatMessage(
            id: packet.id,
            senderId: packet.senderId,
            text: text,
            timestamp: packet.timestamp,
            isOwn: packet.senderId == _mesh.deviceId,
          ));
        });
        _scrollToBottom();
      }
    });
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

    await _mesh.broadcastMessage(text);

    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().toIso8601String(),
        senderId: _mesh.deviceId,
        text: text,
        timestamp: DateTime.now(),
        isOwn: true,
      ));
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: const Text(
          'MESH CHAT',
          style: TextStyle(
            color: Color(0xFF00FF88),
            letterSpacing: 4,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF00FF88)),
      ),
      body: Column(
        children: [

          // ── Messages ─────────────────────────────────────────────
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_tethering,
                            color: Colors.white12, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'No messages yet.',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Messages hop to all nearby devices.',
                          style: TextStyle(
                              color: Colors.white12, fontSize: 12),
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

          // ── Input Bar ────────────────────────────────────────────
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
                      hintText: 'Type a message...',
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

// ── Message Bubble Widget ─────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          msg.isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            if (!msg.isOwn)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg.senderId,
                  style: const TextStyle(
                    color: Color(0xFF0088FF),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            Text(
              msg.text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}