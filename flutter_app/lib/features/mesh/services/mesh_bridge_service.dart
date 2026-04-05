import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/mesh_message_model.dart';
import 'mesh_message_store.dart';

/// Enum for bridge sync status
enum BridgeSyncStatus {
  idle,
  syncing,
  success,
  failed,
  offline,
}

/// Bridges offline mesh messages to the backend server.
///
/// Two modes:
///  1. AUTO: triggered whenever connectivity changes to online,
///     or when a connected mesh node reports it has internet
///  2. MANUAL: user taps "Forward Now" button in UI
///
/// The bridge uploads all unforwarded messages in priority order,
/// marks them as forwarded, and reports back to UI.
class MeshBridgeService {
  static final MeshBridgeService _instance = MeshBridgeService._();
  static MeshBridgeService get instance => _instance;
  MeshBridgeService._();

  final _statusCtrl = StreamController<BridgeSyncStatus>.broadcast();
  final _syncLogCtrl = StreamController<String>.broadcast();

  Stream<BridgeSyncStatus> get statusStream => _statusCtrl.stream;
  Stream<String> get syncLog => _syncLogCtrl.stream;

  BridgeSyncStatus _status = BridgeSyncStatus.idle;
  BridgeSyncStatus get currentStatus => _status;

  int _lastSyncCount = 0;
  DateTime? _lastSyncTime;
  bool _isSyncing = false;

  int get lastSyncCount => _lastSyncCount;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Initialize: watch connectivity changes for auto-sync
  void init() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _log('Network restored — triggering auto bridge sync');
        triggerAutoSync();
      }
    });
  }

  /// Called automatically when internet becomes available
Future<void> triggerAutoSync() async {
    if (_isSyncing) return;
    final result = await Connectivity().checkConnectivity();
    final isConnected = result != ConnectivityResult.none;
    if (!isConnected) {
      _setStatus(BridgeSyncStatus.offline);
      return;
    }
    await _sync(isManual: false);
  }

  /// Called by user tapping "Forward Now"
  Future<SyncResult> manualSync() async {
    final result = await Connectivity().checkConnectivity();
    final isConnected = result != ConnectivityResult.none;
    if (!isConnected) {
      _setStatus(BridgeSyncStatus.offline);
      return SyncResult(success: false, synced: 0, message: 'No internet connection');
    }
    return _sync(isManual: true);
  }

  Future<SyncResult> _sync({required bool isManual}) async {
    _isSyncing = true;
    _setStatus(BridgeSyncStatus.syncing);
    _log(isManual ? 'Manual bridge sync started' : 'Auto bridge sync started');

    final pending = MeshMessageStore.instance.getPendingBridge();

    if (pending.isEmpty) {
      _isSyncing = false;
      _setStatus(BridgeSyncStatus.idle);
      _log('Nothing to sync');
      return SyncResult(success: true, synced: 0, message: 'No pending messages');
    }

    _log('Syncing ${pending.length} messages...');

    int synced = 0;
    int failed = 0;

    for (final msg in pending) {
      try {
        await ApiClient.instance.post('/mesh/bridge', data: {
          'id': msg.id,
          'sender_id': msg.senderId,
          'sender_name': msg.senderName,
          'type': msg.type.name,
          'priority': msg.priority.name,
          'text': msg.text,
          'latitude': msg.latitude,
          'longitude': msg.longitude,
          'target_id': msg.targetId,
          'created_at': msg.createdAt.toIso8601String(),
          'hop_count': msg.hopCount,
          'battery_level': msg.batteryLevel,
        });

        // Mark as forwarded in local store
        await MeshMessageStore.instance.update(msg.asForwarded());
        synced++;
        _log('✓ Synced: ${msg.typeLabel} from ${msg.senderName}');
      } catch (e) {
        failed++;
        _log('✗ Failed: ${msg.id} — $e');
      }
    }

    _lastSyncCount = synced;
    _lastSyncTime = DateTime.now();
    _isSyncing = false;

    final success = failed == 0;
    _setStatus(success ? BridgeSyncStatus.success : BridgeSyncStatus.failed);

    final result = SyncResult(
      success: success,
      synced: synced,
      failed: failed,
      message: success
          ? 'Synced $synced message${synced != 1 ? 's' : ''} to server'
          : 'Synced $synced, failed $failed',
    );
    _log(result.message);
    return result;
  }

  void _setStatus(BridgeSyncStatus s) {
    _status = s;
    _statusCtrl.add(s);
  }

  void _log(String msg) {
    debugPrint('[BridgeService] $msg');
    _syncLogCtrl.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $msg');
  }

  void dispose() {
    _statusCtrl.close();
    _syncLogCtrl.close();
  }
}

class SyncResult {
  final bool success;
  final int synced;
  final int failed;
  final String message;

  const SyncResult({
    required this.success,
    required this.synced,
    this.failed = 0,
    required this.message,
  });
}
