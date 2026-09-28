import 'package:uuid/uuid.dart';

enum PacketType { location, message, presence, connectReq, connectAct, seen }


class Packet {
  final String id;
  final PacketType type;
  final String senderId;
  final String senderName;
  final String payload;
  final String? targetId; // for DMs and connect requests
  final int hopCount;
  final int maxHops;
  final DateTime timestamp;

  const Packet({
    required this.id,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.payload,
    this.targetId,
    this.hopCount = 0,
    this.maxHops = 10,
    required this.timestamp,
  });

  // ── Factory constructors ──────────────────────────────────────────────

  factory Packet.location({
  required String senderId,
  required String senderName,
  required double latitude,
  required double longitude,
  String? targetId,
}) {
  return Packet(
    id: const Uuid().v4(),
    type: PacketType.location,
    senderId: senderId,
    senderName: senderName,
    payload: 'LOC|$latitude|$longitude',
    targetId: targetId,
    timestamp: DateTime.now(),
  );
}

  factory Packet.message({
    required String senderId,
    required String senderName,
    required String text,
    String? targetId,
  }) {
    return Packet(
      id: const Uuid().v4(),
      type: PacketType.message,
      senderId: senderId,
      senderName: senderName,
      payload: 'MSG|$text',
      targetId: targetId,
      timestamp: DateTime.now(),
    );
  }

  factory Packet.presence({
    required String senderId,
    required String senderName,
  }) {
    return Packet(
      id: const Uuid().v4(),
      type: PacketType.presence,
      senderId: senderId,
      senderName: senderName,
      payload: 'PRESENCE',
      timestamp: DateTime.now(),
    );
  }

  factory Packet.connectReq({
    required String senderId,
    required String senderName,
    required String targetId,
  }) {
    return Packet(
      id: const Uuid().v4(),
      type: PacketType.connectReq,
      senderId: senderId,
      senderName: senderName,
      payload: 'CONNECT_REQ',
      targetId: targetId,
      timestamp: DateTime.now(),
    );
  }

  factory Packet.connectAct({
    required String senderId,
    required String senderName,
    required String targetId,
    required bool accepted,
  }) {
    return Packet(
      id: const Uuid().v4(),
      type: PacketType.connectAct,
      senderId: senderId,
      senderName: senderName,
      payload: 'CONNECT_ACT|${accepted ? 'accepted' : 'rejected'}',
      targetId: targetId,
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
      senderName,
      targetId ?? 'null',
      hopCount.toString(),
      maxHops.toString(),
      timestamp.millisecondsSinceEpoch.toString(),
      payload,
    ].join('||');
  }

  factory Packet.deserialize(String raw) {
    final parts = raw.split('||');
    if (parts.length < 10 || parts[0] != 'CROWDLINK') {
      throw FormatException('Invalid packet: $raw');
    }
    return Packet(
      id: parts[1],
      type: PacketType.values.byName(parts[2]),
      senderId: parts[3],
      senderName: parts[4],
      targetId: parts[5] == 'null' ? null : parts[5],
      hopCount: int.parse(parts[6]),
      maxHops: int.parse(parts[7]),
      timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[8])),
      payload: parts.sublist(9).join('||'),
    );
  }

  factory Packet.seen({
  required String senderId,
  required String senderName,
  required String targetId,
  required String messageId,
}) {
  return Packet(
    id: const Uuid().v4(),
    type: PacketType.seen,
    senderId: senderId,
    senderName: senderName,
    payload: 'SEEN|$messageId',
    targetId: targetId,
    timestamp: DateTime.now(),
  );
}


  // ── Helpers ───────────────────────────────────────────────────────────

  bool get isExpired => hopCount >= maxHops;

  Packet withIncrementedHop() => Packet(
        id: id,
        type: type,
        senderId: senderId,
        senderName: senderName,
        payload: payload,
        targetId: targetId,
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

  bool? parseConnectAct() {
    if (type != PacketType.connectAct) return null;
    final parts = payload.split('|');
    if (parts.length < 2) return null;
    return parts[1] == 'accepted';
  }
}