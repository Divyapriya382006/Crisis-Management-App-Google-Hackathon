// lib/features/notifications/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:crisis_response_app/core/theme/app_theme.dart';
import 'package:crisis_response_app/shared/models/models.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:crisis_response_app/core/services/shared_data_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _loading = true;
  Timer? _pollTimer;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    // Poll every 30 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchNotifications());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final alerts = SharedDataService.instance.getAlerts();
    if (mounted) {
      setState(() {
        _notifications = alerts.map((a) => NotificationModel(
          id: a['id'],
          title: a['title'],
          body: a['body'],
          type: a['type'],
          source: a['source'],
          timestamp: DateTime.parse(a['timestamp']),
          isRead: a['isRead'] ?? false,
        )).toList();
        _loading = false;
      });
    }
  }

  void _saveNotifications(List<NotificationModel> notifications, Box box) {
    box.put('notifications', notifications.map((n) => {
      'id': n.id,
      'title': n.title,
      'body': n.body,
      'type': n.type,
      'source': n.source,
      'timestamp': n.timestamp.toIso8601String(),
      'isRead': n.isRead,
    }).toList());
  }

  List<NotificationModel> get _filtered =>
      _filter == 'all' ? _notifications : _notifications.where((n) => n.type == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, size: 20),
            tooltip: 'Mark All Read',
            onPressed: () {
              SharedDataService.instance.markAllAlertsRead();
              _fetchNotifications();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, size: 20),
            tooltip: 'Clear All',
            onPressed: () {
              SharedDataService.instance.clearAllAlerts();
              _fetchNotifications();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
        // Filter bar
        Container(
          color: AppColors.primary,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'All', value: 'all', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                const SizedBox(width: 8),
                _FilterChip(label: '🔴 Critical', value: 'critical', selected: _filter == 'critical', onTap: () => setState(() => _filter = 'critical'), color: AppColors.critical),
                const SizedBox(width: 8),
                _FilterChip(label: '⚠️ Warning', value: 'warning', selected: _filter == 'warning', onTap: () => setState(() => _filter = 'warning'), color: AppColors.high),
                const SizedBox(width: 8),
                _FilterChip(label: 'ℹ️ Info', value: 'info', selected: _filter == 'info', onTap: () => setState(() => _filter = 'info'), color: AppColors.accentGreen),
              ],
            ),
          ),
        ),

        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
        else
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accent,
              onRefresh: _fetchNotifications,
              child: _filtered.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _NotificationCard(notification: _filtered[i]),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  const _NotificationCard({required this.notification});

  Color get _typeColor => switch (notification.type) {
    'critical' => AppColors.critical,
    'warning' => AppColors.high,
    'info' => AppColors.accentGreen,
    _ => AppColors.textSecondary,
  };

  IconData get _typeIcon => switch (notification.type) {
    'critical' => Icons.crisis_alert,
    'warning' => Icons.warning_amber,
    'info' => Icons.info_outline,
    _ => Icons.notifications_outlined,
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: notification.isRead ? AppColors.divider : _typeColor.withOpacity(0.4), width: notification.isRead ? 1 : 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _typeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_typeIcon, color: _typeColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(notification.type.toUpperCase(), style: TextStyle(color: _typeColor, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                    ),
                    if (!notification.isRead) ...[
                      const SizedBox(width: 8),
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(notification.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text(notification.body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.verified, color: AppColors.textMuted, size: 12),
                    const SizedBox(width: 4),
                    Text(notification.source, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, color: AppColors.textMuted, size: 12),
                    const SizedBox(width: 4),
                    Text(_timeAgo(notification.timestamp), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, color: AppColors.textMuted, size: 48),
          SizedBox(height: 12),
          Text('No alerts', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Pull down to refresh', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label, value;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  const _FilterChip({required this.label, required this.value, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : AppColors.divider, width: selected ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(color: selected ? c : AppColors.textSecondary, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
      ),
    );
  }
}

// Mock data fallback
final _mockNotifications = [
  NotificationModel(id: '1', title: 'Cyclone Alert: Bay of Bengal', body: 'IMD warns of cyclonic storm forming in Bay of Bengal. Coastal areas of Tamil Nadu on high alert. Fishing activities suspended.', type: 'critical', source: 'IMD / Govt. of India', timestamp: DateTime.now().subtract(const Duration(minutes: 12))),
  NotificationModel(id: '2', title: 'Heavy Rainfall Warning', body: 'Red alert issued for Chennai and surrounding districts. Expected 150mm+ rainfall in next 24 hours. Avoid low-lying areas.', type: 'warning', source: 'Chennai Corporation', timestamp: DateTime.now().subtract(const Duration(hours: 1))),
  NotificationModel(id: '3', title: 'NDRF Teams Deployed', body: '4 NDRF teams deployed across North Chennai in anticipation of flooding. Rescue operations ready.', type: 'info', source: 'NDRF HQ', timestamp: DateTime.now().subtract(const Duration(hours: 2)), isRead: true),
  NotificationModel(id: '4', title: 'Power Outage: North Chennai', body: 'Planned power shutdown in Perambur, Kolathur zones from 9AM–4PM for maintenance work.', type: 'warning', source: 'TANGEDCO', timestamp: DateTime.now().subtract(const Duration(hours: 5)), isRead: true),
  NotificationModel(id: '5', title: 'Blood Donation Camp', body: 'Emergency blood donation required at Rajiv Gandhi Govt. Hospital. All blood groups needed urgently.', type: 'info', source: 'RGGGH Chennai', timestamp: DateTime.now().subtract(const Duration(hours: 8)), isRead: true),
];

// Widget used in HomeScreen
class NotificationPreviewCard extends StatelessWidget {
  const NotificationPreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _mockNotifications.take(2).map((n) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _NotificationCard(notification: n),
      )).toList(),
    );
  }
}
