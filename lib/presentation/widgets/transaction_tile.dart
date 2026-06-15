import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/mpesa_constants.dart';
import '../../data/models/transaction.dart';

class TransactionTile extends StatelessWidget {
  final MpesaTransaction transaction;
  final VoidCallback? onTap;

  const TransactionTile({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final amountColor = isIncome ? AppColors.upGreen : AppColors.downRed;
    final dateFormat = DateFormat('MMM d, h:mm a');

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getIconBgColor(transaction.type),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIcon(transaction.type),
                size: 20,
                color: _getIconColor(transaction.type),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.type.displayName,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.displayParty,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateFormat.format(transaction.dateTime),
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}${transaction.displayAmount}',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
                ),
                if (transaction.transactionCost != null &&
                    transaction.transactionCost! > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Fee: ${MpesaConstants.currencySymbol}${transaction.transactionCost!.toStringAsFixed(2)}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(TransactionType type) {
    switch (type) {
      case TransactionType.received:
        return Icons.arrow_downward;
      case TransactionType.sent:
        return Icons.arrow_upward;
      case TransactionType.withdrawal:
        return Icons.account_balance_wallet;
      case TransactionType.deposit:
        return Icons.add_circle;
      case TransactionType.airtime:
        return Icons.phone_android;
      case TransactionType.paybill:
        return Icons.receipt_long;
      case TransactionType.till:
        return Icons.store;
      case TransactionType.balanceCheck:
        return Icons.account_balance;
      case TransactionType.failed:
        return Icons.error;
      case TransactionType.reversal:
        return Icons.undo;
      case TransactionType.unknown:
        return Icons.help;
    }
  }

  Color _getIconBgColor(TransactionType type) {
    switch (type) {
      case TransactionType.received:
      case TransactionType.deposit:
      case TransactionType.reversal:
        return AppColors.upGreen.withValues(alpha: 0.14);
      case TransactionType.sent:
      case TransactionType.withdrawal:
      case TransactionType.airtime:
      case TransactionType.paybill:
      case TransactionType.till:
        return AppColors.downRed.withValues(alpha: 0.14);
      case TransactionType.balanceCheck:
      case TransactionType.failed:
      case TransactionType.unknown:
        return AppColors.surface3;
    }
  }

  Color _getIconColor(TransactionType type) {
    switch (type) {
      case TransactionType.received:
      case TransactionType.deposit:
      case TransactionType.reversal:
        return AppColors.upGreen;
      case TransactionType.sent:
      case TransactionType.withdrawal:
      case TransactionType.airtime:
      case TransactionType.paybill:
      case TransactionType.till:
        return AppColors.downRed;
      case TransactionType.balanceCheck:
      case TransactionType.failed:
      case TransactionType.unknown:
        return AppColors.textSecondary;
    }
  }
}
