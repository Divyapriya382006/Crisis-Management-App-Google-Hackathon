// lib/features/home/screens/request_help_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:crisis_response_app/core/theme/app_theme.dart';
import 'package:crisis_response_app/core/constants/app_constants.dart';
import 'package:crisis_response_app/core/services/shared_data_service.dart';

class _RequestType {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String priority;
  const _RequestType(this.id, this.label, this.icon, this.color, this.priority);
}

const _types = [
  _RequestType('food', 'Food', Icons.fastfood, Color(0xFFFFD166), 'medium'),
  _RequestType('water', 'Water', Icons.water_drop, Color(0xFF1E90FF), 'high'),
  _RequestType('electricity', 'Power / Electricity', Icons.electrical_services, Color(0xFFFFD166), 'medium'),
  _RequestType('medical', 'Medical Aid', Icons.medical_services, Color(0xFFFF6B6B), 'critical'),
  _RequestType('boat', 'Boat Rescue', Icons.directions_boat, Color(0xFF1E90FF), 'critical'),
  _RequestType('helicopter', 'Helicopter Rescue', Icons.flight, Color(0xFFFF6B35), 'critical'),
  _RequestType('shelter', 'Shelter', Icons.home, Color(0xFF2EC4B6), 'high'),
  _RequestType('evacuation', 'Evacuation Help', Icons.directions_run, Color(0xFFDA70D6), 'high'),
];

class RequestHelpScreen extends StatefulWidget {
  const RequestHelpScreen({super.key});

  @override
  State<RequestHelpScreen> createState() => _RequestHelpScreenState();
}

class _RequestHelpScreenState extends State<RequestHelpScreen> {
  String? _selectedType;
  final _descCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  bool _isLoading = false;
  Position? _position;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    setState(() => _locating = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      _position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {}
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _submit() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select assistance type'), backgroundColor: AppColors.accent),
      );
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    // Save to shared storage — visible to admin and responders
    SharedDataService.instance.submitRequest(
      userId: 'user-001',
      userName: 'Citizen',
      type: _selectedType!,
      priority: _priorityFor(_selectedType!),
      description: _descCtrl.text.trim().isEmpty ? 'No description provided' : _descCtrl.text.trim(),
      location: _position != null
          ? '${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}'
          : '${AppConstants.defaultLat}, ${AppConstants.defaultLng}',
      contactNumber: _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SuccessDialog(
          onDone: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      );
    }
  }

  String _priorityFor(String type) {
    const critical = ['boat', 'helicopter', 'medical', 'Boat Rescue', 'Helicopter Rescue', 'Medical Aid'];
    const high = ['water', 'evacuation', 'shelter', 'Water', 'Evacuation', 'Shelter'];
    if (critical.any((c) => type.toLowerCase().contains(c.toLowerCase()))) return 'critical';
    if (high.any((h) => type.toLowerCase().contains(h.toLowerCase()))) return 'high';
    return 'medium';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Request Assistance'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _locating
                    ? AppColors.accentYellow.withOpacity(0.1)
                    : _position != null
                        ? AppColors.safe.withOpacity(0.1)
                        : AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _locating
                      ? AppColors.accentYellow.withOpacity(0.4)
                      : _position != null
                          ? AppColors.safe.withOpacity(0.4)
                          : AppColors.accent.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _locating ? Icons.location_searching : _position != null ? Icons.location_on : Icons.location_off,
                    color: _locating ? AppColors.accentYellow : _position != null ? AppColors.safe : AppColors.accent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _locating
                        ? 'Detecting location...'
                        : _position != null
                            ? 'Location: ${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}'
                            : 'Location unavailable — using default',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  if (!_locating) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: _getLocation,
                      child: const Text('Retry', style: TextStyle(color: AppColors.accentGreen, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text('WHAT DO YOU NEED?', style: AppTextStyles.sectionHeader),
            const SizedBox(height: 12),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.1,
              ),
              itemCount: _types.length,
              itemBuilder: (_, i) {
                final t = _types[i];
                final selected = _selectedType == t.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = t.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? t.color.withOpacity(0.2) : AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? t.color : AppColors.divider, width: selected ? 2 : 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(t.icon, color: selected ? t.color : AppColors.textMuted, size: 16),
                        const SizedBox(height: 3),
                        Text(t.label, textAlign: TextAlign.center, style: TextStyle(color: selected ? t.color : AppColors.textMuted, fontSize: 8, fontWeight: FontWeight.w600, height: 1.2)),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            const Text('DETAILS', style: AppTextStyles.sectionHeader),
            const SizedBox(height: 12),

            TextField(
              controller: _descCtrl,
              maxLines: 4,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Describe your situation (optional but helpful)...',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _contactCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Contact Number (optional)',
                prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textMuted),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send, size: 20),
                label: const Text('SEND EMERGENCY REQUEST', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Your location will be automatically attached to this request. Requests are reviewed and prioritized by severity.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessDialog({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.safe, size: 64),
            const SizedBox(height: 16),
            const Text('Request Sent!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Your emergency request has been submitted and will be reviewed immediately. Stay safe.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: onDone, child: const Text('Done')),
            ),
          ],
        ),
      ),
    );
  }
}

// End of file
