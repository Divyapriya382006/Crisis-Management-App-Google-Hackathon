// lib/features/emergency/screens/emergency_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:crisis_response_app/core/services/shared_data_service.dart';
import 'package:crisis_response_app/core/theme/app_theme.dart';
import 'package:crisis_response_app/features/emergency/screens/emergency_situations_screen.dart';

class EmergencyDetailScreen extends StatelessWidget {
  final String type;
  const EmergencyDetailScreen({super.key, required this.type});

  EmergencyType get _emergency =>
      emergencyTypes.firstWhere((e) => e.id == type, orElse: () => emergencyTypes.first);

  @override
  Widget build(BuildContext context) {
    final e = _emergency;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(e.label),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, size: 22),
            onPressed: () => Share.share(
              '⚠️ EMERGENCY ALERT: ${e.label}\n\nPriority: ${e.priority.toUpperCase()}\n\nDescription: ${e.description}\n\nImmediate Actions:\n${e.actions.join('\n')}',
            ),
            tooltip: 'Share Emergency Details',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [e.color.withOpacity(0.2), AppColors.card],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: e.color.withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  Icon(e.icon, color: e.color, size: 56),
                  const SizedBox(height: 12),
                  Text(e.label, style: TextStyle(color: e.color, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(e.description, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Priority & status
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _InfoChip(label: 'Priority: ${e.priority.toUpperCase()}', color: _priorityColor(e.priority)),
                _InfoChip(label: 'ACTIVE MONITORING', color: AppColors.safe),
                _InfoChip(label: 'VERIFIED RESOURCE', color: AppColors.accent),
              ],
            ),

            const SizedBox(height: 28),

            // Immediate Actions
            const Text('IMMEDIATE ACTIONS', style: AppTextStyles.sectionHeader),
            const SizedBox(height: 12),

            ...e.actions.map((action) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ActionButton(label: action, color: e.color),
            )),

            const SizedBox(height: 24),

            // Safety Guidelines
            const Text('SAFETY GUIDELINES', style: AppTextStyles.sectionHeader),
            const SizedBox(height: 12),
            ..._guidelines(type).map((g) => _GuidelineItem(text: g)),

            const SizedBox(height: 24),

            // Request Help CTA
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/home/request-help'),
                icon: const Icon(Icons.sos, size: 22),
                label: const Text('REQUEST EMERGENCY ASSISTANCE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(String p) => switch (p) {
    'critical' => AppColors.critical,
    'high' => AppColors.high,
    'medium' => AppColors.medium,
    _ => AppColors.low,
  };

  List<String> _guidelines(String t) => switch (t) {
    'flood' => ['Move to highest available ground immediately', 'Avoid walking through moving water', 'Stay away from drains, channels, streams', 'Disconnect electrical appliances', 'Store drinking water in clean containers'],
    'earthquake' => ['DROP to hands and knees, take COVER under desk/table, HOLD ON', 'Stay away from windows and heavy furniture', 'Do not run outside during shaking', 'After shaking: check for injuries, expect aftershocks', 'Do not use lifts/elevators'],
    'tsunami' => ['If ground shakes near coast: move inland immediately', 'Do not wait for official warning', 'Move to elevation of 30m or more', 'Stay away from beach until officials confirm it is safe', 'Tsunamis can come in multiple waves hours apart'],
    'cyclone' => ['Stay indoors in strongest part of building', 'Close all windows and doors, board up if possible', 'Store water and emergency supplies', 'Avoid candles — use torches', 'After the eye passes, the storm is not over'],
    'bomb' => ['Do not touch or move any suspicious object', 'Evacuate the area calmly and quickly', 'Keep clear of the area by at least 300m', 'Do not use mobile phones near the device', 'Call 100 immediately from a safe distance'],
    _ => ['Stay calm and assess the situation', 'Call emergency services immediately', 'Follow instructions from authorities', 'Help others if it is safe to do so', 'Keep your phone charged and accessible'],
  };
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  const _ActionButton({required this.label, required this.color});

  Future<void> _handleAction(BuildContext context, String action) async {
    final phoneNum = RegExp(r'\(\d+\)').firstMatch(action)?.group(0)?.replaceAll(RegExp(r'[()]'), '');
    if (phoneNum != null) {
      final uri = Uri(scheme: 'tel', path: phoneNum);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } else {
      // Functional: Submit real request if it's a rescue/aid action
      final lowAction = action.toLowerCase();
      if (lowAction.contains('rescue') || lowAction.contains('report') || lowAction.contains('medical') || lowAction.contains('hotline')) {
         SharedDataService.instance.submitRequest(
          userId: 'user-001',
          userName: 'Citizen',
          type: action,
          priority: 'critical',
          description: 'Automatic request triggered from ${label} guidelines.',
          location: 'Auto-detected',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 Emergency Request Submitted to Responders!'),
            backgroundColor: AppColors.critical,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guidance Received: $action'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.primaryLight,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleAction(context, label),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_forward, color: color, size: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label, 
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }
}

class _GuidelineItem extends StatelessWidget {
  final String text;
  const _GuidelineItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check_circle_outline, color: AppColors.accentGreen, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5))),
        ],
      ),
    );
  }
}
