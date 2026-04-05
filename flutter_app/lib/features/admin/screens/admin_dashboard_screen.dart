// lib/features/admin/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crisis_response_app/core/constants/app_constants.dart';
import 'package:crisis_response_app/core/theme/app_theme.dart';
import 'package:crisis_response_app/features/notifications/screens/notifications_screen.dart';
import 'package:crisis_response_app/features/statistics/screens/statistics_screen.dart';
import 'package:crisis_response_app/core/services/shared_data_service.dart';

class _UserRequest {
  final String id;
  final String userName;
  final String userId;
  final String type;
  final String priority;
  String status;
  final String description;
  final String location;
  final String timeAgo;
  final bool isSos;
  _UserRequest({required this.id, required this.userName, required this.userId, required this.type, required this.priority, required this.status, required this.description, required this.location, required this.timeAgo, this.isSos = false});
}

class _ResponderModel {
  final String id;
  String name, role, phone, location;
  bool isAvailable;
  String? specialization;
  _ResponderModel({required this.id, required this.name, required this.role, required this.phone, required this.location, required this.isAvailable, this.specialization});
}

class _AppUser {
  final String id, name, email;
  final int requestCount;
  final String lastSeen;
  final bool hasSos;
  const _AppUser({required this.id, required this.name, required this.email, required this.requestCount, required this.lastSeen, required this.hasSos});
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _storage = const FlutterSecureStorage();

  List<_UserRequest> _requests = [];
  List<_AppUser> _users = [];
  List<_ResponderModel> _responders = [];

  // late Box _box;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadData();
  }

  void _loadData() {
    final rawRequests = SharedDataService.instance.getRequests();
    _requests = rawRequests.map((e) => _UserRequest(
      id: e['id'], userName: e['userName'] ?? 'Unknown',
      userId: e['userId'] ?? '', type: e['type'],
      priority: e['priority'], status: e['status'],
      description: e['description'], location: e['location'],
      timeAgo: _timeAgo(e['timestamp']),
      isSos: e['isSos'] ?? false,
    )).toList();

    final rawResponders = SharedDataService.instance.getResponders();
    _responders = rawResponders.map((e) => _ResponderModel(
      id: e['id'], name: e['name'], role: e['role'],
      phone: e['phone'], location: e['location'],
      isAvailable: e['isAvailable'] ?? true,
      specialization: e['specialization'],
    )).toList();

    // Build users from requests (deduplicated)
    final seen = <String>{};
    _users = [];
    for (final r in _requests) {
      if (!seen.contains(r.userId)) {
        seen.add(r.userId);
        _users.add(_AppUser(
          id: r.userId,
          name: r.userName,
          email: '${r.userName.toLowerCase().replaceAll(' ', '')}@app.com',
          requestCount: _requests.where((req) => req.userId == r.userId).length,
          lastSeen: r.timeAgo,
          hasSos: _requests.any((req) => req.userId == r.userId && req.isSos),
        ));
      }
    }

    if (mounted) setState(() {});
  }

  String _timeAgo(String? isoString) {
    if (isoString == null) return 'Recently';
    try {
      final dt = DateTime.parse(isoString);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Recently';
    }
  }

  // void _saveResponders() {
  //   _box.put('responders', _responders.map((r) => {
  //     'id': r.id, 'name': r.name, 'role': r.role,
  //     'phone': r.phone, 'location': r.location,
  //     'isAvailable': r.isAvailable, 'specialization': r.specialization,
  //   }).toList());
  // }

  // void _saveRequests() {
  //   _box.put('admin_requests', _requests.map((r) => {
  //     'id': r.id, 'userName': r.userName, 'userId': r.userId,
  //     'type': r.type, 'priority': r.priority, 'status': r.status,
  //     'description': r.description, 'location': r.location,
  //     'timeAgo': r.timeAgo, 'isSos': r.isSos,
  //   }).toList());
  // }

  // void _saveUsers() {
  //   _box.put('admin_users', _users.map((u) => {
  //     'id': u.id, 'name': u.name, 'email': u.email,
  //     'requestCount': u.requestCount, 'lastSeen': u.lastSeen,
  //     'hasSos': u.hasSos,
  //   }).toList());
  // }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await _storage.deleteAll();
    if (mounted) context.go(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.admin_panel_settings, color: AppColors.accent, size: 20),
          SizedBox(width: 8),
          Text('Admin Dashboard'),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: () => setState(() {})),
          IconButton(icon: const Icon(Icons.logout, size: 20), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard, size: 16), text: 'Overview'),
            Tab(icon: Icon(Icons.list_alt, size: 16), text: 'Requests'),
            Tab(icon: Icon(Icons.people, size: 16), text: 'Users'),
            Tab(icon: Icon(Icons.groups, size: 16), text: 'Responders'),
            Tab(icon: Icon(Icons.campaign, size: 16), text: 'Publish'),
            Tab(icon: Icon(Icons.notifications, size: 16), text: 'Alerts'),
            Tab(icon: Icon(Icons.bar_chart, size: 16), text: 'Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(requests: _requests, users: _users, responders: _responders),
          _RequestsTab(requests: _requests, responders: _responders, onStatusChange: (id, status) {
            SharedDataService.instance.updateRequestStatus(id, status);
            _loadData();
          }),
          _UsersTab(users: _users, requests: _requests),
          _RespondersTab(
            responders: _responders,
            onAdd: (r) {
              _responders.add(r);
              SharedDataService.instance.saveResponders(_responders.map((r) => {'id': r.id, 'name': r.name, 'role': r.role, 'phone': r.phone, 'location': r.location, 'isAvailable': r.isAvailable, 'specialization': r.specialization}).toList());
              setState(() {});
            },
            onDelete: (id) {
              _responders.removeWhere((r) => r.id == id);
              SharedDataService.instance.saveResponders(_responders.map((r) => {'id': r.id, 'name': r.name, 'role': r.role, 'phone': r.phone, 'location': r.location, 'isAvailable': r.isAvailable, 'specialization': r.specialization}).toList());
              setState(() {});
            },
            onToggle: (id) {
              final r = _responders.firstWhere((r) => r.id == id);
              r.isAvailable = !r.isAvailable;
              SharedDataService.instance.saveResponders(_responders.map((r) => {'id': r.id, 'name': r.name, 'role': r.role, 'phone': r.phone, 'location': r.location, 'isAvailable': r.isAvailable, 'specialization': r.specialization}).toList());
              setState(() {});
            },
          ),
          const _PublishTab(),
          const NotificationsScreen(),
          const StatisticsScreen(),
        ],
      ),
    );
  }
}

