// lib/features/mesh/services/mesh_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:crisis_response_app/core/constants/app_constants.dart';
import 'package:crisis_response_app/shared/models/mesh_message_model.dart';
import 'package:crisis_response_app/features/mesh/services/mesh_message_store.dart';
import 'package:crisis_response_app/features/mesh/services/mesh_bridge_service.dart';

/// Connectivity states of this device
enum MeshConnectivityState {
  online,     // Has internet — acts as bridge
  meshOnly,   // No internet, but connected to ≥1 mesh node
  isolated,   // No internet, no mesh peers
  starting,   // Initializing
}

/// Core BLE Mesh service using Google Nearby Connections API.
///
/// Architecture:
///   - Runs in BOTH advertising AND discovery mode simultaneously
///   - This makes every device simultaneously a "server" and "client"
///   - When a message arrives, it's stored locally and re-broadcast to all
///     connected peers (relay), respecting the hop count TTL
///   - If this device has internet, it auto-syncs the bridge queue
///   - Emits streams for UI to observe state changes
class MeshService {
  static final MeshService _instance = MeshService._();
  static MeshService get instance => _instance;
  MeshService._();

  static const String _serviceId = 'com.crisisresponse.mesh';
  static const Strategy _strategy = Strategy.P2P_CLUSTER;
  static const Duration _beaconInterval = Duration(seconds: 60);
  static const Duration _nodeStaleTimeout = Duration(seconds: 45);

  // ── State ─────────────────────────────────────────────────────────────────

  final _nearby = Nearby();
  final _battery = Battery();
  final _storage = const FlutterSecureStorage();
  final _uuid = const Uuid();

  bool _isRunning = false;
  String? _myUserId;
  String? _myUserName;

  // Connected peer endpoints
  final Map<String, MeshNode> _connectedNodes = {};
  // Recently discovered (not yet connected) endpoints
  final Map<String, MeshNode> _discoveredNodes = {};

  Timer? _beaconTimer;
  Timer? _staleNodeTimer;

  // ── Streams ───────────────────────────────────────────────────────────────

  final _connectivityCtrl = StreamController<MeshConnectivityState>.broadcast();
  final _nodesCtrl = StreamController<List<MeshNode>>.broadcast();
  final _messagesCtrl = StreamController<MeshMessage>.broadcast();
  final _logCtrl = StreamController<String>.broadcast();

  Stream<MeshConnectivityState> get connectivityStream => _connectivityCtrl.stream;
  Stream<List<MeshNode>> get nodesStream => _nodesCtrl.stream;
  Stream<MeshMessage> get incomingMessages => _messagesCtrl.stream;
  Stream<String> get logStream => _logCtrl.stream;

  MeshConnectivityState _state = MeshConnectivityState.starting;
  MeshConnectivityState get currentState => _state;
  List<MeshNode> get connectedNodes => _connectedNodes.values.toList();
  List<MeshNode> get allDiscoveredNodes => {
    ..._connectedNodes,
    ..._discoveredNodes,
  }.values.toList();

  // ── Init & Start ──────────────────────────────────────────────────────────

  Future<bool> _checkPermissions() async {
    final permissions = [
      Permission.location,
      if (defaultTargetPlatform == TargetPlatform.android) ...[
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.nearbyWifiDevices,
      ]
    ];

    final status = await permissions.request();
    bool isOk = true;

    for (final entry in status.entries) {
      if (!entry.value.isGranted && !entry.value.isLimited) {
        _log('Permission denied: ${entry.key} -> ${entry.value}');
        
        // nearbyWifiDevices is only strictly needed on Android 13+.
        if (entry.key == Permission.nearbyWifiDevices) {
          _log('Ignoring nearbyWifiDevices denial (often fine on Android < 13).');
          continue;
        }

        // Similarly for Android 12+ Bluetooth permissions on older devices.
        if (entry.key == Permission.bluetoothScan || 
            entry.key == Permission.bluetoothAdvertise || 
            entry.key == Permission.bluetoothConnect) {
           _log('Ignoring BLE specific denial (often fine on Android < 12).');
           continue; 
        }

        isOk = false;
      }
    }

    return isOk;
  }

