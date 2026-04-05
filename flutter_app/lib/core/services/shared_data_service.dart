import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../network/api_client.dart';
import '../network/network_checker.dart';
import '../constants/app_constants.dart';

/// Single source of truth for all cross-role data.
/// All roles (user, admin, responder) read and write here.
/// Works fully offline via Hive local storage.
class SharedDataService {
  static const String _boxName = 'shared_data';

  static SharedDataService? _instance;
  static SharedDataService get instance {
    _instance ??= SharedDataService._();
    return _instance!;
  }
  SharedDataService._();
  
  Timer? _syncTimer;
  final _eventCtrl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get eventStream => _eventCtrl.stream;

  Box get _box => Hive.box(_boxName);

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    // Start background sync
    instance._startSync();
  }

  void _startSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchRemoteUpdates();
    });
  }

  Future<void> _fetchRemoteUpdates() async {
    final isConnected = await NetworkChecker.instance.isConnected;
    if (!isConnected) return; // Silent return when offline for mesh testing

    try {
      // 1. Fetch Alerts
      final alertsRes = await ApiClient.instance.get('/alerts/latest');
      if (alertsRes.data != null) {
        final List<dynamic> remoteAlerts = alertsRes.data;
        final currentAlerts = getAlerts();
        
        for (var raw in remoteAlerts) {
          final alert = Map<String, dynamic>.from(raw);
          if (!currentAlerts.any((a) => a['id'] == alert['id'])) {
            publishAlert(
              title: alert['title'],
              body: alert['body'],
              type: alert['type'],
              source: alert['source'] ?? 'Remote System',
            );
            _eventCtrl.add({'type': 'alert', 'data': alert});
          }
        }
      }

      // 2. Fetch Requests (SOS)
      final reqsRes = await ApiClient.instance.get('/requests/active');
      if (reqsRes.data != null) {
        final List<dynamic> remoteReqs = reqsRes.data;
        final currentReqs = getRequests();

        for (var raw in remoteReqs) {
          final req = Map<String, dynamic>.from(raw);
          if (!currentReqs.any((r) => r['id'] == req['id'])) {
            // Add as local SOS message
            _eventCtrl.add({'type': 'request', 'data': req});
          }
        }
      }
    } catch (e) {
      // Silent fail for polling in MVP
    }
  }

  // ── ALERTS (admin → users/responders) ────────────────────────────────────

  List<Map<String, dynamic>> getAlerts() {
    final saved = _box.get('alerts');
    if (saved == null) return _defaultAlerts();
    return (saved as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void publishAlert({
    required String title,
    required String body,
    required String type,
    String source = 'Crisis Response Admin',
  }) {
    final alerts = getAlerts();
    alerts.insert(0, {
      'id': 'alert_${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'body': body,
      'type': type,
      'source': source,
      'timestamp': DateTime.now().toIso8601String(),
      'isRead': false,
    });
    _box.put('alerts', alerts);
  }

  void markAlertRead(String id) {
    final alerts = getAlerts();
    final idx = alerts.indexWhere((a) => a['id'] == id);
    if (idx != -1) {
      final updated = Map<String, dynamic>.from(alerts[idx]);
      updated['isRead'] = true;
      alerts[idx] = updated;
      _box.put('alerts', alerts);
      _eventCtrl.add({'type': 'update_alerts'});
    }
  }

  void markAllAlertsRead() {
    final alerts = getAlerts();
    final updatedAlerts = alerts.map((a) {
      final updated = Map<String, dynamic>.from(a);
      updated['isRead'] = true;
      return updated;
    }).toList();
    _box.put('alerts', updatedAlerts);
    _eventCtrl.add({'type': 'update_alerts'});
  }

  void clearAllAlerts() {
    _box.put('alerts', []);
    _eventCtrl.add({'type': 'update_alerts'});
  }

  List<Map<String, dynamic>> _defaultAlerts() {
    final defaults = [
      {'id': 'da1', 'title': 'Cyclone Alert: Bay of Bengal', 'body': 'IMD warns of cyclonic storm. Coastal areas on high alert. Fishing suspended.', 'type': 'critical', 'source': 'IMD / Govt. of India', 'timestamp': DateTime.now().subtract(const Duration(minutes: 12)).toIso8601String(), 'isRead': false},
      {'id': 'da2', 'title': 'Heavy Rainfall Warning', 'body': 'Red alert issued. 150mm+ rainfall expected in 24 hours. Avoid low-lying areas.', 'type': 'warning', 'source': 'Chennai Corporation', 'timestamp': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(), 'isRead': false},
      {'id': 'da3', 'title': 'NDRF Teams Deployed', 'body': '4 NDRF teams deployed across North Chennai. Rescue operations ready.', 'type': 'info', 'source': 'NDRF HQ', 'timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'isRead': true},
    ];
    _box.put('alerts', defaults);
    return defaults;
  }

  // ── USER REQUESTS / SOS (users → admin/responders) ────────────────────────

  List<Map<String, dynamic>> getRequests() {
    final saved = _box.get('user_requests');
    if (saved == null) return _defaultRequests();
    return (saved as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void submitRequest({
    required String userId,
    required String userName,
    required String type,
    required String priority,
    required String description,
    required String location,
    bool isSos = false,
    String? contactNumber,
  }) {
    final requests = getRequests();
    requests.insert(0, {
      'id': 'req_${DateTime.now().millisecondsSinceEpoch}',
      'userId': userId,
      'userName': userName,
      'type': type,
      'priority': priority,
      'status': 'pending',
      'description': description,
      'location': location,
      'isSos': isSos,
      'contactNumber': contactNumber,
      'timeAgo': 'Just now',
      'timestamp': DateTime.now().toIso8601String(),
    });
    _box.put('user_requests', requests);
  }

  void updateRequestStatus(String id, String status) {
    final requests = getRequests();
    final idx = requests.indexWhere((r) => r['id'] == id);
    if (idx != -1) {
      requests[idx]['status'] = status;
      _box.put('user_requests', requests);
    }
  }

  List<Map<String, dynamic>> _defaultRequests() {
    final defaults = [
      {'id': 'r1', 'userId': 'u1', 'userName': 'Priya Sharma', 'type': 'Boat Rescue', 'priority': 'critical', 'status': 'pending', 'description': 'Family of 4 stranded on rooftop. Water rising fast.', 'location': '13.0821, 80.2707', 'isSos': true, 'timeAgo': '5m ago', 'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String()},
      {'id': 'r2', 'userId': 'u2', 'userName': 'Ravi Kumar', 'type': 'Medical Aid', 'priority': 'critical', 'status': 'in_progress', 'description': 'Elderly woman with chest pain, no ambulance access.', 'location': '13.0950, 80.2850', 'isSos': true, 'timeAgo': '18m ago', 'timestamp': DateTime.now().subtract(const Duration(minutes: 18)).toIso8601String()},
      {'id': 'r3', 'userId': 'u3', 'userName': 'Meena Devi', 'type': 'Food', 'priority': 'high', 'status': 'pending', 'description': 'Community of 30 without food for 2 days.', 'location': '13.0600, 80.2500', 'isSos': false, 'timeAgo': '1h ago', 'timestamp': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()},
      {'id': 'r4', 'userId': 'u4', 'userName': 'Arjun Nair', 'type': 'Water', 'priority': 'high', 'status': 'in_progress', 'description': 'Flood contamination — clean water needed urgently.', 'location': '13.0700, 80.2600', 'isSos': false, 'timeAgo': '2h ago', 'timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String()},
      {'id': 'r5', 'userId': 'u5', 'userName': 'Lakshmi Raj', 'type': 'Shelter', 'priority': 'medium', 'status': 'resolved', 'description': 'Single mother with 2 kids needs shelter.', 'location': '13.0400, 80.2300', 'isSos': false, 'timeAgo': '6h ago', 'timestamp': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String()},
      {'id': 'r6', 'userId': 'u6', 'userName': 'Suresh Babu', 'type': 'Helicopter Rescue', 'priority': 'critical', 'status': 'pending', 'description': 'Injured person unable to walk, road blocked.', 'location': '13.0300, 80.2100', 'isSos': true, 'timeAgo': '30m ago', 'timestamp': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String()},
    ];
    _box.put('user_requests', defaults);
    return defaults;
  }

  // ── RESPONDERS (admin manages, all read) ──────────────────────────────────

  List<Map<String, dynamic>> getResponders() {
    final saved = _box.get('responders');
    if (saved == null) return _defaultResponders();
    return (saved as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void saveResponders(List<Map<String, dynamic>> responders) {
    _box.put('responders', responders);
  }

  List<Map<String, dynamic>> _defaultResponders() {
    final defaults = [
      {'id': 'resp1', 'name': 'Dr. Senthil Kumar', 'role': 'Hospital', 'phone': '044-25305000', 'location': 'Park Town', 'isAvailable': true, 'specialization': 'Emergency Medicine'},
      {'id': 'resp2', 'name': 'Capt. Ramesh Pillai', 'role': 'Rescuer', 'phone': '9876543210', 'location': 'Marina Beach', 'isAvailable': true, 'specialization': 'Water Rescue'},
      {'id': 'resp3', 'name': 'Hotel Saravana Bhavan', 'role': 'Hospitality Provider', 'phone': '044-28551234', 'location': 'T Nagar', 'isAvailable': true, 'specialization': 'Food & Shelter'},
      {'id': 'resp4', 'name': 'Rajan (Boatman)', 'role': 'Boat Operator', 'phone': '9988776655', 'location': 'Adyar River', 'isAvailable': false, 'specialization': 'Flood Rescue'},
      {'id': 'resp5', 'name': 'Anna Canteen Unit 3', 'role': 'Food Provider', 'phone': '1800-599-0019', 'location': 'Egmore', 'isAvailable': true, 'specialization': 'Mass Catering'},
      {'id': 'resp6', 'name': 'Lt. Col. Mohan Das', 'role': 'Military', 'phone': '044-22341234', 'location': 'Fort St. George', 'isAvailable': true, 'specialization': 'Disaster Relief'},
    ];
    _box.put('responders', defaults);
    return defaults;
  }

  // ── SOS MESSAGES (from mesh or user) ─────────────────────────────────────

  List<Map<String, dynamic>> getSosMessages() {
    final saved = _box.get('sos_messages');
    if (saved == null) return [];
    return (saved as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void submitSos({
    required String userId,
    required String userName,
    required String message,
    required String location,
    String source = 'app', // 'app' or 'mesh'
  }) {
    final sos = getSosMessages();
    sos.insert(0, {
      'id': 'sos_${DateTime.now().millisecondsSinceEpoch}',
      'userId': userId,
      'userName': userName,
      'message': message,
      'location': location,
      'source': source,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'active',
    });
    _box.put('sos_messages', sos);

    // Also add as a request so admin sees it in requests tab
    submitRequest(
      userId: userId,
      userName: userName,
      type: 'SOS',
      priority: 'critical',
      description: message,
      location: location,
      isSos: true,
    );
  }
}