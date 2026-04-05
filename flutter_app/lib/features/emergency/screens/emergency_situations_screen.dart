// lib/features/emergency/screens/emergency_situations_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crisis_response_app/core/theme/app_theme.dart';

class EmergencyType {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String priority;
  final String description;
  final List<String> actions;

  const EmergencyType({
    required this.id, required this.label, required this.icon,
    required this.color, required this.priority, required this.description,
    required this.actions,
  });
}

const List<EmergencyType> emergencyTypes = [
  EmergencyType(id: 'flood', label: 'Flood', icon: Icons.water, color: Color(0xFF1E90FF), priority: 'critical',
    description: 'Rising water levels — evacuate to higher ground immediately.',
    actions: ['Request Boat Rescue', 'Find Shelter', 'Call 1078']),
  EmergencyType(id: 'earthquake', label: 'Earthquake', icon: Icons.terrain, color: Color(0xFFD2691E), priority: 'critical',
    description: 'Drop, cover, and hold on. Move away from buildings after shaking stops.',
    actions: ['Find Safe Zone', 'Structural Report', 'Medical Aid']),
  EmergencyType(id: 'tsunami', label: 'Tsunami', icon: Icons.waves, color: Color(0xFF006994), priority: 'critical',
    description: 'Move inland and to high ground immediately. Do not wait for official warning.',
    actions: ['Evacuation Route', 'High Ground Map', 'Call Coastguard']),
  EmergencyType(id: 'cyclone', label: 'Cyclone', icon: Icons.cyclone, color: Color(0xFF8A2BE2), priority: 'high',
    description: 'Seek shelter in a strong building. Stay away from windows.',
    actions: ['Find Shelter', 'Wind Speed', 'Evacuation Zones']),
  EmergencyType(id: 'protest', label: 'Civil Unrest', icon: Icons.groups, color: Color(0xFFFF6B35), priority: 'high',
    description: 'Avoid affected areas. Stay indoors and away from crowds.',
    actions: ['Safe Routes', 'Area Alerts', 'Report Incident']),
  EmergencyType(id: 'war', label: 'Armed Conflict', icon: Icons.security, color: Color(0xFFDC143C), priority: 'critical',
    description: 'Move to designated safe zones. Follow official guidance only.',
    actions: ['Bunker Locations', 'Evacuation Corridors', 'UN Hotline']),
  EmergencyType(id: 'theft', label: 'Theft / Robbery', icon: Icons.no_backpack, color: Color(0xFFFF8C00), priority: 'medium',
    description: 'Do not resist. Note descriptions and call police immediately.',
    actions: ['Call Police (100)', 'Report Online', 'Nearest Station']),
  EmergencyType(id: 'abduction', label: 'Abduction', icon: Icons.person_off, color: Color(0xFFFF2D55), priority: 'critical',
    description: 'Call 100 immediately. Provide last known location.',
    actions: ['Call Police', 'Child Helpline (1098)', 'Track & Report']),
  EmergencyType(id: 'abuse', label: 'Domestic Abuse', icon: Icons.family_restroom, color: Color(0xFFDA70D6), priority: 'high',
    description: 'You are not alone. Safe houses and support are available.',
    actions: ["Women's Helpline (1091)", 'Nearest Shelter', 'Legal Aid']),
  EmergencyType(id: 'womens_safety', label: "Women's Safety", icon: Icons.woman, color: Color(0xFFFF69B4), priority: 'high',
    description: 'Share live location. Panic button sends alert to trusted contacts.',
    actions: ['Panic Alert', 'Share Location', 'Helpline (1091)']),
  EmergencyType(id: 'bomb', label: 'Bomb / Explosive', icon: Icons.warning_amber, color: Color(0xFFFF0000), priority: 'critical',
    description: 'Evacuate immediately. Do not touch suspicious objects. Call 100.',
    actions: ['Evacuate Area', 'Call Bomb Squad', 'Cordon Zone']),
  EmergencyType(id: 'fire', label: 'Fire / Explosion', icon: Icons.local_fire_department, color: Color(0xFFFF4500), priority: 'critical',
    description: 'Activate alarm, evacuate, call 101. Do not use lifts.',
    actions: ['Call Fire (101)', 'Evacuation Map', 'First Aid']),
    EmergencyType(
  id: 'police_rescue',
  label: 'Police Rescue',
  icon: Icons.local_police,
  color: Color(0xFF4169E1),
  priority: 'critical',
  description: 'Request immediate police assistance. Stay calm and share your location.',
  actions: ['Call Police (100)', 'Share Location', 'Nearest Station'],
),
];

class EmergencySituationsScreen extends StatefulWidget {
  const EmergencySituationsScreen({super.key});

  @override
  State<EmergencySituationsScreen> createState() => _EmergencySituationsScreenState();
}

class _EmergencySituationsScreenState extends State<EmergencySituationsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? emergencyTypes
        : emergencyTypes.where((e) => e.priority == _filter).toList();

    return Column(
      children: [
        // Filter chips
        Container(
          color: AppColors.primary,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'All', value: 'all', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                const SizedBox(width: 8),
                _FilterChip(label: '🔴 Critical', value: 'critical', selected: _filter == 'critical', onTap: () => setState(() => _filter = 'critical'), color: AppColors.critical),
                const SizedBox(width: 8),
                _FilterChip(label: '🟠 High', value: 'high', selected: _filter == 'high', onTap: () => setState(() => _filter = 'high'), color: AppColors.high),
                const SizedBox(width: 8),
                _FilterChip(label: '🟡 Medium', value: 'medium', selected: _filter == 'medium', onTap: () => setState(() => _filter = 'medium'), color: AppColors.medium),
              ],
            ),
          ),
        ),

        // Grid of emergency types
        Expanded(
          child: RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async => await Future.delayed(const Duration(milliseconds: 500)),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.35,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, i) => _EmergencyCard(
                type: filtered[i],
                onTap: () => context.go('/home/emergency/${filtered[i].id}'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  final EmergencyType type;
  final VoidCallback onTap;
  const _EmergencyCard({required this.type, required this.onTap});

  Color get _priorityColor => switch (type.priority) {
    'critical' => AppColors.critical,
    'high' => AppColors.high,
    'medium' => AppColors.medium,
    _ => AppColors.low,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: type.color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: type.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(type.icon, color: type.color, size: 28),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _priorityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _priorityColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    type.priority.toUpperCase(),
                    style: TextStyle(color: _priorityColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              type.label, 
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            Expanded(
              child: Text(
                type.description,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: type.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'View Actions →',
                textAlign: TextAlign.center,
                style: TextStyle(color: type.color, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
