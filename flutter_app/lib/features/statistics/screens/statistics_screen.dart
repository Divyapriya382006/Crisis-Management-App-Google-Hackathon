// lib/features/statistics/screens/statistics_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:crisis_response_app/core/theme/app_theme.dart';
import 'package:crisis_response_app/shared/models/models.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  WeatherStats? _weather;
  SeismicStats? _seismic;
  bool _loading = true;
  DateTime? _lastUpdated;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) => _fetchStats());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    // Use mock data directly — no backend needed
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() {
        _weather = WeatherStats.mock();
        _seismic = SeismicStats.mock();
        _lastUpdated = DateTime.now();
        _loading = false;
      });
    }
  }

  String _freshnessLabel() {
    if (_lastUpdated == null) return 'No data';
    final diff = DateTime.now().difference(_lastUpdated!);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    return 'Cached (${diff.inHours}h old)';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.accent));

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _fetchStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Data freshness
            Row(
              children: [
                const Icon(Icons.update, color: AppColors.textMuted, size: 14),
                const SizedBox(width: 6),
                Text(_freshnessLabel(), style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📊 Statistics report exported to device storage')),
                    );
                  },
                  child: const Row(children: [
                    Icon(Icons.ios_share, color: AppColors.accent, size: 14),
                    SizedBox(width: 4),
                    Text('Export', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _fetchStats,
                  child: const Row(children: [
                    Icon(Icons.refresh, color: AppColors.accentGreen, size: 14),
                    SizedBox(width: 4),
                    Text('Refresh', style: TextStyle(color: AppColors.accentGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Location
            const Text('CURRENT LOCATION — CHENNAI', style: AppTextStyles.sectionHeader),
            const SizedBox(height: 12),

            // Weather grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                _StatCard(label: 'Temperature', value: '${_weather!.temperature.toStringAsFixed(1)}°C', icon: Icons.thermostat, color: AppColors.accentOrange, sub: 'Feels like ${(_weather!.temperature + 2).toStringAsFixed(1)}°C'),
                _StatCard(label: 'Humidity', value: '${_weather!.humidity.toStringAsFixed(0)}%', icon: Icons.water_drop, color: const Color(0xFF1E90FF), sub: _humidityLabel(_weather!.humidity)),
                _StatCard(label: 'Wind', value: '${_weather!.windSpeed.toStringAsFixed(1)} km/h', icon: Icons.air, color: AppColors.accentGreen, sub: 'Direction: ${_weather!.windDirection}'),
                _StatCard(label: 'Conditions', value: _weather!.condition, icon: Icons.cloud, color: const Color(0xFF8A2BE2), sub: 'Current sky'),
              ],
            ),

            const SizedBox(height: 20),

            // Seismic section
            const Text('SEISMIC / TECTONIC', style: AppTextStyles.sectionHeader),
            const SizedBox(height: 12),
            _SeismicCard(stats: _seismic!),

            const SizedBox(height: 20),

            // Ocean / Wave
            const Text('OCEAN CONDITIONS', style: AppTextStyles.sectionHeader),
            const SizedBox(height: 12),
            _OceanCard(),

            const SizedBox(height: 20),

            // Historical chart
            const Text('HUMIDITY TREND (24H)', style: AppTextStyles.sectionHeader),
            const SizedBox(height: 12),
            _HumidityChart(),

            const SizedBox(height: 20),

            // Risk level summary
            const Text('RISK ASSESSMENT', style: AppTextStyles.sectionHeader),
            const SizedBox(height: 12),
            _RiskSummary(weather: _weather!, seismic: _seismic!),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _humidityLabel(double h) {
    if (h > 80) return 'Very High';
    if (h > 60) return 'High';
    if (h > 40) return 'Moderate';
    return 'Low';
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Flexible(child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 9), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SeismicCard extends StatelessWidget {
  final SeismicStats stats;
  const _SeismicCard({required this.stats});

  Color get _levelColor => switch (stats.level) {
    'high' || 'severe' => AppColors.critical,
    'moderate' => AppColors.high,
    'low' => AppColors.medium,
    _ => AppColors.safe,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _levelColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(stats.magnitude.toStringAsFixed(1), style: TextStyle(color: _levelColor, fontSize: 36, fontWeight: FontWeight.w800)),
              const Text('Richter', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(width: 20),
          const VerticalDivider(color: AppColors.divider, thickness: 1),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Activity Level: ${stats.level.toUpperCase()}', style: TextStyle(color: _levelColor, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Region: ${stats.region}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                if (stats.lastActivity != null) ...[
                  const SizedBox(height: 4),
                  Text('Last activity: ${_timeAgo(stats.lastActivity!)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _OceanCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E90FF).withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text('1.2m', style: TextStyle(color: Color(0xFF1E90FF), fontSize: 24, fontWeight: FontWeight.w800)),
                Text('Wave Height', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text('18°C', style: TextStyle(color: AppColors.accentGreen, fontSize: 24, fontWeight: FontWeight.w800)),
                Text('Sea Temp', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text('LOW', style: TextStyle(color: AppColors.safe, fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Tsunami Risk', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HumidityChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Mock 24h humidity data
    final spots = List.generate(24, (i) => FlSpot(i.toDouble(), 55 + (i % 7) * 4.5 - (i % 3) * 2));
    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 0.5),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(color: AppColors.textMuted, fontSize: 9)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 6, getTitlesWidget: (v, _) => Text('${v.toInt()}h', style: const TextStyle(color: AppColors.textMuted, fontSize: 9)))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF1E90FF),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: const Color(0xFF1E90FF).withOpacity(0.08)),
            ),
          ],
          minY: 40, maxY: 100,
        ),
      ),
    );
  }
}

class _RiskSummary extends StatelessWidget {
  final WeatherStats weather;
  final SeismicStats seismic;
  const _RiskSummary({required this.weather, required this.seismic});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RiskRow(label: 'Flood Risk', level: weather.humidity > 80 ? 'HIGH' : 'MODERATE', color: weather.humidity > 80 ? AppColors.critical : AppColors.medium),
        const SizedBox(height: 8),
        _RiskRow(label: 'Storm Risk', level: weather.windSpeed > 50 ? 'HIGH' : 'LOW', color: weather.windSpeed > 50 ? AppColors.critical : AppColors.safe),
        const SizedBox(height: 8),
        _RiskRow(label: 'Seismic Risk', level: seismic.level.toUpperCase(), color: seismic.level == 'high' ? AppColors.critical : AppColors.safe),
        const SizedBox(height: 8),
        _RiskRow(label: 'Tsunami Risk', level: 'LOW', color: AppColors.safe),
      ],
    );
  }
}

class _RiskRow extends StatelessWidget {
  final String label, level;
  final Color color;
  const _RiskRow({required this.label, required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(level, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8)),
          ),
        ],
      ),
    );
  }
}