  Future<void> start() async {
    if (_isRunning) return;
    
    _log('Checking permissions for mesh...');
    if (!await _checkPermissions()) {
      _log('Mesh start failed: Permissions denied');
      return;
    }

    _log('Starting BLE Mesh Service...');

    // Load user identity
    _myUserId = await _storage.read(key: StorageKeys.userId) ?? _uuid.v4();
    final storedName = await _storage.read(key: StorageKeys.userName);
    _myUserName = (storedName != null && storedName != 'Unknown') 
        ? storedName 
        : 'Survivor-${_myUserId!.substring(0, 4)}';

    // Initialize local store
    await MeshMessageStore.instance.init();

    try {
      await _startAdvertising();
      await _startDiscovery();
      _isRunning = true;
      _startBeacon();
      _startStaleNodeCleanup();
      _updateState();
      _log('Mesh active ✓ — advertising as $_myUserName');
    } catch (e) {
      _log('Mesh start error: $e');
    }
  }

  Future<void> stop() async {
    _beaconTimer?.cancel();
    _staleNodeTimer?.cancel();
    _nearby.stopAdvertising();
    _nearby.stopDiscovery();
    _nearby.stopAllEndpoints();
    _connectedNodes.clear();
    _discoveredNodes.clear();
    _isRunning = false;
    _log('Mesh stopped');
  }

  // ── Advertising (makes this device discoverable) ──────────────────────────

  Future<void> _startAdvertising() async {
    try {
      await _nearby.startAdvertising(
        _myUserName!,
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );
      _log('Advertising started: $_myUserName');
    } catch (e) {
      // Ignore if already advertising
      _log('Advertising info: $e');
    }
  }

  // ── Discovery (finds other mesh nodes) ────────────────────────────────────

  Future<void> _startDiscovery() async {
    try {
      await _nearby.startDiscovery(
        _myUserName!,
        _strategy,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: _serviceId,
      );
      _log('Discovery started');
    } catch (e) {
      _log('Discovery info: $e');
    }
  }

  // ── Connection Lifecycle ──────────────────────────────────────────────────

  void _onEndpointFound(String endpointId, String endpointName, String serviceId) async {
    _log('Found peer: $endpointName ($endpointId)');
    
    // Add to discovered nodes immediately for Radar visibility
    _discoveredNodes[endpointId] = MeshNode(
      endpointId: endpointId,
      userId: endpointId,
      name: endpointName,
      hasInternet: false,
      lastSeen: DateTime.now(),
    );
    _nodesCtrl.add(allDiscoveredNodes);

    // ANTI-COLLISION: random delay to prevent 8012 IO collisions 
    // when both devices try to connect at the same time.
    final delay = Random().nextInt(2000);
    await Future.delayed(Duration(milliseconds: 500 + delay));

    // Auto-connect to every found device in cluster mode
    try {
      await _nearby.requestConnection(
        _myUserName!,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      _log('Connection request failed: $e');
    }
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId != null) {
      _discoveredNodes.remove(endpointId);
      _nodesCtrl.add(allDiscoveredNodes);
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    _log('Connection initiated with ${info.endpointName}');
    // Accept all connections automatically — open mesh
    _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: (_, __) {},
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _log('Connected to $endpointId');
      // Success! Move from discovered to connected
      final discoveredNode = _discoveredNodes.remove(endpointId);
      _connectedNodes[endpointId] = MeshNode(
        endpointId: endpointId,
        userId: discoveredNode?.userId ?? endpointId,
        name: discoveredNode?.name ?? 'Verifying...',
        hasInternet: false,
        lastSeen: DateTime.now(),
      );
      _nodesCtrl.add(allDiscoveredNodes);
      _updateState();
      // Send our beacon immediately so they know who we are
      _sendBeaconTo(endpointId);
    } else {
      _log('Connection failed to $endpointId: $status');
    }
  }

