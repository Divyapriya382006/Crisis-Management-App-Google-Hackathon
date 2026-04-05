// lib/features/mesh/services/mesh_message_store.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../../../shared/models/mesh_message_model.dart';

/// Local persistent store for mesh messages.
/// Handles:
///  - Deduplication (same message ID never stored twice)
///  - TTL expiry cleanup (messages older than 24h removed)
///  - Priority-sorted retrieval for relay queue
///  - Unforwarded message queue for bridge syncing
class MeshMessageStore {
  static const String _boxName = 'mesh_messages';
  static const Duration _messageTtl = Duration(hours: 24);

  static MeshMessageStore? _instance;
  static MeshMessageStore get instance {
    _instance ??= MeshMessageStore._();
    return _instance!;
  }
  MeshMessageStore._();

  Box? _box;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
    await _cleanup();
  }

  Box get _store {
    if (_box == null || !_box!.isOpen) throw StateError('MeshMessageStore not initialized');
    return _box!;
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Store a message. Returns false if already exists (dedup).
  Future<bool> put(MeshMessage msg) async {
    if (_store.containsKey(msg.id)) return false; // deduplicate
    if (msg.isExpired) return false;               // drop expired TTL
    await _store.put(msg.id, msg.toHive());
    return true;
  }

  /// Update a message (e.g. mark as forwarded)
  Future<void> update(MeshMessage msg) async {
    await _store.put(msg.id, msg.toHive());
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// All stored messages sorted by priority then time (newest first)
  List<MeshMessage> getAll() {
    final messages = _store.values
        .map((v) => MeshMessage.fromHive(v as Map<dynamic, dynamic>))
        .where((m) => !_isExpiredByTime(m))
        .toList();

    messages.sort((a, b) {
      // Critical first
      final pCmp = a.priority.index.compareTo(b.priority.index);
      if (pCmp != 0) return pCmp;
      // Then newest first
      return b.createdAt.compareTo(a.createdAt);
    });
    return messages;
  }

  /// Messages pending relay (not yet forwarded to server)
  List<MeshMessage> getPendingBridge() => getAll()
      .where((m) => !m.isForwardedToServer && m.type != MeshMessageType.ping)
      .toList();

  /// Messages addressed to a specific user
  List<MeshMessage> getForUser(String userId) => getAll()
      .where((m) => m.targetId == null || m.targetId == userId)
      .toList();

  /// SOS messages only
  List<MeshMessage> getSosMessages() => getAll()
      .where((m) => m.type == MeshMessageType.sos)
      .toList();

  /// Check if we've already seen this message ID
  bool contains(String messageId) => _store.containsKey(messageId);

  int get count => _store.length;

  // ── Cleanup ───────────────────────────────────────────────────────────────

  bool _isExpiredByTime(MeshMessage m) =>
      DateTime.now().difference(m.createdAt) > _messageTtl;

  Future<void> _cleanup() async {
    final expiredKeys = _store.keys.where((key) {
      final v = _store.get(key);
      if (v == null) return true;
      final m = MeshMessage.fromHive(v as Map<dynamic, dynamic>);
      return _isExpiredByTime(m);
    }).toList();

    for (final key in expiredKeys) {
      await _store.delete(key);
    }
  }

  Future<void> clear() async => _store.clear();
}