// ── OVERVIEW TAB ──────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final List<_UserRequest> requests;
  final List<_AppUser> users;
  final List<_ResponderModel> responders;
  const _OverviewTab({required this.requests, required this.users, required this.responders});

  @override
  Widget build(BuildContext context) {
    final critical = requests.where((r) => r.priority == 'critical' && r.status == 'pending').length;
    final pending = requests.where((r) => r.status == 'pending').length;
    final inProgress = requests.where((r) => r.status == 'in_progress').length;
    final resolved = requests.where((r) => r.status == 'resolved').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (critical > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.critical.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.critical.withOpacity(0.5))),
              child: Row(children: [
                const Icon(Icons.crisis_alert, color: AppColors.critical, size: 18),
                const SizedBox(width: 8),
                Text('$critical CRITICAL requests need immediate attention', style: const TextStyle(color: AppColors.critical, fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
          const _SLabel('OVERVIEW'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MStat('Total', '${requests.length}', Icons.inbox, AppColors.textSecondary)),
            const SizedBox(width: 8),
            Expanded(child: _MStat('Pending', '$pending', Icons.pending_actions, AppColors.accentYellow)),
            const SizedBox(width: 8),
            Expanded(child: _MStat('Active', '$inProgress', Icons.sync, AppColors.accentGreen)),
            const SizedBox(width: 8),
            Expanded(child: _MStat('Done', '$resolved', Icons.check_circle, AppColors.safe)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _MStat('Users', '${users.length}', Icons.people, AppColors.accent)),
            const SizedBox(width: 8),
            Expanded(child: _MStat('SOS', '${requests.where((r) => r.isSos).length}', Icons.sos, AppColors.critical)),
            const SizedBox(width: 8),
            Expanded(child: _MStat('Available', '${responders.where((r) => r.isAvailable).length}', Icons.groups, AppColors.accentGreen)),
            const SizedBox(width: 8),
            Expanded(child: _MStat('Critical', '$critical', Icons.warning, AppColors.high)),
          ]),
          const SizedBox(height: 20),
          const _SLabel('RECENT SOS ALERTS'),
          const SizedBox(height: 10),
          ...requests.where((r) => r.isSos).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.critical.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.critical.withOpacity(0.4))),
              child: Row(children: [
                const Icon(Icons.sos, color: AppColors.critical, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.userName, style: const TextStyle(color: AppColors.critical, fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(r.description, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                Text(r.timeAgo, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ]),
            ),
          )),
          const SizedBox(height: 20),
          const _SLabel('REQUEST BREAKDOWN'),
          const SizedBox(height: 10),
          ...(() {
            final types = <String, int>{};
            for (final r in requests) types[r.type] = (types[r.type] ?? 0) + 1;
            return types.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(width: 110, child: Text(e.key, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis)),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: e.value / requests.length, backgroundColor: AppColors.surfaceLight, valueColor: const AlwaysStoppedAnimation(AppColors.accentGreen), minHeight: 8))),
                const SizedBox(width: 8),
                Text('${e.value}', style: const TextStyle(color: AppColors.accentGreen, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ));
          })(),
          const SizedBox(height: 20),
          const _SLabel('SYSTEM STATUS'),
          const SizedBox(height: 10),
          _SRow('API Server', 'Online', AppColors.safe),
          const SizedBox(height: 6),
          _SRow('Database', 'Online', AppColors.safe),
          const SizedBox(height: 6),
          _SRow('Firebase FCM', 'Connected', AppColors.safe),
          const SizedBox(height: 6),
          _SRow('BLE Mesh Bridge', 'Active', AppColors.accentGreen),
        ],
      ),
    );
  }
}

