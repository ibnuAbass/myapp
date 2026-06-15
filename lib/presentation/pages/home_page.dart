import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/mpesa_constants.dart';
import '../../data/models/transaction.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';
import '../widgets/balance_hero.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/spending_chart.dart';

class HomePage extends StatelessWidget {
  final VoidCallback? onViewAllTransactions;

  const HomePage({super.key, this.onViewAllTransactions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(
          'M-PESA Tracker',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: AppColors.textPrimary),
            tooltip: 'Sync SMS',
            onPressed: () {
              context.read<TransactionBloc>().add(const ReadSmsFromDevice());
            },
          ),
        ],
      ),
      body: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, state) {
          if (state is TransactionLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brandYellow),
            );
          }

          if (state is TransactionError) {
            return _buildErrorState(context, state.message);
          }

          if (state is SmsPermissionDenied) {
            return _buildPermissionDeniedState(context);
          }

          if (state is TransactionLoaded) {
            if (state.transactions.isEmpty) {
              return _buildEmptyState(context, state.hasSmsPermission);
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<TransactionBloc>().add(
                  const RefreshTransactions(),
                );
              },
              color: AppColors.brandYellow,
              backgroundColor: AppColors.surface1,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (state.newTransactionsCount > 0)
                    _buildNewTransactionsBanner(state.newTransactionsCount),
                  BalanceHero(
                    balance: state.currentBalance,
                    totalIncome: state.totalIncome,
                    totalExpenses: state.totalExpenses,
                  ),
                  const SizedBox(height: 20),
                  SpendingChart(
                    dailySpending: state.dailySpending,
                    dailyIncome: state.dailyIncome,
                    days: 7,
                  ),
                  const SizedBox(height: 20),
                  _buildRecentTransactionsHeader(context),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: state.transactions.take(5).map((transaction) {
                        return TransactionTile(
                          transaction: transaction,
                          onTap: () =>
                              _showTransactionDetails(context, transaction),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          }

          return _buildEmptyState(context, false);
        },
      ),
    );
  }

  Widget _buildNewTransactionsBanner(int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.upGreen.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.upGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count new transaction${count == 1 ? '' : 's'} imported',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.upGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.downRed),
            const SizedBox(height: 16),
            Text(
              'Error loading transactions',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.read<TransactionBloc>().add(const LoadTransactions());
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.sms_failed_outlined,
                size: 64,
                color: AppColors.downRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SMS Permission Required',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We need access to SMS from ${MpesaConstants.mpesaSender} to read your M-PESA transactions. Your data stays on your device.',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<TransactionBloc>().add(const ReadSmsFromDevice());
                },
                icon: const Icon(Icons.security),
                label: const Text('Grant Permission'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool hasSmsPermission) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                hasSmsPermission ? Icons.inbox_outlined : Icons.sms_outlined,
                size: 64,
                color: hasSmsPermission
                    ? AppColors.textSecondary
                    : AppColors.brandYellow,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasSmsPermission
                  ? 'No M-PESA Messages Found'
                  : 'SMS Access Required',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSmsPermission
                  ? 'No M-PESA transactions were found in your SMS inbox from ${MpesaConstants.mpesaSender}. Make sure you have M-PESA confirmation messages saved on this device.'
                  : 'This app reads M-PESA confirmation SMS from ${MpesaConstants.mpesaSender} to track your spending. Grant SMS permission to continue.',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<TransactionBloc>().add(
                    const ReadSmsFromDevice(),
                  );
                },
                icon: Icon(hasSmsPermission ? Icons.refresh : Icons.sms),
                label: Text(
                  hasSmsPermission ? 'Scan SMS Inbox Again' : 'Grant SMS Permission',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Transactions',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        TextButton(
          onPressed: onViewAllTransactions,
          child: Text(
            'View All',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.brandYellow,
            ),
          ),
        ),
      ],
    );
  }

  void _showTransactionDetails(
    BuildContext context,
    MpesaTransaction transaction,
  ) {
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
              if (transaction.balance != null)
                _buildDetailRow(
                  'Balance After',
                  '${MpesaConstants.currencySymbol}${transaction.balance!.toStringAsFixed(2)}',
                ),
              if (transaction.transactionCost != null &&
                  transaction.transactionCost! > 0)
                _buildDetailRow(
                  'Transaction Cost',
                  '${MpesaConstants.currencySymbol}${transaction.transactionCost!.toStringAsFixed(2)}',
                ),
              _buildDetailRow('Transaction ID', transaction.transactionId),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
}
