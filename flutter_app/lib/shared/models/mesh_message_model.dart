// lib/shared/models/mesh_message_model.dart
import 'dart:convert';

/// Types of messages that can travel over the BLE mesh
enum MeshMessageType {
  sos,        // Emergency SOS with GPS
  text,       // Short text message
  ping,       // "I'm alive" beacon (auto-sent every 60s)
  bridge,     // Internal: marks a message as forwarded to server
}

/// Priority levels — determines relay order in the mesh queue
enum MeshPriority {
  critical,   // SOS — always relayed first
  high,       // Targeted messages
  normal,     // Broadcasts and pings
}

/// A single message unit that travels across the BLE mesh network.
/// Each message carries enough data to be self-contained and deduplicated
/// by any node that receives it.
class MeshMessage {
  final String id;              // UUID — used for deduplication across hops
  final String senderId;        // Sender's user ID
  final String senderName;      // Display name (shown in UI)
  final MeshMessageType type;
  final MeshPriority priority;
  final String? text;           // Text content (SOS description or chat)
  final double? latitude;       // GPS — required for SOS
  final double? longitude;
  final double? accuracy;       // GPS accuracy in meters
  final String? targetId;       // null = broadcast, set = targeted message
  final DateTime createdAt;
  final int hopCount;           // Incremented each time message is relayed
  final int maxHops;            // TTL — drop message after this many hops
  final bool isForwardedToServer; // True once a bridge node synced it
  final int? batteryLevel;      // Sender's battery % (useful for rescuers)

  const MeshMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.priority,
    this.text,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.targetId,
    required this.createdAt,
    this.hopCount = 0,
    this.maxHops = 5,
    this.isForwardedToServer = false,
    this.batteryLevel,
  });

  /// Serialize to JSON string for BLE transmission
  /// Kept compact to fit within BLE packet size constraints (~512 bytes)
  String toJson() => jsonEncode({
    'id': id,
    'sid': senderId,
    'sn': senderName,
    't': type.index,
    'p': priority.index,
    if (text != null) 'tx': text,
    if (latitude != null) 'lat': latitude,
    if (longitude != null) 'lng': longitude,
    if (accuracy != null) 'acc': accuracy,
    if (targetId != null) 'tid': targetId,
    'ca': createdAt.millisecondsSinceEpoch,
    'h': hopCount,
    'mh': maxHops,
    'fs': isForwardedToServer ? 1 : 0,
    if (batteryLevel != null) 'bat': batteryLevel,
  });

  /// Parse from JSON string received over BLE
  factory MeshMessage.fromJson(String jsonStr) {
    final m = jsonDecode(jsonStr) as Map<String, dynamic>;
    return MeshMessage(
      id: m['id'],
      senderId: m['sid'],
      senderName: m['sn'],
      type: MeshMessageType.values[m['t'] as int],
      priority: MeshPriority.values[m['p'] as int],
      text: m['tx'],
      latitude: (m['lat'] as num?)?.toDouble(),
      longitude: (m['lng'] as num?)?.toDouble(),
      accuracy: (m['acc'] as num?)?.toDouble(),
      targetId: m['tid'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['ca'] as int),
      hopCount: m['h'] as int? ?? 0,
      maxHops: m['mh'] as int? ?? 5,
      isForwardedToServer: (m['fs'] as int? ?? 0) == 1,
      batteryLevel: m['bat'] as int?,
    );
  }

  /// Create a relay copy with incremented hop count
  MeshMessage withIncrementedHop() => MeshMessage(
    id: id,
    senderId: senderId,
    senderName: senderName,
    type: type,
    priority: priority,
    text: text,
    latitude: latitude,
    longitude: longitude,
    accuracy: accuracy,
    targetId: targetId,
    createdAt: createdAt,
    hopCount: hopCount + 1,
    maxHops: maxHops,
    isForwardedToServer: isForwardedToServer,
    batteryLevel: batteryLevel,
  );

  /// Mark as forwarded to server
  MeshMessage asForwarded() => MeshMessage(
    id: id,
    senderId: senderId,
    senderName: senderName,
    type: type,
    priority: priority,
    text: text,
    latitude: latitude,
    longitude: longitude,
    accuracy: accuracy,
    targetId: targetId,
    createdAt: createdAt,
    hopCount: hopCount,
    maxHops: maxHops,
    isForwardedToServer: true,
    batteryLevel: batteryLevel,
  );

  /// Has this message exceeded its TTL?
  bool get isExpired => hopCount >= maxHops;

  /// Is this message addressed to a specific user?
  bool get isTargeted => targetId != null;

  /// Human-readable type label
  String get typeLabel => switch (type) {
    MeshMessageType.sos => '🆘 SOS',
    MeshMessageType.text => '💬 Message',
    MeshMessageType.ping => '📡 Ping',
    MeshMessageType.bridge => '🌐 Bridge',
  };

  /// Hive storage map (simpler than full JSON)
  Map<String, dynamic> toHive() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'type': type.index,
    'priority': priority.index,
    'text': text,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'targetId': targetId,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'hopCount': hopCount,
    'maxHops': maxHops,
    'isForwardedToServer': isForwardedToServer,
    'batteryLevel': batteryLevel,
  };

  factory MeshMessage.fromHive(Map<dynamic, dynamic> m) => MeshMessage(
    id: m['id'],
    senderId: m['senderId'],
    senderName: m['senderName'],
    type: MeshMessageType.values[m['type'] as int],
    priority: MeshPriority.values[m['priority'] as int],
    text: m['text'],
    latitude: (m['latitude'] as num?)?.toDouble(),
    longitude: (m['longitude'] as num?)?.toDouble(),
    accuracy: (m['accuracy'] as num?)?.toDouble(),
    targetId: m['targetId'],
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
    hopCount: m['hopCount'] as int? ?? 0,
    maxHops: m['maxHops'] as int? ?? 5,
    isForwardedToServer: m['isForwardedToServer'] as bool? ?? false,
    batteryLevel: m['batteryLevel'] as int?,
  );
}

/// Represents a nearby mesh node discovered over BLE
class MeshNode {
  final String endpointId;   // Nearby Connections endpoint ID
  final String userId;       // App user ID (from beacon payload)
  final String name;         // Display name
  final double? latitude;
  final double? longitude;
  final bool hasInternet;    // True if node has active internet
  final int? batteryLevel;
  final DateTime lastSeen;
  final int rssi;            // Signal strength (-100 = weak, 0 = strong)

  const MeshNode({
    required this.endpointId,
    required this.userId,
    required this.name,
    this.latitude,
    this.longitude,
    required this.hasInternet,
    this.batteryLevel,
    required this.lastSeen,
    this.rssi = -70,
  });

  /// Signal quality label
  String get signalLabel {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -65) return 'Good';
    if (rssi >= -80) return 'Fair';
    return 'Weak';
  }

  /// Distance estimation from RSSI (very rough)
  String get distanceEstimate {
    if (rssi >= -50) return '~5m';
    if (rssi >= -65) return '~20m';
    if (rssi >= -80) return '~50m';
    return '~100m+';
  }

  bool get isStale => DateTime.now().difference(lastSeen).inSeconds > 30;
}