// ── REQUESTS TAB ──────────────────────────────────────────────────────────────
class _RequestsTab extends StatefulWidget {
  final List<_UserRequest> requests;
  final List<_ResponderModel> responders;
  final void Function(String id, String status) onStatusChange;
  const _RequestsTab({required this.requests, required this.responders, required this.onStatusChange});

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  String _statusFilter = 'all';
  String _priorityFilter = 'all';

  List<_UserRequest> get _filtered => widget.requests.where((r) {
    final s = _statusFilter == 'all' || r.status == _statusFilter;
    final p = _priorityFilter == 'all' || r.priority == _priorityFilter;
    return s && p;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: ['all', 'pending', 'accepted', 'in_progress', 'resolved'].map((s) {
              final c = s == 'pending' ? AppColors.accentYellow : s == 'accepted' ? AppColors.accent : s == 'in_progress' ? AppColors.accentGreen : s == 'resolved' ? AppColors.safe : AppColors.textSecondary;
              final lbl = s == 'in_progress' ? 'Active' : s == 'all' ? 'All' : s[0].toUpperCase() + s.substring(1);
              return Padding(padding: const EdgeInsets.only(right: 6), child: _FChip(lbl, _statusFilter == s, c, () => setState(() => _statusFilter = s)));
            }).toList()),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: ['all', 'critical', 'high', 'medium', 'low'].map((p) {
              final c = p == 'critical' ? AppColors.critical : p == 'high' ? AppColors.high : p == 'medium' ? AppColors.medium : p == 'low' ? AppColors.safe : AppColors.textSecondary;
              return Padding(padding: const EdgeInsets.only(right: 6), child: _FChip(p[0].toUpperCase() + p.substring(1), _priorityFilter == p, c, () => setState(() => _priorityFilter = p)));
            }).toList()),
          ),
        ]),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Row(children: [Text('${_filtered.length} requests', style: const TextStyle(color: AppColors.textMuted, fontSize: 12))])),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: _filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _ReqCard(request: _filtered[i], responders: widget.responders, onStatusChange: widget.onStatusChange),
        ),
      ),
    ]);
  }
}

