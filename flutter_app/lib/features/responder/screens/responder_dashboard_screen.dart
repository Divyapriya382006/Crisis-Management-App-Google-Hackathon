// lib/features/responder/screens/responder_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crisis_response_app/core/constants/app_constants.dart';
import 'package:crisis_response_app/core/theme/app_theme.dart';
import 'package:crisis_response_app/features/home/screens/home_screen.dart';
import 'package:crisis_response_app/features/notifications/screens/notifications_screen.dart';
import 'package:crisis_response_app/features/statistics/screens/statistics_screen.dart';
import 'package:crisis_response_app/features/map/screens/map_screen.dart';
import 'package:crisis_response_app/features/mesh/screens/mesh_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ResponderDashboardScreen extends StatefulWidget {
  const ResponderDashboardScreen({super.key});

  @override
  State<ResponderDashboardScreen> createState() =>
      _ResponderDashboardScreenState();
}

class _ResponderDashboardScreenState extends State<ResponderDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _storage = const FlutterSecureStorage();
  String _responderName = 'Responder';
  String _responderRole = 'Rescuer';

  // Mock assigned tasks for this responder
  final List<_Task> _myTasks = [
    _Task(id: 't1', userName: 'Priya Sharma', type: 'Boat Rescue', priority: 'critical', status: 'assigned', description: 'Family of 4 stranded on rooftop. Water rising fast.', location: '13.0821, 80.2707', timeAgo: '5m ago', isSos: true),
    _Task(id: 't2', userName: 'Ravi Kumar', type: 'Medical Aid', priority: 'critical', status: 'in_progress', description: 'Elderly woman with chest pain, no ambulance access.', location: '13.0950, 80.2850', timeAgo: '18m ago', isSos: true),
    _Task(id: 't3', userName: 'Vijay Mohan', type: 'Evacuation', priority: 'high', status: 'assigned', description: 'Entire street needs evacuation — flood rising.', location: '13.0650, 80.2550', timeAgo: '45m ago'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadUser();
  }

  Future<void> _loadUser() async {
    final name = await _storage.read(key: StorageKeys.userName);
    final role = await _storage.read(key: StorageKeys.userRole);
    if (mounted) setState(() {
      _responderName = name ?? 'Responder';
      _responderRole = role ?? 'Rescuer';
    });
  }

  Future<void> _logout() async {
    await _storage.deleteAll();
    if (mounted) context.go(RouteNames.login);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.emergency_share, color: AppColors.accentGreen, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RESPONDER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppColors.textPrimary)),
                Text(_responderName, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        actions: [
          // Role badge
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accentGreen.withOpacity(0.4)),
            ),
            child: Text(_responderRole, style: const TextStyle(color: AppColors.accentGreen, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          IconButton(icon: const Icon(Icons.logout, size: 20), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.task_alt, size: 16), text: 'My Tasks'),
            Tab(icon: Icon(Icons.home, size: 16), text: 'Home'),
            Tab(icon: Icon(Icons.notifications, size: 16), text: 'Alerts'),
            Tab(icon: Icon(Icons.bar_chart, size: 16), text: 'Stats'),
            Tab(icon: Icon(Icons.map, size: 16), text: 'Map'),
            Tab(icon: Icon(Icons.hub, size: 16), text: 'Mesh'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyTasksTab(tasks: _myTasks, onUpdate: (id, status) => setState(() {
            _myTasks.firstWhere((t) => t.id == id).status = status;
          })),
          const HomeScreen(),
          const NotificationsScreen(),
          const StatisticsScreen(),
          const MapScreen(),
          const MeshScreen(),
        ],
      ),
    );
  }
}

// ── My Tasks Tab ──────────────────────────────────────────────────────────────

class _Task {
  final String id;
  final String userName;
  final String type;
  final String priority;
  String status;
  final String description;
  final String location;
  final String timeAgo;
  final bool isSos;

  _Task({
    required this.id,
    required this.userName,
    required this.type,
    required this.priority,
    required this.status,
    required this.description,
    required this.location,
    required this.timeAgo,
    this.isSos = false,
  });
}

class _MyTasksTab extends StatefulWidget {
  final List<_Task> tasks;
  final void Function(String id, String status) onUpdate;
  const _MyTasksTab({required this.tasks, required this.onUpdate});

  @override
  State<_MyTasksTab> createState() => _MyTasksTabState();
}

class _MyTasksTabState extends State<_MyTasksTab> {
  String _filter = 'all';

