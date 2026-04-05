// lib/features/home/screens/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:crisis_response_app/core/theme/app_theme.dart';
import 'package:crisis_response_app/core/network/network_checker.dart';
import 'package:crisis_response_app/features/home/screens/home_screen.dart';
import 'package:crisis_response_app/features/emergency/screens/emergency_situations_screen.dart';
import 'package:crisis_response_app/features/map/screens/map_screen.dart';
import 'package:crisis_response_app/features/notifications/screens/notifications_screen.dart';
import 'package:crisis_response_app/features/statistics/screens/statistics_screen.dart';
import 'package:crisis_response_app/features/mesh/screens/mesh_screen.dart';
import 'package:crisis_response_app/features/mesh/widgets/mesh_status_banner.dart';
import 'package:crisis_response_app/features/mesh/services/mesh_service.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isOffline = false;

  final List<_TabItem> _tabs = const [
    _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    _TabItem(icon: Icons.warning_amber_outlined, activeIcon: Icons.warning_amber, label: 'Emergency'),
    _TabItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map'),
    _TabItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications, label: 'Alerts'),
    _TabItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Stats'),
    _TabItem(icon: Icons.hub_outlined, activeIcon: Icons.hub, label: 'Mesh'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    NetworkChecker.instance.onConnectivityChanged.listen((connected) {
      if (mounted) setState(() => _isOffline = !connected);
    });

    // Start BLE mesh in background
    try {
  MeshService.instance.start();
} catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Swipe left/right to change tabs
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -300 && _tabController.index < _tabs.length - 1) {
          _tabController.animateTo(_tabController.index + 1);
        } else if (details.primaryVelocity! > 300 && _tabController.index > 0) {
          _tabController.animateTo(_tabController.index - 1);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        // REPLACE the entire appBar: PreferredSize(...) block with this:
appBar: AppBar(
  title: Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.emergency, color: AppColors.accent, size: 18),
      ),
      const SizedBox(width: 10),
      const Text('CRISIS RESPONSE',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1)),
    ],
  ),
  actions: [
    Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Icon(
        _isOffline ? Icons.wifi_off : Icons.wifi,
        color: _isOffline ? AppColors.accentOrange : AppColors.safe,
        size: 18,
      ),
    ),
    IconButton(
      icon: const Icon(Icons.accessibility_new, size: 22),
      onPressed: () => _showAccessibilityToggle(context),
      tooltip: 'Accessibility',
    ),
  ],
  bottom: PreferredSize(
    preferredSize: Size.fromHeight(_isOffline ? 96 : 48),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isOffline)
          Container(
            width: double.infinity,
            color: AppColors.accentOrange,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text(
                  'OFFLINE MODE — Showing cached data',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          tabs: _tabs.map((t) => AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              final isSelected = _tabController.index == _tabs.indexOf(t);
              return Tab(
                height: 48,
                icon: Icon(isSelected ? t.activeIcon : t.icon, size: 20),
                text: t.label,
              );
            },
          )).toList(),
        ),
      ],
    ),
  ),
),
        body: Column(
          children: [
            // Mesh status banner — visible on all tabs
            MeshStatusBanner(
              onTap: () => _tabController.animateTo(5),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  HomeScreen(),
                  EmergencySituationsScreen(),
                  MapScreen(),
                  NotificationsScreen(),
                  StatisticsScreen(),
                  MeshScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccessibilityToggle(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _AccessibilitySheet(),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabItem({required this.icon, required this.activeIcon, required this.label});
}

class _AccessibilitySheet extends StatefulWidget {
  const _AccessibilitySheet();

  @override
  State<_AccessibilitySheet> createState() => _AccessibilitySheetState();
}

class _AccessibilitySheetState extends State<_AccessibilitySheet> {
  bool _tts = false;
  bool _stt = false;
  bool _largeText = false;
  bool _highContrast = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Accessibility', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Customize for your needs', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 20),
          _toggle('Text-to-Speech', 'Read alerts aloud', Icons.volume_up, _tts, (v) => setState(() => _tts = v)),
          _toggle('Speech-to-Text', 'Voice emergency input', Icons.mic, _stt, (v) => setState(() => _stt = v)),
          _toggle('Large UI Elements', 'Bigger buttons & text', Icons.text_fields, _largeText, (v) => setState(() => _largeText = v)),
          _toggle('High Contrast', 'Enhanced visibility', Icons.contrast, _highContrast, (v) => setState(() => _highContrast = v)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _toggle(String title, String sub, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 18),
      ),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.accent,
      ),
    );
  }
}