class _ReqCard extends StatelessWidget {
  final _UserRequest request;
  final List<_ResponderModel> responders;
  final void Function(String, String) onStatusChange;
  const _ReqCard({required this.request, required this.responders, required this.onStatusChange});

  Color get _pc => switch (request.priority) { 'critical' => AppColors.critical, 'high' => AppColors.high, 'medium' => AppColors.medium, _ => AppColors.safe };
  Color get _sc => switch (request.status) { 'pending' => AppColors.accentYellow, 'accepted' => AppColors.accent, 'in_progress' => AppColors.accentGreen, 'resolved' => AppColors.safe, _ => AppColors.textMuted };

  void _assign(BuildContext context) {
    final avail = responders.where((r) => r.isAvailable).toList();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Assign Responder', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 320,
          child: avail.isEmpty
              ? const Text('No available responders', style: TextStyle(color: AppColors.textMuted))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: avail.length,
                  separatorBuilder: (_, __) => const Divider(color: AppColors.divider, height: 1),
                  itemBuilder: (ctx, i) {
                    final r = avail[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundColor: AppColors.accentGreen.withOpacity(0.15), child: Text(r.name[0], style: const TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.w700))),
                      title: Text(r.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('${r.role} · ${r.location}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      trailing: TextButton(
                        onPressed: () {
                          onStatusChange(request.id, 'in_progress');
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r.name} assigned!'), backgroundColor: AppColors.safe));
                        },
                        child: const Text('Assign', style: TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.w700)),
                      ),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _pc.withOpacity(0.4), width: request.isSos ? 1.5 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (request.isSos) ...[_Badge('SOS', AppColors.critical), const SizedBox(width: 5)],
          _Badge(request.priority.toUpperCase(), _pc),
          const SizedBox(width: 5),
          _Badge(request.status.replaceAll('_', ' ').toUpperCase(), _sc),
          const Spacer(),
          Text(request.timeAgo, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          CircleAvatar(radius: 14, backgroundColor: AppColors.accent.withOpacity(0.15), child: Text(request.userName[0], style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(request.userName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
            Text(request.type, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ])),
        ]),
        const SizedBox(height: 8),
        Text(request.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.location_on, color: AppColors.textMuted, size: 12),
          const SizedBox(width: 4),
          Text(request.location, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          if (request.status == 'pending') ...[
            Expanded(child: _Btn('Accept', AppColors.accentGreen, () {
              onStatusChange(request.id, 'accepted');
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request accepted'), backgroundColor: AppColors.safe));
            })),
            const SizedBox(width: 8),
          ],
          if (request.status != 'resolved') ...[
            Expanded(child: _Btn('Assign →', AppColors.accent, () => _assign(context))),
            const SizedBox(width: 8),
          ],
          Expanded(child: _Btn(
            request.status == 'resolved' ? 'Resolved ✓' : 'Resolve',
            request.status == 'resolved' ? AppColors.textMuted : AppColors.safe,
            request.status == 'resolved' ? null : () {
              onStatusChange(request.id, 'resolved');
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked resolved'), backgroundColor: AppColors.safe));
            },
          )),
        ]),
      ]),
    );
  }
}

// ── USERS TAB ─────────────────────────────────────────────────────────────────
class _UsersTab extends StatefulWidget {
  final List<_AppUser> users;
  final List<_UserRequest> requests;
  const _UsersTab({required this.users, required this.requests});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _filter = 'all';
  String _search = '';

  List<_AppUser> get _filtered => widget.users.where((u) {
    final ms = _search.isEmpty || u.name.toLowerCase().contains(_search.toLowerCase()) || u.email.toLowerCase().contains(_search.toLowerCase());
    final mf = _filter == 'all' || (_filter == 'sos' && u.hasSos) || (_filter == 'active' && u.requestCount > 0);
    return ms && mf;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          TextField(onChanged: (v) => setState(() => _search = v), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13), decoration: const InputDecoration(hintText: 'Search users...', prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 18), contentPadding: EdgeInsets.symmetric(vertical: 10))),
          const SizedBox(height: 8),
          Row(children: [
            _FChip('All', _filter == 'all', AppColors.textSecondary, () => setState(() => _filter = 'all')),
            const SizedBox(width: 8),
            _FChip('🆘 SOS', _filter == 'sos', AppColors.critical, () => setState(() => _filter = 'sos')),
            const SizedBox(width: 8),
            _FChip('Active', _filter == 'active', AppColors.accentGreen, () => setState(() => _filter = 'active')),
          ]),
        ]),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Row(children: [Text('${_filtered.length} users', style: const TextStyle(color: AppColors.textMuted, fontSize: 12))])),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: _filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final u = _filtered[i];
            return _UserCard(user: u, requests: widget.requests.where((r) => r.userId == u.id).toList());
          },
        ),
      ),
    ]);
  }
}

