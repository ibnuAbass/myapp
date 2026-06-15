import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../../core/constants/mpesa_constants.dart';

class TransactionRepository {
  static const String _transactionsKey = 'mpesa_transactions_v2';
  final SharedPreferences _prefs;

  TransactionRepository(this._prefs);

  Future<List<MpesaTransaction>> getTransactions() async {
    final data = _prefs.getString(_transactionsKey);
    if (data == null) return [];

    final jsonList = json.decode(data) as List<dynamic>;
    return jsonList
        .map((e) => MpesaTransaction.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  Future<void> saveTransactions(List<MpesaTransaction> transactions) async {
    final data = json.encode(transactions.map((e) => e.toJson()).toList());
    await _prefs.setString(_transactionsKey, data);
  }

  Future<void> clearTransactions() async {
    await _prefs.remove(_transactionsKey);
  }

  double getTotalIncome(List<MpesaTransaction> transactions) {
    return transactions
        .where((t) => t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getTotalExpenses(List<MpesaTransaction> transactions) {
    return transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount + (t.transactionCost ?? 0));
  }

  List<MpesaTransaction> filterByMonth(
    List<MpesaTransaction> transactions,
    int year,
    int month,
  ) {
    return transactions
        .where((t) => t.dateTime.year == year && t.dateTime.month == month)
        .toList();
  }

  DateTime? getEarliestMonth(List<MpesaTransaction> transactions) {
    if (transactions.isEmpty) return null;
    final earliest = transactions.reduce(
      (a, b) => a.dateTime.isBefore(b.dateTime) ? a : b,
    );
    return DateTime(earliest.dateTime.year, earliest.dateTime.month);
  }

  List<DateTime> getSelectableMonths(List<MpesaTransaction> transactions) {
    final earliest = getEarliestMonth(transactions);
    if (earliest == null) return [];

    final now = DateTime.now();
    final months = <DateTime>[];
    var current = DateTime(earliest.year, earliest.month);
    final end = DateTime(now.year, now.month);

    while (!current.isAfter(end)) {
      months.add(current);
      current = DateTime(current.year, current.month + 1);
    }
    return months.reversed.toList();
  }

  List<MpesaTransaction> getTransactionsForCounterparty(
    List<MpesaTransaction> transactions,
    String counterpartyLabel, {
    required bool expense,
  }) {
    return transactions
        .where((t) {
          if (expense && !t.isExpense) return false;
          if (!expense && !t.isIncome) return false;
          return t.matchesCounterpartyLabel(counterpartyLabel);
        })
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  Map<DateTime, double> getDailySpendingForMonth(
    List<MpesaTransaction> transactions,
    int year,
    int month,
  ) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final daily = <DateTime, double>{};
    for (int day = 1; day <= daysInMonth; day++) {
      daily[DateTime(year, month, day)] = 0;
    }

    for (final t in transactions.where((t) => t.isExpense)) {
      if (t.dateTime.year != year || t.dateTime.month != month) continue;
      final date = DateTime(year, month, t.dateTime.day);
      daily[date] = daily[date]! + t.amount + (t.transactionCost ?? 0);
    }
    return daily;
  }

  Map<DateTime, double> getDailyIncomeForMonth(
    List<MpesaTransaction> transactions,
    int year,
    int month,
  ) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final daily = <DateTime, double>{};
    for (int day = 1; day <= daysInMonth; day++) {
      daily[DateTime(year, month, day)] = 0;
    }

    for (final t in transactions.where((t) => t.isIncome)) {
      if (t.dateTime.year != year || t.dateTime.month != month) continue;
      final date = DateTime(year, month, t.dateTime.day);
      daily[date] = daily[date]! + t.amount;
    }
    return daily;
  }

  Map<String, double> getSpendingByCounterparty(
    List<MpesaTransaction> transactions,
  ) {
    return _aggregateByCounterparty(
      transactions,
      (t) => t.isExpense,
      (t) => t.amount + (t.transactionCost ?? 0),
    );
  }

  Map<String, double> getIncomeByCounterparty(
    List<MpesaTransaction> transactions,
  ) {
    return _aggregateByCounterparty(
      transactions,
      (t) => t.isIncome,
      (t) => t.amount,
    );
  }

  Map<String, double> _aggregateByCounterparty(
    List<MpesaTransaction> transactions,
    bool Function(MpesaTransaction) include,
    double Function(MpesaTransaction) amountFor,
  ) {
    final totals = <String, double>{};
    final labels = <String, String>{};

    for (final t in transactions.where(include)) {
      final party = t.counterparty;
      if (party == null) continue;

      final key = party.trim().toUpperCase();
      labels.putIfAbsent(key, () => t.counterpartyDisplay);
      totals[key] = (totals[key] ?? 0) + amountFor(t);
    }

    return {for (final entry in totals.entries) labels[entry.key]!: entry.value};
  }

  Map<DateTime, double> getDailySpending(
    List<MpesaTransaction> transactions, {
    int days = 30,
  }) {
    final daily = <DateTime, double>{};
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      daily[date] = 0;
    }

    for (final t in transactions.where((t) => t.isExpense)) {
      final date = DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day);
      if (daily.containsKey(date)) {
        daily[date] = daily[date]! + t.amount + (t.transactionCost ?? 0);
      }
    }
    return daily;
  }

  Map<DateTime, double> getDailyIncome(
    List<MpesaTransaction> transactions, {
    int days = 30,
  }) {
    final daily = <DateTime, double>{};
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      daily[date] = 0;
    }

    for (final t in transactions.where((t) => t.isIncome)) {
      final date = DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day);
      if (daily.containsKey(date)) {
        daily[date] = daily[date]! + t.amount;
      }
    }
    return daily;
  }

  double getCurrentBalance(List<MpesaTransaction> transactions) {
    final sorted = List<MpesaTransaction>.from(transactions)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    for (final t in sorted) {
      if (t.balance != null) return t.balance!;
    }
    return 0;
  }

  List<MpesaTransaction> getTrackableTransactions(
    List<MpesaTransaction> transactions,
  ) {
    return transactions
        .where(
          (t) =>
              t.type != TransactionType.balanceCheck &&
              t.type != TransactionType.failed &&
              t.type != TransactionType.unknown,
        )
        .toList();
  }
}
