import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mpesa_tracker2/core/constants/mpesa_constants.dart';
import 'package:mpesa_tracker2/data/models/transaction.dart';
import 'package:mpesa_tracker2/data/repositories/transaction_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TransactionRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = TransactionRepository(prefs);
  });

  MpesaTransaction expense({
    required TransactionType type,
    required double amount,
    String? recipientName,
    String? businessName,
  }) {
    return MpesaTransaction(
      id: '1',
      type: type,
      amount: amount,
      recipientName: recipientName,
      businessName: businessName,
      dateTime: DateTime(2022, 9, 18),
      rawMessage: 'test',
      transactionId: 'TX${amount.toInt()}',
    );
  }

  MpesaTransaction income({
    required double amount,
    String? senderName,
    String? businessName,
  }) {
    return MpesaTransaction(
      id: '2',
      type: TransactionType.received,
      amount: amount,
      senderName: senderName,
      businessName: businessName,
      dateTime: DateTime(2022, 9, 18),
      rawMessage: 'test',
      transactionId: 'IN${amount.toInt()}',
    );
  }

  test('groups spending by counterparty names', () {
    final transactions = [
      expense(type: TransactionType.sent, amount: 75, recipientName: 'John Doe'),
      expense(type: TransactionType.sent, amount: 125, recipientName: 'JOHN DOE'),
      expense(type: TransactionType.paybill, amount: 950, businessName: 'High Enterp.'),
      expense(type: TransactionType.withdrawal, amount: 500, businessName: 'Taco Restaurant'),
    ];

    final spending = repository.getSpendingByCounterparty(transactions);

    expect(spending['John Doe'], 200);
    expect(spending['High Enterp.'], 950);
    expect(spending['Taco Restaurant'], 500);
  });

  test('groups income by sender names', () {
    final transactions = [
      income(amount: 130, senderName: 'JOHN DOE'),
      income(amount: 200, senderName: 'John Doe'),
      income(amount: 2270, businessName: 'GERMAN Inv BRANCH'),
    ];

    final incomeByParty = repository.getIncomeByCounterparty(transactions);

    expect(incomeByParty['John Doe'], 330);
    expect(incomeByParty['German Inv Branch'], 2270);
  });

  test('filters analytics by month', () {
    final transactions = [
      expense(
        type: TransactionType.sent,
        amount: 100,
        recipientName: 'John Doe',
      ).copyWithDate(DateTime(2022, 9, 18)),
      expense(
        type: TransactionType.sent,
        amount: 200,
        recipientName: 'John Doe',
      ).copyWithDate(DateTime(2022, 8, 10)),
    ];

    final september = repository.filterByMonth(transactions, 2022, 9);
    final spending = repository.getSpendingByCounterparty(september);

    expect(september.length, 1);
    expect(spending['John Doe'], 100);
  });

  test('finds transactions for a counterparty', () {
    final transactions = [
      expense(type: TransactionType.sent, amount: 75, recipientName: 'John Doe'),
      expense(type: TransactionType.sent, amount: 125, recipientName: 'JOHN DOE'),
      expense(type: TransactionType.paybill, amount: 950, businessName: 'High Enterp.'),
    ];

    final johnTxns = repository.getTransactionsForCounterparty(
      transactions,
      'John Doe',
      expense: true,
    );

    expect(johnTxns.length, 2);
    expect(johnTxns.every((t) => t.isExpense), isTrue);
  });

  test('includes paybill-via-sent in spending by counterparty', () {
    final transactions = [
      expense(
        type: TransactionType.paybill,
        amount: 3500,
        businessName: 'Madrid Hotel',
      ),
    ];

    final spending = repository.getSpendingByCounterparty(transactions);
    expect(spending['Madrid Hotel'], 3500);
  });

  test('extracts counterparty from raw message when fields missing', () {
    final transaction = MpesaTransaction(
      id: '1',
      type: TransactionType.sent,
      amount: 3500,
      dateTime: DateTime(2026, 6, 11),
      rawMessage:
          'UFB287R9IB Confirmed. Ksh3,500.00 sent to Madrid Hotel for account TTMZ7PDFHK on 11/6/26 at 7:41 AM',
      transactionId: 'UFB287R9IB',
    );

    expect(transaction.counterparty, 'Madrid Hotel');
  });
}

extension _TestTransaction on MpesaTransaction {
  MpesaTransaction copyWithDate(DateTime dateTime) {
    return MpesaTransaction(
      id: id,
      type: type,
      amount: amount,
      senderName: senderName,
      senderPhone: senderPhone,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      businessName: businessName,
      businessNumber: businessNumber,
      balance: balance,
      transactionCost: transactionCost,
      dateTime: dateTime,
      rawMessage: rawMessage,
      transactionId: transactionId,
    );
  }
}