class _UserCard extends StatefulWidget {
  final _AppUser user;
  final List<_UserRequest> requests;
  const _UserCard({required this.user, required this.requests});

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: widget.user.hasSos ? AppColors.critical.withOpacity(0.4) : AppColors.divider)),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: (widget.user.hasSos ? AppColors.critical : AppColors.accent).withOpacity(0.15), child: Text(widget.user.name[0], style: TextStyle(color: widget.user.hasSos ? AppColors.critical : AppColors.accent, fontWeight: FontWeight.w700, fontSize: 14))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(widget.user.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                  if (widget.user.hasSos) ...[const SizedBox(width: 6), _Badge('SOS', AppColors.critical)],
                ]),
                Text(widget.user.email, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${widget.user.requestCount} req', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                Text(widget.user.lastSeen, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ]),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textMuted, size: 18),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(color: AppColors.divider, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: widget.requests.isEmpty
                ? const Text('No requests from this user', style: TextStyle(color: AppColors.textMuted, fontSize: 12))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('REQUESTS', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    ...widget.requests.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: r.priority == 'critical' ? AppColors.critical : r.priority == 'high' ? AppColors.high : AppColors.medium, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(r.type, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(4)), child: Text(r.status.replaceAll('_', ' '), style: const TextStyle(color: AppColors.textMuted, fontSize: 10))),
                        const SizedBox(width: 8),
                        Text(r.timeAgo, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      ]),
                    )),
                  ]),
          ),
        ],
      ]),
    );
  }
}

// ── RESPONDERS TAB ────────────────────────────────────────────────────────────
class _RespondersTab extends StatefulWidget {
  final List<_ResponderModel> responders;
  final void Function(_ResponderModel) onAdd;
  final void Function(String) onDelete;
  final void Function(String) onToggle;
  const _RespondersTab({required this.responders, required this.onAdd, required this.onDelete, required this.onToggle});

  @override
  State<_RespondersTab> createState() => _RespondersTabState();
}

class _RespondersTabState extends State<_RespondersTab> {
  String _roleFilter = 'all';
  static const _roles = ['all', 'Hospital', 'Rescuer', 'Hospitality Provider', 'Boat Operator', 'Food Provider', 'Military'];

  List<_ResponderModel> get _filtered => _roleFilter == 'all' ? widget.responders : widget.responders.where((r) => r.role == _roleFilter).toList();

  void _showAdd() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    String role = 'Rescuer';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Add Responder', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            _DField(nameCtrl, 'Name / Organization'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: role, isExpanded: true, dropdownColor: AppColors.card,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                items: _roles.skip(1).map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setD(() => role = v!),
              )),
            ),
            const SizedBox(height: 10),
            _DField(phoneCtrl, 'Phone Number'),
            const SizedBox(height: 10),
            _DField(locationCtrl, 'Location / Area'),
            const SizedBox(height: 10),
            _DField(specCtrl, 'Specialization (optional)'),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                widget.onAdd(_ResponderModel(id: 'r_${DateTime.now().millisecondsSinceEpoch}', name: nameCtrl.text.trim(), role: role, phone: phoneCtrl.text.trim(), location: locationCtrl.text.trim(), isAvailable: true, specialization: specCtrl.text.trim().isEmpty ? null : specCtrl.text.trim()));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Responder added'), backgroundColor: AppColors.safe));
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _roles.map((r) { final lbl = r == 'all' ? 'All' : r.split(' ').first; return Padding(padding: const EdgeInsets.only(right: 6), child: _FChip(lbl, _roleFilter == r, AppColors.accentGreen, () => setState(() => _roleFilter = r))); }).toList()))),
          const SizedBox(width: 8),
          ElevatedButton.icon(onPressed: _showAdd, icon: const Icon(Icons.add, size: 16), label: const Text('Add', style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
        ]),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Row(children: [
        Text('${_filtered.length} responders', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(width: 12),
        Text('${_filtered.where((r) => r.isAvailable).length} available', style: const TextStyle(color: AppColors.safe, fontSize: 12, fontWeight: FontWeight.w600)),
      ])),
      Expanded(child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _RespCard(responder: _filtered[i], onDelete: () { widget.onDelete(_filtered[i].id); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Responder removed'), backgroundColor: AppColors.critical)); }, onToggle: () => widget.onToggle(_filtered[i].id)),
      )),
    ]);
  }
}

