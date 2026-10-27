import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/packet.dart';
import '../models/peer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/chat_message.dart';
import 'storage_service.dart';
import 'notification_service.dart';

class MeshService {
  static final MeshService _instance = MeshService._internal();
  factory MeshService() => _instance;
  MeshService._internal();

  final Nearby _nearby = Nearby();
  final String _serviceId = 'com.crowdlink.mesh';

  String _deviceId = '';
  String _deviceName = '';

  final Set<String> _seenPacketIds = {};
  final Map<String, String> _connectedEndpoints = {};
  final Set<String> _pendingEndpoints = {};
  final List<Packet> _outbox = [];
  final Map<String, Peer> _peers = {}; // all known peers

  Timer? _presenceTimer;
  Timer? _healthTimer;
  bool _initialized = false;

  // ── Streams ───────────────────────────────────────────────────────────
  final _locationController = StreamController<Packet>.broadcast();
  final _messageController = StreamController<Packet>.broadcast();
  final _peersController = StreamController<Map<String, Peer>>.broadcast();
  final _connectReqController = StreamController<Peer>.broadcast();
  final _connectActController = StreamController<Peer>.broadcast();
  final _seenController = StreamController<String>.broadcast();

  Stream<String> get seenStream => _seenController.stream;
  Stream<Packet> get locationStream => _locationController.stream;
  Stream<Packet> get messageStream => _messageController.stream;
  // Replays current peers to every new listener, so a re-opened screen
  // doesn't miss events that fired while it wasn't subscribed.
  Stream<Map<String, Peer>> get peersStream async* {
    yield Map.from(_peers);
    yield* _peersController.stream;
  }
  Stream<Peer> get connectReqStream => _connectReqController.stream;
  Stream<Peer> get connectActStream => _connectActController.stream;

  Map<String, Peer> get peers => Map.unmodifiable(_peers);
  String get deviceId => _deviceId;
  String get deviceName => _deviceName;

