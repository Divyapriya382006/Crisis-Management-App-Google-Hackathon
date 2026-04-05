// lib/features/mesh/widgets/mesh_node_radar.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/mesh_service.dart';
import '../../../shared/models/mesh_message_model.dart';
import '../../../core/theme/app_theme.dart';

/// Animated radar visualization showing nearby mesh nodes.
/// Nodes rotate around a center "you" dot.
/// Bridge nodes (with internet) are highlighted in green.
class MeshNodeRadar extends StatefulWidget {
  final List<MeshNode> nodes;
  final double size;

  const MeshNodeRadar({
    super.key,
    required this.nodes,
    this.size = 280,
  });

  @override
  State<MeshNodeRadar> createState() => _MeshNodeRadarState();
}

class _MeshNodeRadarState extends State<MeshNodeRadar>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepCtrl;

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _sweepCtrl,
        builder: (_, __) {
          return CustomPaint(
            painter: _RadarPainter(
              nodes: widget.nodes,
              sweepAngle: _sweepCtrl.value * 2 * math.pi,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Center "You" node
                _YouNode(),
                // Peer node labels
                ...widget.nodes.asMap().entries.map((entry) {
                  return _NodeLabel(
                    node: entry.value,
                    index: entry.key,
                    total: widget.nodes.length,
                    radarSize: widget.size,
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<MeshNode> nodes;
  final double sweepAngle;

  _RadarPainter({required this.nodes, required this.sweepAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // ── Background rings ──────────────────────────────────────────────────
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      ringPaint.color = AppColors.accentGreen.withOpacity(0.12 + i * 0.03);
      canvas.drawCircle(center, maxRadius * i / 3, ringPaint);
    }

    // ── Radar sweep ───────────────────────────────────────────────────────
    final sweepPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.accentGreen.withOpacity(0.35),
          AppColors.accentGreen.withOpacity(0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius),
      sweepAngle,
      math.pi / 3, // 60-degree sweep cone
      true,
      sweepPaint,
    );

    // ── Cross-hairs ───────────────────────────────────────────────────────
    final hairPaint = Paint()
      ..color = AppColors.accentGreen.withOpacity(0.15)
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), hairPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), hairPaint);

    // ── Node dots ─────────────────────────────────────────────────────────
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final angle = (2 * math.pi / math.max(nodes.length, 1)) * i - math.pi / 2;
      // Assign radius based on signal: closer = stronger
      final radius = _rssiToRadius(node.rssi, maxRadius);
      final nodeOffset = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      // Node color: bridge nodes are green, regular are blue
      final nodeColor = node.hasInternet ? AppColors.safe : AppColors.accentGreen;

      // Outer glow
      canvas.drawCircle(
        nodeOffset,
        10,
        Paint()..color = nodeColor.withOpacity(0.15),
      );

      // Node dot
      canvas.drawCircle(
        nodeOffset,
        5,
        Paint()..color = nodeColor,
      );

      // Bridge indicator ring
      if (node.hasInternet) {
        canvas.drawCircle(
          nodeOffset,
          8,
          Paint()
            ..color = nodeColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }

      // Connection line from center
      canvas.drawLine(
        center,
        nodeOffset,
        Paint()
          ..color = nodeColor.withOpacity(0.2)
          ..strokeWidth = 0.8,
      );
    }
  }

  double _rssiToRadius(int rssi, double maxRadius) {
    // Map RSSI range (-100 to -40) to radius (80% to 30% of max)
    final clamped = rssi.clamp(-100, -40);
    final t = (clamped + 100) / 60; // 0 = far, 1 = close
    return maxRadius * (0.85 - t * 0.55); // 0.3 to 0.85 of max radius
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.sweepAngle != sweepAngle;
}

class _YouNode extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 2),
          ),
          child: const Icon(Icons.person, color: AppColors.accent, size: 18),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'YOU',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _NodeLabel extends StatelessWidget {
  final MeshNode node;
  final int index;
  final int total;
  final double radarSize;

  const _NodeLabel({
    required this.node,
    required this.index,
    required this.total,
    required this.radarSize,
  });

  @override
  Widget build(BuildContext context) {
    final maxRadius = radarSize / 2;
    final rssi = node.rssi;
    final clamped = rssi.clamp(-100, -40);
    final t = (clamped + 100) / 60;
    final radius = maxRadius * (0.85 - t * 0.55);

    final angle = (2 * math.pi / math.max(total, 1)) * index - math.pi / 2;
    final x = radius * math.cos(angle);
    final y = radius * math.sin(angle);

    final nodeColor = node.hasInternet ? AppColors.safe : AppColors.accentGreen;

    return Positioned(
      left: maxRadius + x - 30,
      top: maxRadius + y + 10,
      child: SizedBox(
        width: 60,
        child: Column(
          children: [
            Text(
              node.name.split(' ').first, // First name only
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: nodeColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (node.hasInternet)
              Text(
                '🌐',
                style: const TextStyle(fontSize: 8),
              ),
          ],
        ),
      ),
    );
  }
}