class _RespCard extends StatelessWidget {
  final _ResponderModel responder;
  final VoidCallback onDelete, onToggle;
  const _RespCard({required this.responder, required this.onDelete, required this.onToggle});

  Color get _rc => switch (responder.role) { 'Hospital' => AppColors.critical, 'Rescuer' => AppColors.accent, 'Military' => AppColors.accentOrange, 'Boat Operator' => const Color(0xFF1E90FF), 'Food Provider' => AppColors.accentYellow, _ => AppColors.accentGreen };
  IconData get _ri => switch (responder.role) { 'Hospital' => Icons.local_hospital, 'Rescuer' => Icons.emergency, 'Military' => Icons.security, 'Boat Operator' => Icons.directions_boat, 'Food Provider' => Icons.fastfood, _ => Icons.home };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: responder.isAvailable ? _rc.withOpacity(0.3) : AppColors.divider)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _rc.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(_ri, color: _rc, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(responder.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13))),
            GestureDetector(onTap: onToggle, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: responder.isAvailable ? AppColors.safe.withOpacity(0.12) : AppColors.textMuted.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: responder.isAvailable ? AppColors.safe.withOpacity(0.4) : AppColors.divider)),
              child: Text(responder.isAvailable ? '● Available' : '○ Off Duty', style: TextStyle(color: responder.isAvailable ? AppColors.safe : AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
            )),
          ]),
          const SizedBox(height: 3),
          Text(responder.role, style: TextStyle(color: _rc, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.phone, color: AppColors.textMuted, size: 11),
            const SizedBox(width: 4),
            Text(responder.phone, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(width: 8),
            const Icon(Icons.location_on, color: AppColors.textMuted, size: 11),
            const SizedBox(width: 2),
            Expanded(child: Text(responder.location, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis)),
          ]),
          if (responder.specialization != null)
            Text(responder.specialization!, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontStyle: FontStyle.italic)),
        ])),
        IconButton(
          onPressed: () => showDialog(context: context, builder: (_) => AlertDialog(
            backgroundColor: AppColors.card,
            title: const Text('Remove Responder', style: TextStyle(color: AppColors.textPrimary)),
            content: Text('Remove ${responder.name}?', style: const TextStyle(color: AppColors.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
              TextButton(onPressed: () { Navigator.pop(context); onDelete(); }, child: const Text('Remove', style: TextStyle(color: AppColors.critical))),
            ],
          )),
          icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }
}

// ── PUBLISH TAB ───────────────────────────────────────────────────────────────
class _PublishTab extends StatefulWidget {
  const _PublishTab();

  @override
  State<_PublishTab> createState() => _PublishTabState();
}

