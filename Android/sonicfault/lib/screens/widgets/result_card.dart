
// ════════════════════════════════════════════════════════════════════════════
// lib/screens/widgets/result_card.dart
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/detection_result.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';

class ResultCard extends StatelessWidget {
  final DetectionResult result;
  const ResultCard({super.key, required this.result});

  Color get _severityColor {
    final k = result.labelKey;
    if (k.contains('engine') || k.contains('brake') || k.contains('knock')) {
      return AppTheme.red;
    }
    if (k.contains('exhaust') || k.contains('wheel') || k.contains('transmission')) {
      return Colors.orange;
    }
    return AppTheme.green;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _severityColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _severityColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: _severityColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('DETECTED ISSUE',
                    style: TextStyle(
                        color: AppTheme.textSec,
                        fontSize: 11,
                        letterSpacing: 1.5)),
                const SizedBox(height: 2),
                Text(result.label,
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        color: _severityColor)),
              ]),
            ),
            Text('${(result.confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    color: _severityColor,
                    fontSize: 24,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.w700)),
          ]),

          const SizedBox(height: 20),

          // Top-5 bar chart
          Text('CONFIDENCE SCORES',
              style: TextStyle(
                  color: AppTheme.textSec,
                  fontSize: 11,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 1.0,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx >= result.allScores.length) return const SizedBox();
                        final lbl = result.allScores[idx].label;
                        final short = lbl.split(' ').first;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(short,
                              style: const TextStyle(
                                  color: AppTheme.textSec, fontSize: 9)),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(result.allScores.length, (i) {
                  final s = result.allScores[i];
                  final isTop = i == 0;
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: s.score,
                      color: isTop ? _severityColor : AppTheme.border,
                      width: 20,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
