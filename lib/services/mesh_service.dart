import 'dart:async';

import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:uuid/uuid.dart';
import '../models/packet.dart';
import 'package:permission_handler/permission_handler.dart';

class MeshService {
  static final MeshService _instance = MeshService._internal();
  factory MeshService() => _instance;
  MeshService._internal();

  final Nearby _nearby = Nearby();
  final String _serviceId = 'com.crowdlink.mesh';

  late String _deviceId;

  final Set<String> _seenPacketIds = {};
  final Map<String, String> _connectedEndpoints = {};

  final _locationController = StreamController<Packet>.broadcast();
  final _messageController  = StreamController<Packet>.broadcast();
  final _peersController    = StreamController<Map<String, String>>.broadcast();

  Stream<Packet>              get locationStream => _locationController.stream;
  Stream<Packet>              get messageStream  => _messageController.stream;
  Stream<Map<String, String>> get peersStream    => _peersController.stream;
  Map<String, String>         get connectedPeers => Map.unmodifiable(_connectedEndpoints);
  String                      get deviceId       => _deviceId;

  // ── Init ──────────────────────────────────────────────────────────────

 Future<void> init() async {
  _deviceId = const Uuid().v4().substring(0, 8);
  await _requestPermissions();
  await _startAdvertising();
  await _startDiscovery();
  // Keep mesh alive by restarting discovery every 30 seconds
  Timer.periodic(const Duration(seconds: 30), (_) async {
    await _nearby.stopDiscovery();
    await _startDiscovery();
  });
}

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
      await _nearby.startDiscovery(
        _deviceId,
        Strategy.P2P_CLUSTER,
        onEndpointFound: (endpointId, endpointName, serviceId) {
          _nearby.requestConnection(
            _deviceId,
            endpointId,
            onConnectionInitiated: _onConnectionInitiated,
            onConnectionResult: _onConnectionResult,
            onDisconnected: _onDisconnected,
          );
        },
        onEndpointLost: (endpointId) {
          _connectedEndpoints.remove(endpointId);
          _peersController.add(Map.from(_connectedEndpoints));
        },
        serviceId: _serviceId,
      );
    } catch (e) {
      print('Discovery error: $e');
    }
  }

  // ── Connection Callbacks ──────────────────────────────────────────────

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: (endpointId, update) {},
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _connectedEndpoints[endpointId] = endpointId;
      _peersController.add(Map.from(_connectedEndpoints));
      print('Connected to: $endpointId');
    }
  }

  void _onDisconnected(String endpointId) {
    _connectedEndpoints.remove(endpointId);
    _peersController.add(Map.from(_connectedEndpoints));
    print('Disconnected from: $endpointId');
  }

  // ── Receive & Process ─────────────────────────────────────────────────

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type != PayloadType.BYTES) return;

    final raw = String.fromCharCodes(payload.bytes!);

    try {
      final packet = Packet.deserialize(raw);
      _processPacket(packet);
    } catch (e) {
      print('Malformed packet from $endpointId: $e');
    }
  }

  void _processPacket(Packet packet) {
    // ① Deduplicate
    if (_seenPacketIds.contains(packet.id)) return;
    _seenPacketIds.add(packet.id);

    if (_seenPacketIds.length > 500) {
      _seenPacketIds.remove(_seenPacketIds.first);
    }

    // ② Deliver locally
    if (packet.type == PacketType.location) {
      _locationController.add(packet);
    } else if (packet.type == PacketType.message) {
      _messageController.add(packet);
    }

    // ③ Forward (hop)
    if (!packet.isExpired) {
      _forwardPacket(packet.withIncrementedHop());
    }
  }

  // ── Send ──────────────────────────────────────────────────────────────

  Future<void> sendPacket(Packet packet) async {
    _seenPacketIds.add(packet.id);
    final bytes = Uint8List.fromList(packet.serialize().codeUnits);

    for (final endpointId in _connectedEndpoints.keys) {
      try {
        await _nearby.sendBytesPayload(endpointId, bytes);
      } catch (e) {
        print('Failed to send to $endpointId: $e');
      }
    }
  }

  Future<void> _forwardPacket(Packet packet) => sendPacket(packet);

  // ── Public API ────────────────────────────────────────────────────────

  Future<void> broadcastLocation(double lat, double lng) async {
    final packet = Packet.location(
      senderId: _deviceId,
      latitude: lat,
      longitude: lng,
    );
    await sendPacket(packet);
  }

  Future<void> broadcastMessage(String text) async {
    final packet = Packet.message(
      senderId: _deviceId,
      text: text,
    );
    await sendPacket(packet);
  }

  Future<void> dispose() async {
    await _nearby.stopAdvertising();
    await _nearby.stopDiscovery();
    await _nearby.stopAllEndpoints();
    await _locationController.close();
    await _messageController.close();
    await _peersController.close();
  }
}