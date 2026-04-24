import 'package:uuid/uuid.dart';

enum PacketType { location, message }

class Packet {
  final String id;
  final PacketType type;
  final String senderId;
  final String payload;
  final int hopCount;
  final int maxHops;
  final DateTime timestamp;

  const Packet({
    required this.id,
    required this.type,
    required this.senderId,
    required this.payload,
    this.hopCount = 0,
    this.maxHops = 5,
    required this.timestamp,
  });

  // ── Factory constructors ──────────────────────────────────────────────

  factory Packet.location({
    required String senderId,
    required double latitude,
    required double longitude,
  }) {
    return Packet(
      id: const Uuid().v4(),
      type: PacketType.location,
      senderId: senderId,
      payload: 'LOC|$latitude|$longitude',
      timestamp: DateTime.now(),
    );
  }

  factory Packet.message({
    required String senderId,
    required String text,
  }) {
    return Packet(
      id: const Uuid().v4(),
      type: PacketType.message,
      senderId: senderId,
      payload: 'MSG|$text',
      timestamp: DateTime.now(),
    );
  }

  // ── Serialization ─────────────────────────────────────────────────────

  String serialize() {
    return [
      'CROWDLINK',
      id,
      type.name,
      senderId,
      hopCount.toString(),
      maxHops.toString(),
      timestamp.millisecondsSinceEpoch.toString(),
      payload,
    ].join('|');
  }

  factory Packet.deserialize(String raw) {
    final parts = raw.split('|');
    if (parts.length < 8 || parts[0] != 'CROWDLINK') {
      throw FormatException('Invalid packet: $raw');
    }
    return Packet(
      id: parts[1],
      type: PacketType.values.byName(parts[2]),
      senderId: parts[3],
      hopCount: int.parse(parts[4]),
      maxHops: int.parse(parts[5]),
      timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[6])),
      payload: parts.sublist(7).join('|'),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  bool get isExpired => hopCount >= maxHops;

  Packet withIncrementedHop() => Packet(
        id: id,
        type: type,
        senderId: senderId,
        payload: payload,
        hopCount: hopCount + 1,
        maxHops: maxHops,
        timestamp: timestamp,
      );

  List<double>? parseLocation() {
    if (type != PacketType.location) return null;
    final parts = payload.split('|');
    if (parts.length != 3) return null;
    return [double.parse(parts[1]), double.parse(parts[2])];
  }

  String? parseMessage() {
    if (type != PacketType.message) return null;
    final parts = payload.split('|');
    if (parts.length < 2) return null;
    return parts.sublist(1).join('|');
  }
}