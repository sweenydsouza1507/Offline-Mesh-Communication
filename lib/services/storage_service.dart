import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // ── Save a message ────────────────────────────────────────────────────
  Future<void> saveMessage(String peerId, ChatMessage msg) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'msgs_$peerId';
    final existing = prefs.getStringList(key) ?? [];
    existing.add(jsonEncode({
      'id': msg.id,
      'senderId': msg.senderId,
      'text': msg.text,
      'timestamp': msg.timestamp.millisecondsSinceEpoch,
      'isOwn': msg.isOwn,
      'seen': msg.seen,
    }));
    // Keep only last 100 messages per chat
    if (existing.length > 100) existing.removeAt(0);
    await prefs.setStringList(key, existing);
  }

  // ── Load messages for a chat ──────────────────────────────────────────
  Future<List<ChatMessage>> loadMessages(String peerId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'msgs_$peerId';
    final saved = prefs.getStringList(key) ?? [];
    return saved.map((s) {
      final m = jsonDecode(s);
      return ChatMessage(
        id: m['id'],
        senderId: m['senderId'],
        text: m['text'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(m['timestamp']),
        isOwn: m['isOwn'],
        seen: m['seen'] ?? false,
      );
    }).toList();
  }

  // ── Mark all messages in a chat as seen ───────────────────────────────
  Future<void> markAllSeen(String peerId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'msgs_$peerId';
    final saved = prefs.getStringList(key) ?? [];
    final updated = saved.map((s) {
      final m = jsonDecode(s);
      m['seen'] = true;
      return jsonEncode(m);
    }).toList();
    await prefs.setStringList(key, updated);
  }

  // ── Get unread count for a peer ───────────────────────────────────────
  Future<int> getUnreadCount(String peerId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'msgs_$peerId';
    final saved = prefs.getStringList(key) ?? [];
    int count = 0;
    for (final s in saved) {
      final m = jsonDecode(s);
      if (!(m['seen'] ?? true) && !(m['isOwn'] ?? false)) count++;
    }
    return count;
  }

  // ── Get total unread across all chats ─────────────────────────────────
  Future<Map<String, int>> getAllUnreadCounts(List<String> peerIds) async {
    final Map<String, int> counts = {};
    for (final id in peerIds) {
      counts[id] = await getUnreadCount(id);
    }
    return counts;
  }


Future<DateTime?> getLastMessageTime(String peerId) async {
  final msgs = await loadMessages(peerId);
  if (msgs.isEmpty) return null;
  return msgs.last.timestamp;
}




}