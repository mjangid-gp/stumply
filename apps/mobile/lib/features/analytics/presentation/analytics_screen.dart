import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../data/analytics_repository.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Scaffold(body: Center(child: Text('Login required')));

    return Scaffold(
      appBar: AppBar(title: const Text('CricInsights')),
      body: FutureBuilder(
        future: ref.read(analyticsRepositoryProvider).getPlayerAnalytics(user.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final analytics = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MetricCard('Batting Average', analytics.battingAverage.toStringAsFixed(2)),
              _MetricCard('Strike Rate', analytics.strikeRate.toStringAsFixed(1)),
              _MetricCard('Economy', analytics.economy.toStringAsFixed(2)),
              _MetricCard('4s / 6s', '${analytics.fours} / ${analytics.sixes}'),
              const SizedBox(height: 24),
              Text('Form (Last Innings)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: analytics.inningsScores.isEmpty
                    ? const Center(child: Text('No innings data yet'))
                    : LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: true),
                          titlesData: const FlTitlesData(show: true),
                          borderData: FlBorderData(show: true),
                          lineBarsData: [
                            LineChartBarData(
                              spots: analytics.inningsScores
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                                  .toList(),
                              isCurved: true,
                              color: Colors.green,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                            ),
                          ],
                        ),
                      ),
              ),
              if (analytics.badges.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Badges', style: Theme.of(context).textTheme.titleMedium),
                Wrap(
                  spacing: 8,
                  children: analytics.badges.map((b) => Chip(label: Text(b))).toList(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))],
        ),
      ),
    );
  }
}