class _PublishTabState extends State<_PublishTab> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _type = 'warning';
  bool _loading = false;
  List<Map<String, String>> _sent = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAlerts();
  }

  void _loadSavedAlerts() {
    final alerts = SharedDataService.instance.getAlerts();
    setState(() {
      _sent = alerts.map((a) => {
        'title': a['title'].toString(),
        'body': a['body'].toString(),
        'type': a['type'].toString(),
        'time': _timeAgo(a['timestamp'].toString()),
      }).toList();
    });
  }

  String _timeAgo(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Recently';
    }
  }

  Future<void> _publish() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in title and message'), backgroundColor: AppColors.accent),
      );
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    // Save to shared storage — all roles see this instantly
    SharedDataService.instance.publishAlert(
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      type: _type,
    );

    _loadSavedAlerts(); // Refresh the published list

    _titleCtrl.clear();
    _bodyCtrl.clear();
    setState(() => _loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Alert published — visible to all users and responders!'),
        backgroundColor: AppColors.safe,
      ),
    );
  }

  //   final saved = box.get('published_alerts');
  //   if (saved != null) {
  //     setState(() {
  //       _sent = (saved as List).map((e) => {
  //         'title': e['title'].toString(),
  //         'body': e['body'].toString(),
  //         'type': e['type'].toString(),
  //         'time': _timeAgo(e['time'].toString()),
  //       }).toList();
  //     });
  //   }
  // }

  // String _timeAgo(String isoString) {
  //   try {
  //     final dt = DateTime.parse(isoString);
  //     final diff = DateTime.now().difference(dt);
  //     if (diff.inMinutes < 1) return 'Just now';
  //     if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  //     if (diff.inHours < 24) return '${diff.inHours}h ago';
  //     return '${diff.inDays}d ago';
  //   } catch (_) {
  //     return isoString;
  //   }
  // }

  // Future<void> _publish() async {
  //   if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill in title and message'), backgroundColor: AppColors.accent));
  //     return;
  //   }
  //   setState(() => _loading = true);
  //   await Future.delayed(const Duration(milliseconds: 800));

    
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SLabel('PUBLISH ALERT'),
        const SizedBox(height: 4),
        const Text('Send push notification to all users', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 16),
        const Text('Alert Type', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: ['critical', 'warning', 'info'].map((t) {
          final c = t == 'critical' ? AppColors.critical : t == 'warning' ? AppColors.high : AppColors.accentGreen;
          return Expanded(child: Padding(
            padding: EdgeInsets.only(right: t != 'info' ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _type = t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: _type == t ? c.withOpacity(0.15) : AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _type == t ? c : AppColors.divider, width: _type == t ? 1.5 : 1)),
                child: Text(t.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(color: _type == t ? c : AppColors.textMuted, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
            ),
          ));
        }).toList()),
        const SizedBox(height: 16),
        TextField(controller: _titleCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(labelText: 'Alert Title', prefixIcon: Icon(Icons.title, color: AppColors.textMuted))),
        const SizedBox(height: 12),
        TextField(controller: _bodyCtrl, maxLines: 4, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(labelText: 'Alert Message', alignLabelWithHint: true)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _publish,
            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.campaign, size: 20),
            label: const Text('PUBLISH TO ALL USERS', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ),
        if (_sent.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SLabel('PUBLISHED ALERTS'),
          const SizedBox(height: 10),
          ..._sent.map((p) {
            final c = p['type'] == 'critical' ? AppColors.critical : p['type'] == 'warning' ? AppColors.high : AppColors.accentGreen;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.3))),
              child: Row(children: [
                _Badge(p['type']!.toUpperCase(), c),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['title']!, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(p['body']!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                Text(p['time']!, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ]),
            );
          }),
        ],
      ]),
    );
  }
}

// ── SHARED WIDGETS ────────────────────────────────────────────────────────────
class _SLabel extends StatelessWidget {
  final String text;
  const _SLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: AppTextStyles.sectionHeader);
}

class _MStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MStat(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: color, size: 12), const SizedBox(width: 4), Flexible(child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _SRow extends StatelessWidget {
  final String label, status;
  final Color color;
  const _SRow(this.label, this.status, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
      child: Row(children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _FChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FChip(this.label, this.selected, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: selected ? color.withOpacity(0.15) : AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? color : AppColors.divider, width: selected ? 1.5 : 1)),
        child: Text(label, style: TextStyle(color: selected ? color : AppColors.textSecondary, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, fontSize: 12)),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _Btn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: onTap == null ? AppColors.surfaceLight : color.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: onTap == null ? AppColors.divider : color.withOpacity(0.4))),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: onTap == null ? AppColors.textMuted : color, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }
}

class _DField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  const _DField(this.ctrl, this.hint);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(labelText: hint, labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
    );
  }
}