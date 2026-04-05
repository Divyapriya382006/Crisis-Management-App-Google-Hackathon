// lib/features/map/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crisis_response_app/core/theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String _filter = 'all';
  int? _selectedIndex;

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d]'), ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openMaps(String coords, String name) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$coords';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  final List<_Place> _places = const [
    _Place('Rajiv Gandhi Govt. Hospital', 'hospital', '13.0865, 80.2784', 'Park Town, Chennai', '044-25305000', true, null),
    _Place('Government Stanley Hospital', 'hospital', '13.0943, 80.2773', 'Old Jail Road, Chennai', '044-25281361', true, null),
    _Place('Nehru Indoor Stadium', 'shelter', '13.0844, 80.2717', 'ICF, Chennai', null, true, 2000),
    _Place('YMCA Grounds Nandanam', 'shelter', '13.0274, 80.2337', 'Nandanam, Chennai', null, true, 500),
    _Place('DRJ Convention Centre', 'safe_building', '13.0765, 80.2620', 'Teynampet, Chennai', null, true, null),
    _Place('TIDEL Park', 'safe_building', '13.0078, 80.2441', 'Taramani, Chennai', null, true, null),
    _Place('NDRF Rescue Camp', 'rescue', '13.0600, 80.2500', 'Central Chennai', null, true, null),
    _Place('Apollo Hospitals', 'hospital', '13.0569, 80.2425', 'Greams Road, Chennai', '1860-500-1066', true, null),
  ];

  List<_Place> get _filtered =>
      _filter == 'all' ? _places : _places.where((p) => p.type == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter bar
        Container(
          color: AppColors.primary,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip('All', 'all', _filter == 'all', () => setState(() { _filter = 'all'; _selectedIndex = null; })),
                const SizedBox(width: 8),
                _FilterChip('🏥 Hospitals', 'hospital', _filter == 'hospital', () => setState(() { _filter = 'hospital'; _selectedIndex = null; })),
                const SizedBox(width: 8),
                _FilterChip('🏠 Shelters', 'shelter', _filter == 'shelter', () => setState(() { _filter = 'shelter'; _selectedIndex = null; })),
                const SizedBox(width: 8),
                _FilterChip('🏢 Safe Buildings', 'safe_building', _filter == 'safe_building', () => setState(() { _filter = 'safe_building'; _selectedIndex = null; })),
                const SizedBox(width: 8),
                _FilterChip('🚁 Rescue', 'rescue', _filter == 'rescue', () => setState(() { _filter = 'rescue'; _selectedIndex = null; })),
              ],
            ),
          ),
        ),

        // Map placeholder
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Stack(
            children: [
              // Grid background simulating a map
              CustomPaint(painter: _MapGridPainter(), size: Size.infinite),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, color: AppColors.accentGreen.withOpacity(0.4), size: 48),
                    const SizedBox(height: 8),
                    const Text('Interactive Map', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 16)),
                    const Text('Available on Android device', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 12),
                    // Show dots for each location
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _filtered.take(6).map((p) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: _typeColor(p.type),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Location list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final place = _filtered[i];
              final isSelected = _selectedIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = isSelected ? null : i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? _typeColor(place.type).withOpacity(0.1) : AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? _typeColor(place.type) : AppColors.divider,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _typeColor(place.type).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_typeIcon(place.type), color: _typeColor(place.type), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(place.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                                Text(place.address, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _typeColor(place.type).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              place.type.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(color: _typeColor(place.type), fontSize: 9, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 12),
                        const Divider(color: AppColors.divider, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppColors.textMuted, size: 13),
                            const SizedBox(width: 4),
                            Text(place.coords, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            if (place.capacity != null) ...[
                              const SizedBox(width: 12),
                              const Icon(Icons.people, color: AppColors.textMuted, size: 13),
                              const SizedBox(width: 4),
                              Text('Cap: ${place.capacity}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ],
                        ),
                        if (place.phone != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _callPhone(place.phone!),
                                  icon: const Icon(Icons.phone, size: 14),
                                  label: Text(place.phone!, style: const TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.accentGreen,
                                    side: const BorderSide(color: AppColors.accentGreen),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _openMaps(place.coords, place.name),
                                  icon: const Icon(Icons.navigation, size: 14),
                                  label: const Text('Navigate', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _typeColor(String type) => switch (type) {
    'hospital' => Colors.red,
    'shelter' => AppColors.accentGreen,
    'safe_building' => Colors.blue,
    'rescue' => AppColors.accentOrange,
    _ => AppColors.textSecondary,
  };

  IconData _typeIcon(String type) => switch (type) {
    'hospital' => Icons.local_hospital,
    'shelter' => Icons.home,
    'safe_building' => Icons.apartment,
    'rescue' => Icons.flight,
    _ => Icons.location_on,
  };
}

class _Place {
  final String name, type, coords, address;
  final String? phone;
  final bool isOpen;
  final int? capacity;
  const _Place(this.name, this.type, this.coords, this.address, this.phone, this.isOpen, this.capacity);
}

class _FilterChip extends StatelessWidget {
  final String label, value;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(this.label, this.value, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withOpacity(0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.accent : AppColors.divider, width: selected ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(color: selected ? AppColors.accent : AppColors.textSecondary, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, fontSize: 12)),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A2F4E).withOpacity(0.5)
      ..strokeWidth = 0.5;
    const spacing = 30.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}