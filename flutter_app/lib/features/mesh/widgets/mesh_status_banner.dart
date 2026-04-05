// lib/features/mesh/widgets/mesh_status_banner.dart
import 'package:flutter/material.dart';
import '../services/mesh_service.dart';
import '../../../core/theme/app_theme.dart';

/// Compact banner that sits below the AppBar on all screens.
/// Shows current mesh connectivity state and peer count.
/// Tapping it navigates to the full Mesh screen.
class MeshStatusBanner extends StatefulWidget {
  final VoidCallback? onTap;
  const MeshStatusBanner({super.key, this.onTap});

  @override
  State<MeshStatusBanner> createState() => _MeshStatusBannerState();
}

class _MeshStatusBannerState extends State<MeshStatusBanner>
    with SingleTickerProviderStateMixin {
  MeshConnectivityState _state = MeshConnectivityState.starting;
  int _peerCount = 0;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Subscribe to mesh state changes
    MeshService.instance.connectivityStream.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    MeshService.instance.nodesStream.listen((nodes) {
      if (mounted) setState(() => _peerCount = nodes.length);
    });

    _state = MeshService.instance.currentState;
    _peerCount = MeshService.instance.connectedNodes.length;
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  _BannerConfig get _config => switch (_state) {
    MeshConnectivityState.online => _BannerConfig(
        color: AppColors.safe,
        bgColor: AppColors.safe.withOpacity(0.08),
        icon: Icons.wifi,
        label: 'Online',
        sublabel: _peerCount > 0 ? '+ $_peerCount mesh peers' : 'Internet connected',
      ),
    MeshConnectivityState.meshOnly => _BannerConfig(
        color: AppColors.accentYellow,
        bgColor: AppColors.accentYellow.withOpacity(0.08),
        icon: Icons.bluetooth,
        label: 'Mesh Only',
        sublabel: '$_peerCount peer${_peerCount != 1 ? 's' : ''} connected',
        pulsing: true,
      ),
    MeshConnectivityState.isolated => _BannerConfig(
        color: AppColors.critical,
        bgColor: AppColors.critical.withOpacity(0.08),
        icon: Icons.bluetooth_searching,
        label: 'Isolated',
        sublabel: 'Searching for peers...',
        pulsing: true,
      ),
    MeshConnectivityState.starting => _BannerConfig(
        color: AppColors.textMuted,
        bgColor: AppColors.surfaceLight,
        icon: Icons.settings_bluetooth,
        label: 'Starting Mesh',
        sublabel: 'Initializing...',
      ),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _config;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: cfg.bgColor,
          border: Border(
            bottom: BorderSide(color: cfg.color.withOpacity(0.2), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Pulsing indicator dot
            if (cfg.pulsing)
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: cfg.color.withOpacity(_pulse.value),
                    shape: BoxShape.circle,
                  ),
                ),
              )
            else
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: cfg.color,
                  shape: BoxShape.circle,
                ),
              ),

            const SizedBox(width: 8),

            Icon(cfg.icon, color: cfg.color, size: 13),

            const SizedBox(width: 6),

            Text(
              cfg.label,
              style: TextStyle(
                color: cfg.color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(width: 6),

            Text(
              '·  ${cfg.sublabel}',
              style: TextStyle(
                color: cfg.color.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),

            const Spacer(),

            // Mesh icon tap hint
            Icon(
              Icons.hub_outlined,
              color: cfg.color.withOpacity(0.5),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerConfig {
  final Color color;
  final Color bgColor;
  final IconData icon;
  final String label;
  final String sublabel;
  final bool pulsing;

  const _BannerConfig({
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.label,
    required this.sublabel,
    this.pulsing = false,
  });
}