  List<_Task> get _filtered => _filter == 'all'
      ? widget.tasks
      : widget.tasks.where((t) => t.status == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final pending = widget.tasks.where((t) => t.status == 'assigned').length;
    final active = widget.tasks.where((t) => t.status == 'in_progress').length;
    final done = widget.tasks.where((t) => t.status == 'completed').length;

    return Column(
      children: [
        // Summary strip
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _SummaryTile('Assigned', '$pending', AppColors.accentYellow)),
                  const SizedBox(width: 10),
                  Expanded(child: _SummaryTile('In Progress', '$active', AppColors.accentGreen)),
                  const SizedBox(width: 10),
                  Expanded(child: _SummaryTile('Completed', '$done', AppColors.safe)),
                ],
              ),
              const SizedBox(height: 12),
              // Status filter
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FChip('All', _filter == 'all', AppColors.textSecondary, () => setState(() => _filter = 'all')),
                    const SizedBox(width: 8),
                    _FChip('Assigned', _filter == 'assigned', AppColors.accentYellow, () => setState(() => _filter = 'assigned')),
                    const SizedBox(width: 8),
                    _FChip('In Progress', _filter == 'in_progress', AppColors.accentGreen, () => setState(() => _filter = 'in_progress')),
                    const SizedBox(width: 8),
                    _FChip('Completed', _filter == 'completed', AppColors.safe, () => setState(() => _filter = 'completed')),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (_filtered.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, color: AppColors.textMuted, size: 48),
                  SizedBox(height: 12),
                  Text('No tasks here', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 16)),
                  SizedBox(height: 6),
                  Text('New assignments from admin\nwill appear here.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _TaskCard(task: _filtered[i], onUpdate: widget.onUpdate),
            ),
          ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final _Task task;
  final void Function(String, String) onUpdate;
  const _TaskCard({required this.task, required this.onUpdate});

  Color get _pc => switch (task.priority) {
    'critical' => AppColors.critical,
    'high' => AppColors.high,
    'medium' => AppColors.medium,
    _ => AppColors.safe,
  };

  Color get _sc => switch (task.status) {
    'assigned' => AppColors.accentYellow,
    'in_progress' => AppColors.accentGreen,
    'completed' => AppColors.safe,
    _ => AppColors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.isSos ? AppColors.critical.withOpacity(0.5) : _pc.withOpacity(0.3),
          width: task.isSos ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top badges row
          Row(
            children: [
              if (task.isSos) ...[
                _Badge('🆘 SOS', AppColors.critical),
                const SizedBox(width: 6),
              ],
              _Badge(task.priority.toUpperCase(), _pc),
              const SizedBox(width: 6),
              _Badge(task.status.replaceAll('_', ' ').toUpperCase(), _sc),
              const Spacer(),
              Text(task.timeAgo, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),

          const SizedBox(height: 12),

          // Type + user
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _pc.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_taskIcon(task.type), color: _pc, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.type, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('Requested by ${task.userName}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Description
          Text(task.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),

          const SizedBox(height: 8),

          // Location
          GestureDetector(
            onTap: () async {
              final coords = task.location;
              final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$coords');
              if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: AppColors.accent, size: 13),
                  const SizedBox(width: 5),
                  Text(task.location, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  const Text('Tap to navigate →', style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              if (task.status == 'assigned') ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      onUpdate(task.id, 'in_progress');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Task started — marked In Progress'), backgroundColor: AppColors.accentGreen),
                      );
                    },
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Start Task', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (task.status == 'in_progress') ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      onUpdate(task.id, 'completed');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✓ Task completed!'), backgroundColor: AppColors.safe),
                      );
                    },
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Mark Complete', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.safe,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (task.status == 'completed')
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.safe.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.safe.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: AppColors.safe, size: 16),
                        SizedBox(width: 6),
                        Text('Completed ✓', style: TextStyle(color: AppColors.safe, fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              // SOS call button
              if (task.isSos && task.status != 'completed')
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri(scheme: 'tel', path: '112');
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                  icon: const Icon(Icons.phone, size: 14),
                  label: const Text('Call', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.critical,
                    side: const BorderSide(color: AppColors.critical),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _taskIcon(String type) {
    if (type.contains('Boat')) return Icons.directions_boat;
    if (type.contains('Medical')) return Icons.medical_services;
    if (type.contains('Evacuation')) return Icons.directions_run;
    if (type.contains('Helicopter')) return Icons.flight;
    if (type.contains('Food')) return Icons.fastfood;
    if (type.contains('Water')) return Icons.water_drop;
    return Icons.emergency;
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
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
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : AppColors.divider, width: selected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}