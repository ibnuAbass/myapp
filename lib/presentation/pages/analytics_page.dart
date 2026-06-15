import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/mpesa_constants.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../main.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_state.dart';
import '../widgets/spending_chart.dart';
import '../widgets/category_chart.dart';
import '../widgets/transaction_tile.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late DateTime _selectedMonth;
  final _repository = getIt<TransactionRepository>();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(
          'Analytics',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, state) {
          if (state is TransactionLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brandYellow),
            );
          }

          if (state is TransactionLoaded) {
            if (state.transactions.isEmpty) {
              return _buildEmptyState('Sync M-PESA SMS messages to see analytics');
            }

            final selectableMonths = _repository.getSelectableMonths(
              state.transactions,
            );
            if (selectableMonths.isEmpty) {
              return _buildEmptyState('No transactions available for analytics');
            }

            if (!_monthIsSelectable(_selectedMonth, selectableMonths)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _selectedMonth = selectableMonths.first);
                }
              });
            }

            final month = _monthIsSelectable(_selectedMonth, selectableMonths)
                ? _selectedMonth
                : selectableMonths.first;

            final monthTransactions = _repository.filterByMonth(
              state.transactions,
              month.year,
              month.month,
            );

            if (monthTransactions.isEmpty) {
              return Column(
                children: [
                  _buildMonthSelector(selectableMonths),
                  Expanded(
                    child: _buildEmptyState(
                      'No transactions in ${_formatMonthYear(month)}',
                    ),
                  ),
                ],
              );
            }

            final monthIncome = _repository.getTotalIncome(monthTransactions);
            final monthExpenses = _repository.getTotalExpenses(monthTransactions);
            final monthNet = monthIncome - monthExpenses;
            final spendingByCounterparty = _repository.getSpendingByCounterparty(
              monthTransactions,
            );
            final incomeByCounterparty = _repository.getIncomeByCounterparty(
              monthTransactions,
            );
            final dailySpending = _repository.getDailySpendingForMonth(
              monthTransactions,
              month.year,
              month.month,
            );
            final dailyIncome = _repository.getDailyIncomeForMonth(
              monthTransactions,
              month.year,
              month.month,
            );

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildMonthSelector(selectableMonths),
                const SizedBox(height: 16),
                _buildSummaryCards(monthIncome, monthExpenses),
                const SizedBox(height: 20),
                SpendingChart(
                  dailySpending: dailySpending,
                  dailyIncome: dailyIncome,
                  title: _formatMonthYear(month),
                  useAllDates: true,
                ),
                const SizedBox(height: 20),
                CategoryChart(
                  title: 'Where You Spend Most',
                  data: spendingByCounterparty,
                  emptyMessage: 'No spending data for this month',
                ),
                const SizedBox(height: 20),
                _buildCounterpartyRankings(
                  title: 'Top Spending',
                  subtitle: 'Tap an item to see all transactions',
                  entries: spendingByCounterparty,
                  amountColor: AppColors.downRed,
                  progressColor: AppColors.brandYellow,
                  totalLabel: 'monthly spending',
                  monthTransactions: monthTransactions,
                  expense: true,
                ),
                const SizedBox(height: 20),
                _buildCounterpartyRankings(
                  title: 'Top Income',
                  subtitle: 'Tap an item to see all transactions',
                  entries: incomeByCounterparty,
                  amountColor: AppColors.upGreen,
                  progressColor: AppColors.upGreen,
                  totalLabel: 'monthly income',
                  monthTransactions: monthTransactions,
                  expense: false,
                ),
                const SizedBox(height: 20),
                _buildMonthOverview(
                  monthTransactions.length,
                  monthNet,
                ),
              ],
            );
          }

          return _buildEmptyState('Sync M-PESA SMS messages to see analytics');
        },
      ),
    );
  }

  bool _monthIsSelectable(DateTime month, List<DateTime> selectable) {
    return selectable.any(
      (m) => m.year == month.year && m.month == month.month,
    );
  }

  Widget _buildMonthSelector(List<DateTime> selectableMonths) {
    final currentIndex = selectableMonths.indexWhere(
      (m) => m.year == _selectedMonth.year && m.month == _selectedMonth.month,
    );
    final canGoNewer = currentIndex > 0;
    final canGoOlder = currentIndex >= 0 && currentIndex < selectableMonths.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: canGoOlder
                ? () => setState(() {
                    _selectedMonth = selectableMonths[currentIndex + 1];
                  })
                : null,
            icon: Icon(
              Icons.chevron_left,
              color: canGoOlder ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _showMonthPicker(selectableMonths),
              child: Column(
                children: [
                  Text(
                    _formatMonthYear(_selectedMonth),
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Tap to pick a month',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: canGoNewer
                ? () => setState(() {
                    _selectedMonth = selectableMonths[currentIndex - 1];
                  })
                : null,
            icon: Icon(
              Icons.chevron_right,
              color: canGoNewer ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  void _showMonthPicker(List<DateTime> months) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Month',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: months.length,
                  itemBuilder: (context, index) {
                    final month = months[index];
                    final isSelected =
                        month.year == _selectedMonth.year &&
                        month.month == _selectedMonth.month;

                    return ListTile(
                      onTap: () {
                        setState(() => _selectedMonth = month);
                        Navigator.pop(context);
                      },
                      title: Text(
                        _formatMonthYear(month),
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? AppColors.brandYellow
                              : AppColors.textPrimary,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check,
                              color: AppColors.brandYellow,
                              size: 20,
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSummaryCards(double monthIncome, double monthExpenses) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Income',
            monthIncome,
            AppColors.upGreen,
            Icons.arrow_downward,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Expenses',
            monthExpenses,
            AppColors.downRed,
            Icons.arrow_upward,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${MpesaConstants.currencySymbol}${amount.toStringAsFixed(2)}',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterpartyRankings({
    required String title,
    required String subtitle,
    required Map<String, double> entries,
    required Color amountColor,
    required Color progressColor,
    required String totalLabel,
    required List<MpesaTransaction> monthTransactions,
    required bool expense,
  }) {
    final sorted = entries.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty) return const SizedBox.shrink();

    final total = sorted.fold(0.0, (sum, e) => sum + e.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...sorted.take(5).map((entry) {
            final percentage = (entry.value / total) * 100;
            return InkWell(
              onTap: () => _showCounterpartyTransactions(
                counterparty: entry.key,
                totalAmount: entry.value,
                monthTransactions: monthTransactions,
                expense: expense,
              ),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${MpesaConstants.currencySymbol}${entry.value.toStringAsFixed(2)}',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: amountColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: AppColors.surface3,
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${percentage.toStringAsFixed(1)}% of $totalLabel',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showCounterpartyTransactions({
    required String counterparty,
    required double totalAmount,
    required List<MpesaTransaction> monthTransactions,
    required bool expense,
  }) {
    final transactions = _repository.getTransactionsForCounterparty(
      monthTransactions,
      counterparty,
      expense: expense,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        counterparty,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${transactions.length} transaction${transactions.length == 1 ? '' : 's'} · ${MpesaConstants.currencySymbol}${totalAmount.toStringAsFixed(2)} in ${_formatMonthYear(_selectedMonth)}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TransactionTile(
                          transaction: transaction,
                          onTap: () => _showTransactionDetail(transaction),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTransactionDetail(MpesaTransaction transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Transaction Details',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Type', transaction.type.displayName),
              _buildDetailRow('Amount', transaction.displayAmount),
              _buildDetailRow('Party', transaction.displayParty),
              _buildDetailRow(
                'Date',
                DateFormat('MMM d, yyyy · h:mm a').format(transaction.dateTime),
              ),
              if (transaction.transactionCost != null &&
                  transaction.transactionCost! > 0)
                _buildDetailRow(
                  'Fee',
                  '${MpesaConstants.currencySymbol}${transaction.transactionCost!.toStringAsFixed(2)}',
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  transaction.rawMessage,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthOverview(int transactionCount, double monthNet) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Net Flow',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${monthNet >= 0 ? '+' : '-'}${MpesaConstants.currencySymbol}${monthNet.abs().toStringAsFixed(2)}',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: monthNet >= 0 ? AppColors.upGreen : AppColors.downRed,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$transactionCount transaction${transactionCount == 1 ? '' : 's'}',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMonthYear(DateTime month) {
    return DateFormat('MMMM yyyy').format(month);
  }
}
