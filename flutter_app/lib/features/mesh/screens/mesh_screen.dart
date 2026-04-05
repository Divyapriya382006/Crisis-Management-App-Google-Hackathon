import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crisis_response_app/core/theme/app_theme.dart';
import 'package:crisis_response_app/features/mesh/services/mesh_service.dart';
import 'package:crisis_response_app/features/mesh/services/mesh_message_store.dart';
import 'package:crisis_response_app/features/mesh/widgets/mesh_node_radar.dart';
import 'package:crisis_response_app/shared/models/mesh_message_model.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:crisis_response_app/core/services/shared_data_service.dart';

class MeshScreen extends StatefulWidget {
  const MeshScreen({super.key});

  @override
  State<MeshScreen> createState() => _MeshScreenState();
}

class _MeshScreenState extends State<MeshScreen> with TickerProviderStateMixin {
  late TabController _tabCtrl;
  final _textCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _sendSos() async {
    setState(() => _sending = true);
    
    try {
      final pos = await Geolocator.getCurrentPosition();
      final success = await MeshService.instance.sendSos(
        text: _textCtrl.text.isEmpty ? 'Emergency — need immediate help' : _textCtrl.text,
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
      );

      // ALSO submit to shared local storage for responders
      SharedDataService.instance.submitRequest(
        userId: 'user-001',
        userName: 'Citizen (via Mesh)',
        type: 'Mesh SOS',
        priority: 'critical',
        description: _textCtrl.text.isEmpty ? 'Emergency SOS via BLE Mesh' : _textCtrl.text,
        location: '${pos.latitude}, ${pos.longitude}',
      );

      if (success && mounted) {
        _textCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🆘 SOS broadcasted to all nearby mesh nodes!'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.accent),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _sendText() async {
    if (_textCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    
    try {
      final success = await MeshService.instance.sendText(text: _textCtrl.text.trim());
      if (success && mounted) {
        _textCtrl.clear();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Status header
        StreamBuilder<MeshConnectivityState>(
          stream: MeshService.instance.connectivityStream,
          initialData: MeshService.instance.currentState,
          builder: (context, snapshot) {
            final state = snapshot.data!;
            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: state == MeshConnectivityState.online 
                    ? AppColors.safe.withOpacity(0.4) 
                    : AppColors.accentYellow.withOpacity(0.4), 
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (state == MeshConnectivityState.online ? AppColors.safe : AppColors.accentYellow).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              state == MeshConnectivityState.online ? Icons.wifi : Icons.bluetooth_searching, 
                              color: state == MeshConnectivityState.online ? AppColors.safe : AppColors.accentYellow, 
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              state == MeshConnectivityState.online ? 'CONNECTED (BRIDGE)' : 'OFFLINE MESH ACTIVE', 
                              style: TextStyle(
                                color: state == MeshConnectivityState.online ? AppColors.safe : AppColors.accentYellow, 
                                fontWeight: FontWeight.w800, fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Bluetooth mesh is discovery and relaying data to nearby peers automatically.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<MeshNode>>(
                    stream: MeshService.instance.nodesStream,
                    initialData: MeshService.instance.allDiscoveredNodes,
                    builder: (context, nodesSnap) {
                      final nodes = nodesSnap.data ?? [];
                      return Row(
                        children: [
                          _Pill(Icons.people, '${nodes.length} nearby', AppColors.accentGreen),
                          const SizedBox(width: 8),
                          _Pill(Icons.hub, 'Relay Active', AppColors.accentYellow),
                        ],
                      );
                    }
                  ),
                ],
              ),
            );
          }
        ),

        // Tabs
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(icon: Icon(Icons.radar, size: 16), text: 'Radar'),
              Tab(icon: Icon(Icons.message_outlined, size: 16), text: 'Messages'),
              Tab(icon: Icon(Icons.sos, size: 16), text: 'Send SOS'),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _RadarTab(),
              const _MessagesTab(),
              _SendTab(
                textCtrl: _textCtrl,
                sending: _sending,
                onSos: _sendSos,
                onText: _sendText,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Radar Tab ─────────────────────────────────────────────────────────────────
class _RadarTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MeshNode>>(
      stream: MeshService.instance.nodesStream,
      initialData: MeshService.instance.allDiscoveredNodes,
      builder: (context, snapshot) {
        final nodes = snapshot.data ?? [];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // High-fidelity animated radar
              MeshNodeRadar(nodes: nodes, size: 280),
              
              const SizedBox(height: 32),
              Icon(
                nodes.isEmpty ? Icons.bluetooth_searching : Icons.bluetooth_connected, 
                color: nodes.isEmpty ? AppColors.textMuted : AppColors.accentGreen, 
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                nodes.isEmpty ? 'Searching for nearby peers...' : 'Found ${nodes.length} nearby devices', 
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Data is automatically relayed across all connected nodes.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _LegendItem(AppColors.accent, 'You'),
                  SizedBox(width: 20),
                  _LegendItem(AppColors.accentGreen, 'Peer'),
                  SizedBox(width: 20),
                  _LegendItem(AppColors.safe, 'Bridge'),
                ],
              ),
            ],
          ),
        );
      }
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8, height: 8, 
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [
            BoxShadow(color: color.withOpacity(0.4), blurRadius: 4, spreadRadius: 1),
          ]),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

// ── Messages Tab ──────────────────────────────────────────────────────────────
class _MessagesTab extends StatelessWidget {
  const _MessagesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MeshMessage>(
      stream: MeshService.instance.incomingMessages,
      builder: (context, _) {
        // We use FutureBuilder to fetch history from Hive, 
        // while StreamBuilder ensures we rebuild whenever a NEW message arrives.
        return FutureBuilder<List<MeshMessage>>(
          future: Future.value(MeshMessageStore.instance.getAll()),
          builder: (context, snapshot) {
            final messages = snapshot.data ?? [];
            if (messages.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.forum_outlined, color: AppColors.textMuted, size: 40),
                    SizedBox(height: 12),
                    Text('Mesh network is quiet', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Text('Messages will appear here as they are received.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _MessageCard(message: messages[i]),
            );
          }
        );
      }
    );
  }
}

class _MessageCard extends StatelessWidget {
  final MeshMessage message;
  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final isSos = message.type == MeshMessageType.sos;
    final timeStr = DateFormat('HH:mm').format(message.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSos ? AppColors.critical.withOpacity(0.5) : AppColors.divider,
          width: isSos ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isSos ? AppColors.critical : AppColors.divider).withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(
                  isSos ? Icons.sos : Icons.person_outline, 
                  size: 14, 
                  color: isSos ? AppColors.critical : AppColors.accentGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  message.senderName.toUpperCase(),
                  style: TextStyle(
                    color: isSos ? AppColors.critical : AppColors.accentGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  timeStr,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          
          // Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text ?? (isSos ? 'Emergency SOS' : 'No content'),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
                ),
                if (isSos && message.latitude != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.accent, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'GPS: ${message.latitude!.toStringAsFixed(4)}, ${message.longitude!.toStringAsFixed(4)}',
                        style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Footer (Relay info)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Icon(Icons.hub_outlined, color: AppColors.textMuted.withOpacity(0.5), size: 10),
                const SizedBox(width: 4),
                Text(
                  'Hop Count: ${message.hopCount} • ${message.priority.name.toUpperCase()} PRIORITY',
                  style: TextStyle(color: AppColors.textMuted.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Send Tab ──────────────────────────────────────────────────────────────────
class _SendTab extends StatelessWidget {
  final TextEditingController textCtrl;
  final bool sending;
  final VoidCallback onSos;
  final VoidCallback onText;
  const _SendTab({required this.textCtrl, required this.sending, required this.onSos, required this.onText});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('EMERGENCY SOS', style: AppTextStyles.sectionHeader),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.critical.withOpacity(0.15), AppColors.card],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.critical.withOpacity(0.5), width: 1.5),
            ),
            child: Column(
              children: [
                const Text(
                  'Broadcasts your GPS + message to ALL nearby app users via BLE.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textCtrl,
                  maxLength: 200,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Describe your emergency (optional)...',
                    counterStyle: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton.icon(
                    onPressed: sending ? null : onSos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.critical,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.sos, size: 24),
                    label: const Text('BROADCAST SOS OVER MESH', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('MESH MESSAGE', style: AppTextStyles.sectionHeader),
          const SizedBox(height: 10),
          TextField(
            controller: textCtrl,
            maxLength: 200,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Type a message to nearby peers...',
              counterStyle: TextStyle(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              onPressed: sending ? null : onText,
              icon: const Icon(Icons.bluetooth_searching, size: 18),
              label: const Text('Send via BLE Mesh', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Pill(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}