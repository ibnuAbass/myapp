import 'package:equatable/equatable.dart';
import '../../data/models/transaction.dart';

abstract class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object?> get props => [];
}

class TransactionInitial extends TransactionState {
  const TransactionInitial();
}

class TransactionLoading extends TransactionState {
  const TransactionLoading();
}

class TransactionLoaded extends TransactionState {
  final List<MpesaTransaction> transactions;
  final double totalIncome;
  final double totalExpenses;
  final double currentBalance;
  final Map<String, double> spendingByCounterparty;
  final Map<String, double> incomeByCounterparty;
  final Map<DateTime, double> dailySpending;
  final Map<DateTime, double> dailyIncome;
  final bool hasSmsPermission;
  final int newTransactionsCount;

  const TransactionLoaded({
    required this.transactions,
    required this.totalIncome,
    required this.totalExpenses,
    required this.currentBalance,
    required this.spendingByCounterparty,
    required this.incomeByCounterparty,
    required this.dailySpending,
    required this.dailyIncome,
    this.hasSmsPermission = false,
    this.newTransactionsCount = 0,
  });

  @override
  List<Object?> get props => [
    transactions,
    totalIncome,
    totalExpenses,
    currentBalance,
    spendingByCounterparty,
    incomeByCounterparty,
    dailySpending,
    dailyIncome,
    hasSmsPermission,
    newTransactionsCount,
  ];
}

class SmsPermissionDenied extends TransactionState {
  const SmsPermissionDenied();
}

class TransactionError extends TransactionState {
  final String message;

  const TransactionError(this.message);

  @override
  List<Object?> get props => [message];
}
