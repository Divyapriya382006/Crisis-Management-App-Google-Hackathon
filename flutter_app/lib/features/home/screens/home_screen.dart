// lib/features/home/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:geolocator/geolocator.dart';
import 'package:crisis_response_app/core/theme/app_theme.dart';
import 'package:crisis_response_app/core/constants/app_constants.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _shareLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final url = 'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';
      await Share.share('My current emergency location: $url\nSent via Crisis Response App');
    } catch (e) {
      // Fallback
      await Share.share('I need help but am unable to fetch precise GPS at the moment.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── BIG SOS BUTTON ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2D0A0F), Color(0xFF1A0508), Color(0xFF0F1E35)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.emergency, color: AppColors.accent, size: 18),
                    SizedBox(width: 8),
                    Text('EMERGENCY', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.5)),
                    Spacer(),
                    _LiveBadge(),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 72,
                  child: ElevatedButton(
                    onPressed: () => _callNumber('112'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: AppColors.accent.withOpacity(0.4),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone, size: 28, color: Colors.white),
                        SizedBox(width: 12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SOS — CALL 112', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                            Text('Tap to call emergency services', style: TextStyle(fontSize: 11, color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _InputBtn(icon: Icons.mic, label: 'Voice\nInput', onTap: () => context.go('/home/assistant'))),
                    const SizedBox(width: 10),
                    Expanded(child: _InputBtn(icon: Icons.edit_note, label: 'Text\nInput', onTap: () => context.go('/home/request-help'))),
                    const SizedBox(width: 10),
                    Expanded(child: _InputBtn(icon: Icons.my_location, label: 'Share\nLocation', onTap: _shareLocation)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── QUICK ACTIONS ───────────────────────────────────────────────
          const _SectionHeader('QUICK ACTIONS'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _QuickAction(icon: Icons.local_police, label: 'Police', color: AppColors.accent, onTap: () => _callNumber('100'))),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(icon: Icons.local_hospital, label: 'Hospital', color: AppColors.accentGreen, onTap: () => _callNumber('108'))),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(icon: Icons.local_fire_department, label: 'Fire', color: AppColors.accentOrange, onTap: () => _callNumber('101'))),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(icon: Icons.send, label: 'Alert', color: AppColors.accentYellow, onTap: () => context.go('/home/request-help'))),
            ],
          ),

          const SizedBox(height: 24),

          // ── HELPLINES ───────────────────────────────────────────────────
          const _SectionHeader('EMERGENCY HELPLINES'),
          const SizedBox(height: 12),
          const _HelplineCard(label: 'Police', number: '100', icon: Icons.local_police, color: AppColors.accent),
          const SizedBox(height: 8),
          const _HelplineCard(label: 'Ambulance / Medical', number: '108', icon: Icons.medical_services, color: AppColors.accentGreen),
          const SizedBox(height: 8),
          const _HelplineCard(label: 'Fire Brigade', number: '101', icon: Icons.local_fire_department, color: AppColors.accentOrange),
          const SizedBox(height: 8),
          const _HelplineCard(label: "Women's Helpline", number: '1091', icon: Icons.woman, color: Color(0xFFDA70D6)),
          const SizedBox(height: 8),
          const _HelplineCard(label: 'Disaster Management', number: '1078', icon: Icons.emergency, color: AppColors.accentYellow),

          const SizedBox(height: 24),

          // ── RECENT ALERTS ───────────────────────────────────────────────
          const _SectionHeader('RECENT ALERTS'),
          const SizedBox(height: 12),
          const _AlertCard(
            title: 'Cyclone Alert: Bay of Bengal',
            body: 'IMD warns of cyclonic storm. Coastal areas on high alert. Fishing suspended.',
            type: 'CRITICAL',
            source: 'IMD / Govt. of India',
            timeAgo: '12m ago',
            color: AppColors.critical,
          ),
          const SizedBox(height: 8),
          const _AlertCard(
            title: 'Heavy Rainfall Warning',
            body: 'Red alert issued. 150mm+ rainfall expected in 24 hours.',
            type: 'WARNING',
            source: 'Chennai Corporation',
            timeAgo: '1h ago',
            color: AppColors.accentOrange,
          ),

          const SizedBox(height: 24),

          // ── AI ASSISTANT CTA ────────────────────────────────────────────
          GestureDetector(
            onTap: () => context.go('/home/assistant'),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accentGreen.withOpacity(0.15), AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.smart_toy_outlined, color: AppColors.accentGreen, size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Crisis Assistant', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                        SizedBox(height: 4),
                        Text('Ask about shelters, resources, or contacts', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 14),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          // ADD after the last SizedBox(height: 16) in the column
Align(
  alignment: Alignment.centerRight,
  child: TextButton(
    onPressed: () => context.go(RouteNames.login),
    child: const Text(
      'Staff Access',
      style: TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
    ),
  ),
),
const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.safe.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('LIVE', style: TextStyle(color: AppColors.safe, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.sectionHeader);
  }
}

class _InputBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _InputBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _HelplineCard extends StatelessWidget {
  final String label;
  final String number;
  final IconData icon;
  final Color color;
  const _HelplineCard({required this.label, required this.number, required this.icon, required this.color});

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(number, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _call,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.phone, color: color, size: 14),
                  const SizedBox(width: 4),
                  Text('Call', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String title, body, type, source, timeAgo;
  final Color color;
  const _AlertCard({required this.title, required this.body, required this.type, required this.source, required this.timeAgo, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(type, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ),
              const Spacer(),
              Text(timeAgo, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.verified, color: AppColors.textMuted, size: 11),
              const SizedBox(width: 4),
              Text(source, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}