  void _onDisconnected(String endpointId) {
    _log('Disconnected from $endpointId');
    _connectedNodes.remove(endpointId);
    _nodesCtrl.add(allDiscoveredNodes);
    _updateState();
  }

  // ── Payload Handling (incoming messages) ──────────────────────────────────

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type != PayloadType.BYTES) return;

    try {
      final jsonStr = utf8.decode(payload.bytes!);
      final outer = jsonDecode(jsonStr) as Map<String, dynamic>;
      final payloadType = outer['type'] as String;

      switch (payloadType) {
        case 'beacon':
          _handleBeacon(endpointId, outer);
        case 'message':
          _handleIncomingMessage(endpointId, outer['msg'] as String);
      }
    } catch (e) {
      _log('Payload parse error: $e');
    }
  }

  /// Process a beacon from a connected peer — update their node info
  void _handleBeacon(String endpointId, Map<String, dynamic> data) {
    final node = MeshNode(
      endpointId: endpointId,
      userId: data['uid'] as String,
      name: data['name'] as String,
      latitude: (data['lat'] as num?)?.toDouble(),
      longitude: (data['lng'] as num?)?.toDouble(),
      hasInternet: (data['inet'] as int? ?? 0) == 1,
      batteryLevel: data['bat'] as int?,
      lastSeen: DateTime.now(),
      rssi: data['rssi'] as int? ?? -70,
    );
    _connectedNodes[endpointId] = node;
    _nodesCtrl.add(allDiscoveredNodes);
    _updateState();

    // If this node has internet and we have pending bridge messages → ask them to forward
    if (node.hasInternet) {
      MeshBridgeService.instance.triggerAutoSync();
    }
  }

  /// Process an incoming mesh message
  Future<void> _handleIncomingMessage(String fromEndpoint, String msgJson) async {
    try {
      final msg = MeshMessage.fromJson(msgJson);
      _log('Received ${msg.typeLabel} from ${msg.senderName} (hop ${msg.hopCount})');

      // Store locally (dedup check inside)
      final isNew = await MeshMessageStore.instance.put(msg);
      if (!isNew) {
        _log('Duplicate message ${msg.id} — dropped');
        return;
      }

      // Notify UI
      _messagesCtrl.add(msg);

      // Relay to all OTHER connected peers (mesh flood relay)
      if (!msg.isExpired) {
        final relayed = msg.withIncrementedHop();
        await _relayToAll(relayed, exceptEndpoint: fromEndpoint);
      }

      // If we have internet, queue for bridge sync
      if (await _hasInternet()) {
        MeshBridgeService.instance.triggerAutoSync();
      }
    } catch (e) {
      _log('Message handle error: $e');
    }
  }

  // ── Sending ───────────────────────────────────────────────────────────────

  /// Send an SOS message over the mesh
  Future<bool> sendSos({
    required String text,
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    final msg = MeshMessage(
      id: _uuid.v4(),
      senderId: _myUserId!,
      senderName: _myUserName!,
      type: MeshMessageType.sos,
      priority: MeshPriority.critical,
      text: text,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      createdAt: DateTime.now(),
      batteryLevel: await _getBattery(),
    );
    return _sendMessage(msg);
  }

  /// Send a text message over the mesh (broadcast or targeted)
  Future<bool> sendText({
    required String text,
    String? targetId,
  }) async {
    final msg = MeshMessage(
      id: _uuid.v4(),
      senderId: _myUserId!,
      senderName: _myUserName!,
      type: MeshMessageType.text,
      priority: targetId != null ? MeshPriority.high : MeshPriority.normal,
      text: text,
      targetId: targetId,
      createdAt: DateTime.now(),
      batteryLevel: await _getBattery(),
    );
    return _sendMessage(msg);
  }

  Future<bool> _sendMessage(MeshMessage msg) async {
    // Store locally first
    await MeshMessageStore.instance.put(msg);
    // Notify our own UI
    _messagesCtrl.add(msg);
    // Broadcast to all connected peers
    await _relayToAll(msg);
    _log('Sent ${msg.typeLabel} to ${_connectedNodes.length} peers');
    // If we have internet, also sync to server
    if (await _hasInternet()) {
      MeshBridgeService.instance.triggerAutoSync();
    }
    return true;
  }

  /// Relay a message to all connected endpoints, optionally skipping one
  Future<void> _relayToAll(MeshMessage msg, {String? exceptEndpoint}) async {
    if (_connectedNodes.isEmpty) return;
    final payload = jsonEncode({'type': 'message', 'msg': msg.toJson()});
    final bytes = utf8.encode(payload);

    for (final endpointId in _connectedNodes.keys) {
      if (endpointId == exceptEndpoint) continue;
      try {
        await _nearby.sendBytesPayload(endpointId, Uint8List.fromList(bytes));
      } catch (e) {
        _log('Relay error to $endpointId: $e');
      }
    }
  }

  // ── Beacon ────────────────────────────────────────────────────────────────

  void _startBeacon() {
    _beaconTimer = Timer.periodic(_beaconInterval, (_) => _broadcastBeacon());
    _broadcastBeacon(); // Send immediately
  }

  Future<void> _broadcastBeacon() async {
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 3),
      );
    } catch (_) {}

    final beacon = jsonEncode({
      'type': 'beacon',
      'uid': _myUserId,
      'name': _myUserName,
      'lat': pos?.latitude,
      'lng': pos?.longitude,
      'inet': (await _hasInternet()) ? 1 : 0,
      'bat': await _getBattery(),
      'rssi': -65, // approximate
    });

    final bytes = Uint8List.fromList(utf8.encode(beacon));
    for (final endpointId in _connectedNodes.keys) {
      try {
        await _nearby.sendBytesPayload(endpointId, bytes);
      } catch (_) {}
    }
  }

  Future<void> _sendBeaconTo(String endpointId) async {
    final beacon = jsonEncode({
      'type': 'beacon',
      'uid': _myUserId,
      'name': _myUserName,
      'inet': (await _hasInternet()) ? 1 : 0,
      'bat': await _getBattery(),
    });
    try {
      await _nearby.sendBytesPayload(
        endpointId,
        Uint8List.fromList(utf8.encode(beacon)),
      );
    } catch (_) {}
  }

  // ── Stale Node Cleanup ────────────────────────────────────────────────────

  void _startStaleNodeCleanup() {
    _staleNodeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final staleIds = _connectedNodes.entries
          .where((e) => e.value.isStale)
          .map((e) => e.key)
          .toList();
      for (final id in staleIds) {
        _connectedNodes.remove(id);
      }
      if (staleIds.isNotEmpty) {
        _nodesCtrl.add(allDiscoveredNodes);
        _updateState();
      }
    });
  }

  // ── State Management ──────────────────────────────────────────────────────

  void _updateState() async {
    final hasNet = await _hasInternet();
    MeshConnectivityState newState;

    if (hasNet) {
      newState = MeshConnectivityState.online;
    } else if (_connectedNodes.isNotEmpty) {
      newState = MeshConnectivityState.meshOnly;
    } else {
      newState = MeshConnectivityState.isolated;
    }

    if (newState != _state) {
      _state = newState;
      _connectivityCtrl.add(_state);
    }
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  Future<bool> _hasInternet() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.any((r) => 
        r == ConnectivityResult.wifi || 
        r == ConnectivityResult.mobile || 
        r == ConnectivityResult.ethernet
      );
    } catch (_) {
      return false;
    }
  }

  Future<int?> _getBattery() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return null;
    }
  }

  void _log(String msg) {
    debugPrint('[MeshService] $msg');
    _logCtrl.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $msg');
  }

  void dispose() {
    stop();
    _connectivityCtrl.close();
    _nodesCtrl.close();
    _messagesCtrl.close();
    _logCtrl.close();
  }
}

// Needed for Uint8List
// import 'dart:typed_data';
