enum PeerStatus { nearby, requestSent, requestReceived, friend }

class Peer {
  final String id;
  String name; // changed from final to mutable
  PeerStatus status;
  DateTime lastSeen;
  

  Peer({
    required this.id,
    required this.name,
    this.status = PeerStatus.nearby,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status.name,
        'lastSeen': lastSeen.millisecondsSinceEpoch,
      };

  factory Peer.fromJson(Map<String, dynamic> json) => Peer(
        id: json['id'],
        name: json['name'],
        status: PeerStatus.values.byName(json['status']),
        lastSeen: DateTime.fromMillisecondsSinceEpoch(json['lastSeen']),
      );
}