  // ── Init ──────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) {
      await resume();
      return;
    }
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _deviceName = prefs.getString('user_name') ?? 'Unknown';

    // Generate ID once and NEVER change it
    String? savedId = prefs.getString('device_id');
    if (savedId == null || savedId.isEmpty) {
      savedId = const Uuid().v4().substring(0, 8);
      await prefs.setString('device_id', savedId);
      print('DEBUG: Generated new device ID: $savedId');
    } else {
      print('DEBUG: Using existing device ID: $savedId');
    }
    _deviceId = savedId;

    await _loadFriends();
    await _requestPermissions();
    await _startAdvertising();
    await _startDiscovery();

    // Presence every 5 seconds (only useful when someone is connected)
    _presenceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_connectedEndpoints.isNotEmpty) _broadcastPresence();
    });

    // Only restart if truly idle (no connections AND nothing in progress)
    _healthTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (_connectedEndpoints.isEmpty && _pendingEndpoints.isEmpty) {
        try {
          await _startAdvertising();
          await _startDiscovery();
        } catch (e) {
          print('Reconnect error: $e');
        }
      }
    });
  }

  /// Call on app resume (and when a screen reopens). Android can silently
  /// kill advertising/discovery/connections while the app is backgrounded.
  Future<void> resume() async {
    _pendingEndpoints.clear();
    _connectedEndpoints.clear(); // stale after background; they re-form fast
    await _startAdvertising();
    await _startDiscovery();
    _peersController.add(Map.from(_peers));
  }

  void _expirePending(String endpointId) {
    Future.delayed(const Duration(seconds: 15), () {
      if (!_connectedEndpoints.containsKey(endpointId)) {
        _pendingEndpoints.remove(endpointId);
      }
    });
  }

  // ── Permissions ───────────────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();
  }

  // ── Advertising ───────────────────────────────────────────────────────

  Future<void> _startAdvertising() async {
    try {
      await _nearby.stopAdvertising();
    } catch (e) {
      // Ignore stop errors
    }
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      await _nearby.startAdvertising(
        _deviceId,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );
    } catch (e) {
      print('Advertising error: $e');
    }
  }

  // ── Discovery ─────────────────────────────────────────────────────────

  Future<void> _startDiscovery() async {
    try {
      await _nearby.stopDiscovery();
    } catch (e) {
      // Ignore stop errors
    }
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      await _nearby.startDiscovery(
        _deviceId,
        Strategy.P2P_CLUSTER,
        onEndpointFound: (endpointId, endpointName, serviceId) {
          if (_connectedEndpoints.containsKey(endpointId) ||
              _pendingEndpoints.contains(endpointId)) return;

          // Higher ID initiates immediately; lower ID waits as a fallback.
          // endpointName is the remote's deviceId (we advertise with it).
          final iInitiate = _deviceId.compareTo(endpointName) > 0;
          final delay = iInitiate ? Duration.zero : const Duration(seconds: 4);

          Future.delayed(delay, () => _requestConn(endpointId));
        },
        onEndpointLost: (endpointId) {
          // Do NOT touch _connectedEndpoints: "lost from discovery"
          // does not mean "disconnected".
          _pendingEndpoints.remove(endpointId);
        },
        serviceId: _serviceId,
      );
    } catch (e) {
      print('Discovery error: $e');
    }
  }

  Future<void> _requestConn(String endpointId) async {
    if (_connectedEndpoints.containsKey(endpointId) ||
        _pendingEndpoints.contains(endpointId)) return;
    _pendingEndpoints.add(endpointId);
    _expirePending(endpointId);
    try {
      await _nearby.requestConnection(
        _deviceId,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      _pendingEndpoints.remove(endpointId);
    }
  }

  // ── Seen ──────────────────────────────────────────────────────────────

  Future<void> sendSeen(String targetId, String messageId) async {
    final packet = Packet.seen(
      senderId: _deviceId,
      senderName: _deviceName,
      targetId: targetId,
      messageId: messageId,
    );
    await sendPacket(packet);
  }

  // ── Connection Callbacks ──────────────────────────────────────────────

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    _pendingEndpoints.add(endpointId);
    _expirePending(endpointId);
    _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: (id, update) {},
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    _pendingEndpoints.remove(endpointId);
    if (status == Status.CONNECTED) {
      _connectedEndpoints[endpointId] = endpointId;
      // Small delay so the other side is ready to receive
      Future.delayed(const Duration(milliseconds: 500), () async {
        await _broadcastPresence();
        await _flushOutbox();
      });
    }
  }

  void _onDisconnected(String endpointId) {
    print('DEBUG: Disconnected from $endpointId');
    _connectedEndpoints.remove(endpointId);
    _pendingEndpoints.remove(endpointId);
    _peersController.add(Map.from(_peers));
    // No discovery restart here; the endpoint will be re-found on its own,
    // and the health timer covers the fully-idle case.
  }

  // ── Receive & Process ─────────────────────────────────────────────────

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type != PayloadType.BYTES || payload.bytes == null) return;
    try {
      final raw = utf8.decode(payload.bytes!);
      _processPacket(Packet.deserialize(raw));
    } catch (e) {
      print('Malformed packet: $e');
    }
  }

  void _processPacket(Packet packet) {
    if (_seenPacketIds.contains(packet.id)) return;
    _seenPacketIds.add(packet.id);
    if (_seenPacketIds.length > 500) {
      _seenPacketIds.remove(_seenPacketIds.first);
    }

    print('DEBUG received: type=${packet.type.name} targetId=${packet.targetId} '
        'myId=$_deviceId match=${packet.targetId == _deviceId}');

    switch (packet.type) {
      case PacketType.presence:
        _handlePresence(packet);
        break;

      case PacketType.connectReq:
        if (packet.targetId == _deviceId) {
          _handleConnectReq(packet);
        }
        break;

      case PacketType.connectAct:
        if (packet.targetId == _deviceId) {
          _handleConnectAct(packet);
        }
        break;

      case PacketType.location:
        _locationController.add(packet);
        break;

      case PacketType.message:
        if (packet.targetId == null || packet.targetId == _deviceId) {
          _messageController.add(packet);

          if (packet.senderId != _deviceId && packet.targetId == _deviceId) {
            // Save message to storage even if chat is not open
            final text = packet.parseMessage();
            if (text != null) {
              final ChatMessage chatMsg = ChatMessage(
                id: packet.id,
                senderId: packet.senderId,
                text: text,
                timestamp: packet.timestamp,
                isOwn: false,
                seen: false,
              );
              StorageService().saveMessage(packet.senderId, chatMsg);
            }

            // Show notification
            NotificationService().showMessageNotification(
              senderName: packet.senderName,
              message: packet.parseMessage() ?? '',
              peerId: packet.senderId,
            );
          }
        }
        break;

      case PacketType.seen:
        if (packet.targetId == _deviceId) {
          final parts = packet.payload.split('|');
          if (parts.length > 1) _seenController.add(parts[1]);
        }
        break;
    }

    // Forward if not expired, and not if it was meant only for us
    final forMe = packet.targetId == _deviceId;
    if (!forMe && !packet.isExpired) {
      _forwardPacket(packet.withIncrementedHop());
    }
  }

  // ── Presence ──────────────────────────────────────────────────────────

  void _handlePresence(Packet packet) {
    if (packet.senderId == _deviceId) return;

    // Check if we have this person as friend under a different ID
    final friendByName = _peers.values
        .where((p) =>
            p.name == packet.senderName &&
            p.status == PeerStatus.friend &&
            p.id != packet.senderId)
        .firstOrNull;

    if (friendByName != null) {
      print('DEBUG: Friend ${packet.senderName} changed ID from '
          '${friendByName.id} to ${packet.senderId}');
      _peers.remove(friendByName.id);
      _peers[packet.senderId] = Peer(
        id: packet.senderId,
        name: packet.senderName,
        status: PeerStatus.friend,
        lastSeen: DateTime.now(),
      );
      _saveFriends();
    } else {
      final existing = _peers[packet.senderId];
      if (existing != null) {
        existing.lastSeen = DateTime.now();
        existing.name = packet.senderName;
      } else {
        _peers[packet.senderId] = Peer(
          id: packet.senderId,
          name: packet.senderName,
          status: PeerStatus.nearby,
          lastSeen: DateTime.now(),
        );
      }
    }
    _peersController.add(Map.from(_peers));
  }

  Future<void> _broadcastPresence() async {
    final packet = Packet.presence(
      senderId: _deviceId,
      senderName: _deviceName,
    );
    await sendPacket(packet);
  }

  // ── Friend Requests ───────────────────────────────────────────────────

  void _handleConnectReq(Packet packet) {
    final peer = _peers[packet.senderId] ??
        Peer(
          id: packet.senderId,
          name: packet.senderName,
          status: PeerStatus.requestReceived,
          lastSeen: DateTime.now(),
        );
    peer.status = PeerStatus.requestReceived;
    _peers[packet.senderId] = peer;
    _peersController.add(Map.from(_peers));
    _connectReqController.add(peer);

    NotificationService().showFriendRequestNotification(
      senderName: packet.senderName,
    );
  }

  void _handleConnectAct(Packet packet) {
    final accepted = packet.parseConnectAct() ?? false;
    final peer = _peers[packet.senderId];
    if (peer != null) {
      peer.status = accepted ? PeerStatus.friend : PeerStatus.nearby;
      _peers[packet.senderId] = peer;
      _peersController.add(Map.from(_peers));
      _connectActController.add(peer);
      if (accepted) _saveFriends();
    }
  }

  Future<void> sendConnectRequest(String targetId) async {
    final peer = _peers[targetId];
    if (peer != null) {
      peer.status = PeerStatus.requestSent;
      _peersController.add(Map.from(_peers));
    }
    final packet = Packet.connectReq(
      senderId: _deviceId,
      senderName: _deviceName,
      targetId: targetId,
    );
    await sendPacket(packet);
  }

  Future<void> respondToRequest(String targetId, bool accepted) async {
    final peer = _peers[targetId];
    if (peer != null) {
      peer.status = accepted ? PeerStatus.friend : PeerStatus.nearby;
      _peersController.add(Map.from(_peers));
      if (accepted) _saveFriends();
    }
    final packet = Packet.connectAct(
      senderId: _deviceId,
      senderName: _deviceName,
      targetId: targetId,
      accepted: accepted,
    );
    await sendPacket(packet);
  }

  Future<void> removeFriend(String peerId) async {
    final peer = _peers[peerId];
    if (peer != null) {
      peer.status = PeerStatus.nearby;
      _peersController.add(Map.from(_peers));
    }
    await _saveFriends();
  }

  // ── Persist Friends ───────────────────────────────────────────────────

  Future<void> _saveFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final friends = _peers.values
        .where((p) => p.status == PeerStatus.friend)
        .map((p) => jsonEncode(p.toJson()))
        .toList();
    await prefs.setStringList('friends', friends);
  }

  Future<void> _loadFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('friends') ?? [];
    for (final s in saved) {
      final peer = Peer.fromJson(jsonDecode(s));
      peer.status = PeerStatus.friend;
      _peers[peer.id] = peer;
    }
  }

  // ── Update name ───────────────────────────────────────────────────────

  Future<void> updateName(String name) async {
    _deviceName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    // Immediately broadcast presence with new name
    await _broadcastPresence();
  }

  // ── Send ──────────────────────────────────────────────────────────────

  Future<void> sendPacket(Packet packet) async {
    _seenPacketIds.add(packet.id);

    if (_connectedEndpoints.isEmpty) {
      // Keep only important packets (not presence spam)
      if (packet.type != PacketType.presence && _outbox.length < 100) {
        _outbox.add(packet);
      }
      return;
    }

    final bytes = Uint8List.fromList(utf8.encode(packet.serialize()));
    final dead = <String>[];
    for (final endpointId in _connectedEndpoints.keys.toList()) {
      try {
        await _nearby.sendBytesPayload(endpointId, bytes);
      } catch (e) {
        print('Send error to $endpointId: $e');
        dead.add(endpointId);
      }
    }
    for (final id in dead) {
      _connectedEndpoints.remove(id);
    }
  }

  Future<void> _flushOutbox() async {
    if (_outbox.isEmpty) return;
    final pending = List<Packet>.from(_outbox);
    _outbox.clear();
    for (final p in pending) {
      if (!p.isExpired) await sendPacket(p);
    }
  }

  Future<void> _forwardPacket(Packet packet) => sendPacket(packet);

  Future<void> broadcastLocation(double lat, double lng,
      {String? targetId}) async {
    if (targetId != null) {
      final msg = Packet.message(
        senderId: _deviceId,
        senderName: _deviceName,
        text: 'LOCATION|$lat|$lng',
        targetId: targetId,
      );
      await sendPacket(msg);

      // Save to local chat history so sender sees it too
      final StorageService storage = StorageService();
      final ChatMessage chatMsg = ChatMessage(
        id: msg.id,
        senderId: _deviceId,
        text: 'LOCATION|$lat|$lng',
        timestamp: DateTime.now(),
        isOwn: true,
        seen: false,
      );
      await storage.saveMessage(targetId, chatMsg);
    }

    final packet = Packet.location(
      senderId: _deviceId,
      senderName: _deviceName,
      latitude: lat,
      longitude: lng,
      targetId: targetId,
    );
    await sendPacket(packet);
  }

  Future<void> broadcastMessage(String text, {String? targetId}) async {
    final packet = Packet.message(
      senderId: _deviceId,
      senderName: _deviceName,
      text: text,
      targetId: targetId,
    );
    await sendPacket(packet);

    // Save to local storage so sender sees their own message
    if (targetId != null) {
      final ChatMessage chatMsg = ChatMessage(
        id: packet.id,
        senderId: _deviceId,
        text: text,
        timestamp: DateTime.now(),
        isOwn: true,
        seen: false,
      );
      await StorageService().saveMessage(targetId, chatMsg);
    }
  }

  /// Stops everything but keeps the singleton reusable.
  /// Never close the stream controllers: this is a singleton, and a closed
  /// controller throws on every later add().
  Future<void> dispose() async {
    _presenceTimer?.cancel();
    _healthTimer?.cancel();
    _initialized = false;
    _connectedEndpoints.clear();
    _pendingEndpoints.clear();
    await _nearby.stopAdvertising();
    await _nearby.stopDiscovery();
    await _nearby.stopAllEndpoints();
  }
}