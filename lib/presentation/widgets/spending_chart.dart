import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/mpesa_constants.dart';

class SpendingChart extends StatelessWidget {
  final Map<DateTime, double> dailySpending;
  final Map<DateTime, double> dailyIncome;
  final int days;
  final String? title;
  final bool useAllDates;

  const SpendingChart({
    super.key,
    required this.dailySpending,
    required this.dailyIncome,
    this.days = 7,
    this.title,
    this.useAllDates = false,
  });

  @override
  Widget build(BuildContext context) {
    final sortedDates = dailySpending.keys.toList()..sort();
    final chartDates = useAllDates
        ? sortedDates
        : (sortedDates.length > days
              ? sortedDates.sublist(sortedDates.length - days)
              : sortedDates);

    if (chartDates.isEmpty ||
        chartDates.every(
          (d) => (dailySpending[d] ?? 0) == 0 && (dailyIncome[d] ?? 0) == 0,
        )) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'No data available',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final maxSpending = chartDates
        .map((d) => dailySpending[d] ?? 0)
        .fold(0.0, (a, b) => a > b ? a : b);
    final maxIncome = chartDates
        .map((d) => dailyIncome[d] ?? 0)
        .fold(0.0, (a, b) => a > b ? a : b);
    final maxY = (maxSpending > maxIncome ? maxSpending : maxIncome) * 1.2;

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title ?? 'Last $days Days',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  _buildLegendItem('Income', AppColors.upGreen),
                  const SizedBox(width: 16),
                  _buildLegendItem('Expenses', AppColors.downRed),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY > 0 ? maxY : 100,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surface3,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final date = chartDates[group.x.toInt()];
                      final dateStr = DateFormat('MMM d').format(date);
                      final isIncome = rodIndex == 0;
                      return BarTooltipItem(
                        '$dateStr\n${isIncome ? 'Income' : 'Expense'}: ${MpesaConstants.currencySymbol}${rod.toY.toStringAsFixed(0)}',
                        GoogleFonts.ibmPlexMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isIncome
                              ? AppColors.upGreen
                              : AppColors.downRed,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= chartDates.length) {
                          return const SizedBox();
                        }
                        final date = chartDates[value.toInt()];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('E').format(date),
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${MpesaConstants.currencySymbol}${value.toInt()}',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                          ),
                        );
                      },
                      reservedSize: 50,
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 4 : 25,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(color: AppColors.divider, strokeWidth: 1);
                  },
                ),
                barGroups: chartDates.asMap().entries.map((entry) {
                  final index = entry.key;
                  final date = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: dailyIncome[date] ?? 0,
                        color: AppColors.upGreen,
                        width: 12,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(2),
                          topRight: Radius.circular(2),
                        ),
                      ),
                      BarChartRodData(
                        toY: dailySpending[date] ?? 0,
                        color: AppColors.downRed,
                        width: 12,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(2),
                          topRight: Radius.circular(2),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
