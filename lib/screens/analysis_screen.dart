import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../provider/app_provider.dart';
import '../utils/theme.dart';

class AnalysisScreen extends StatefulWidget {
  final String matchId;
  const AnalysisScreen({super.key, required this.matchId});
  @override State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (ctx, provider, _) {
      final match = provider.matches.firstWhere((m) => m.id == widget.matchId);

      return Scaffold(
        appBar: AppBar(
          title: const Text('Analysis'),
          bottom: TabBar(
            controller: _tab,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'WORM'),
              Tab(text: 'RUN RATE'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tab,
          children: [
            _WormChart(match: match),
            _RunRateChart(match: match),
          ],
        ),
      );
    });
  }
}

// Worm chart (cumulative runs per over)

class _WormChart extends StatelessWidget {
  final CricketMatch match;
  const _WormChart({required this.match});

  @override
  Widget build(BuildContext context) {
    final first = match.firstInnings;
    final second = match.secondInnings;

    List<FlSpot> spots1 = [const FlSpot(0, 0)];
    List<FlSpot> spots2 = [const FlSpot(0, 0)];

    if (first != null) {
      for (int i = 0; i < first.overRunTotals.length; i++) {
        spots1.add(FlSpot((i + 1).toDouble(),
            first.overRunTotals[i].toDouble()));
      }
      // Add current partial over
      if (first.totalRuns > (first.overRunTotals.isNotEmpty
          ? first.overRunTotals.last : 0)) {
        spots1.add(FlSpot(
            (first.overRunTotals.length + first.ballsInCurrentOver / 6)
                .toDouble(),
            first.totalRuns.toDouble()));
      }
    }

    if (second != null) {
      for (int i = 0; i < second.overRunTotals.length; i++) {
        spots2.add(FlSpot((i + 1).toDouble(),
            second.overRunTotals[i].toDouble()));
      }
      if (second.totalRuns > (second.overRunTotals.isNotEmpty
          ? second.overRunTotals.last : 0)) {
        spots2.add(FlSpot(
            (second.overRunTotals.length + second.ballsInCurrentOver / 6)
                .toDouble(),
            second.totalRuns.toDouble()));
      }
    }

    double maxY = [
      ...spots1.map((s) => s.y),
      ...spots2.map((s) => s.y),
    ].fold(20.0, (a, b) => a > b ? a : b) + 20;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _Legend(),
        const SizedBox(height: 12),
        Expanded(
          child: LineChart(LineChartData(
            minX: 0, maxX: match.totalOvers.toDouble(),
            minY: 0, maxY: maxY,
            gridData: FlGridData(
              show: true,
              horizontalInterval: 20,
              verticalInterval: 2,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.grey.shade200, strokeWidth: 1),
              getDrawingVerticalLine: (_) => FlLine(
                  color: Colors.grey.shade200, strokeWidth: 1),
            ),
            borderData: FlBorderData(
                border: Border.all(color: Colors.grey.shade300)),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 40,
                  reservedSize: 40,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style: const TextStyle(fontSize: 11,
                          color: AppTheme.textSecondary)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 3,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style: const TextStyle(fontSize: 11,
                          color: AppTheme.textSecondary)),
                ),
              ),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              if (spots1.length > 1)
                LineChartBarData(
                  spots: spots1,
                  color: AppTheme.host,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 3, color: AppTheme.host,
                        strokeWidth: 1, strokeColor: Colors.white),
                  ),
                ),
              if (spots2.length > 1)
                LineChartBarData(
                  spots: spots2,
                  color: AppTheme.visitor,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 3, color: AppTheme.visitor,
                        strokeWidth: 1, strokeColor: Colors.white),
                  ),
                ),
            ],
          )),
        ),
      ]),
    );
  }
}


// RUN rate chart (per-over run rate)

class _RunRateChart extends StatelessWidget {
  final CricketMatch match;
  const _RunRateChart({required this.match});

  List<FlSpot> _getRateSpots(Innings innings) {
    final spots = <FlSpot>[];
    int prev = 0;
    for (int i = 0; i < innings.overRunTotals.length; i++) {
      final overRuns = innings.overRunTotals[i] - prev;
      spots.add(FlSpot((i + 1).toDouble(), overRuns.toDouble()));
      prev = innings.overRunTotals[i];
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final first = match.firstInnings;
    final second = match.secondInnings;

    final spots1 = first != null ? _getRateSpots(first) : <FlSpot>[];
    final spots2 = second != null ? _getRateSpots(second) : <FlSpot>[];

    double maxY = [
      ...spots1.map((s) => s.y),
      ...spots2.map((s) => s.y),
    ].fold(10.0, (a, b) => a > b ? a : b) + 2;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _Legend(),
        const SizedBox(height: 12),
        Expanded(
          child: LineChart(LineChartData(
            minX: 0, maxX: match.totalOvers.toDouble(),
            minY: 0, maxY: maxY,
            gridData: FlGridData(
              show: true,
              horizontalInterval: 2,
              verticalInterval: 2,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.grey.shade200, strokeWidth: 1),
              getDrawingVerticalLine: (_) => FlLine(
                  color: Colors.grey.shade200, strokeWidth: 1),
            ),
            borderData: FlBorderData(
                border: Border.all(color: Colors.grey.shade300)),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 2,
                  reservedSize: 30,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style: const TextStyle(fontSize: 11,
                          color: AppTheme.textSecondary)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 3,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style: const TextStyle(fontSize: 11,
                          color: AppTheme.textSecondary)),
                ),
              ),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              if (spots1.isNotEmpty)
                LineChartBarData(
                  spots: spots1,
                  color: AppTheme.host,
                  barWidth: 2.5,
                  isCurved: true, curveSmoothness: 0.3,
                  dotData: FlDotData(
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                          radius: 4, color: AppTheme.host,
                          strokeWidth: 2, strokeColor: Colors.white)),
                ),
              if (spots2.isNotEmpty)
                LineChartBarData(
                  spots: spots2,
                  color: AppTheme.visitor,
                  barWidth: 2.5,
                  isCurved: true, curveSmoothness: 0.3,
                  dotData: FlDotData(
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                          radius: 4, color: AppTheme.visitor,
                          strokeWidth: 2, strokeColor: Colors.white)),
                ),
            ],
          )),
        ),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _dot(AppTheme.host), const SizedBox(width: 4),
      const Text('Host Team', style: TextStyle(fontSize: 12)),
      const SizedBox(width: 20),
      _dot(AppTheme.visitor), const SizedBox(width: 4),
      const Text('Visitor Team', style: TextStyle(fontSize: 12)),
    ],
  );

  Widget _dot(Color c) => Container(
      width: 12, height: 12,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}