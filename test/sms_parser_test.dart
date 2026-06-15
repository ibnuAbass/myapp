import 'package:flutter_test/flutter_test.dart';
import 'package:mpesa_tracker2/data/services/sms_service.dart';

void main() {
  final smsService = SmsService();

  group('Mpesa SMS Parser', () {
    test('parses received money message', () async {
      const message =
          'QI72JWLX4I Confirmed.You have received Ksh130.00 from JOHN DOE 0712345678 on 7/9/22 at 5:47 PM  New M-PESA balance is Ksh1288.00.';
      final results = await smsService.parseMpesaMessages([message]);
      expect(results.length, 1);
      expect(results.first.type.name, 'received');
      expect(results.first.amount, 130.0);
      expect(results.first.senderName, 'JOHN DOE');
      expect(results.first.transactionId, 'QI72JWLX4I');
    });

    test('parses paybill message with JSON wrapper', () async {
      const message =
          '{"1548":"RFK5JGVTSR Confirmed. Ksh950.00 paid to High Enterp. on 20/6/23 at 7:09 PM.New M-PESA balance is Ksh9280.50. Transaction cost, Ksh0.00.';
      final results = await smsService.parseMpesaMessages([message]);
      expect(results.length, 1);
      expect(results.first.type.name, 'paybill');
      expect(results.first.amount, 950.0);
      expect(results.first.businessName, 'High Enterp.');
    });

    test('parses withdrawal message', () async {
      const message =
          'QI79K99I8P Confirmed.on 7/9/22 at 7:39 PMWithdraw Ksh12200.00 from 298382 - GERMAN FACE SAPS  ltd New M-PESA balance is Ksh2178.00. Transaction cost, Ksh10.00.';
      final results = await smsService.parseMpesaMessages([message]);
      expect(results.length, 1);
      expect(results.first.type.name, 'withdrawal');
      expect(results.first.amount, 12200.0);
      expect(results.first.transactionCost, 10.0);
    });

    test('parses sent to phone message', () async {
      const message =
          'QII48M7J0S Confirmed. Ksh75.00 sent to John Doe 0712345678 on 18/9/22 at 8:09 PM. New M-PESA balance is Ksh12243.00. Transaction cost, Ksh0.00.';
      final results = await smsService.parseMpesaMessages([message]);
      expect(results.length, 1);
      expect(results.first.type.name, 'sent');
      expect(results.first.recipientName, 'John Doe');
    });

    test('parses sent to business for account (paybill)', () async {
      const message =
          'UFB287R9IB Confirmed. Ksh3,500.00 sent to Madrid Hotel for account TTMZ7PDFHK on 11/6/26 at 7:41 AM New M-PESA balance is Ksh2,469.02. Transaction cost, Ksh25.00.';
      final results = await smsService.parseMpesaMessages([message]);
      expect(results.length, 1);
      expect(results.first.type.name, 'paybill');
      expect(results.first.amount, 3500.0);
      expect(results.first.businessName, 'Madrid Hotel');
      expect(results.first.businessNumber, 'TTMZ7PDFHK');
      expect(results.first.transactionCost, 25.0);
      expect(results.first.counterparty, 'Madrid Hotel');
    });

    test('parses received money message with anonymized phone', () async {
      const message =
          'UFCKH7HV5B Confirmed.You have received Ksh3,200.00 from John Doe 0713***345 on 12/6/26 at 11:44 AM  New M-PESA balance is Ksh4,077.02. Download My OneApp on https://saf.cx/lPKcC';
      final results = await smsService.parseMpesaMessages([message]);
      expect(results.length, 1);
      expect(results.first.type.name, 'received');
      expect(results.first.amount, 3200.0);
      expect(results.first.senderName, 'John Doe');
      expect(results.first.senderPhone, '0713***345');
      expect(results.first.isIncome, true);
      expect(results.first.counterparty, 'John Doe');
    });

    test('parses deposit message', () async {
      const message =
          'QJ1824QI7Q Confirmed. On 1/10/22 at 7:09 PM Give Ksh2270.00 cash to GERMAN Inv BRANCH New M-PESA balance is Ksh2270.00.';
      final results = await smsService.parseMpesaMessages([message]);
      expect(results.length, 1);
      expect(results.first.type.name, 'deposit');
      expect(results.first.amount, 2270.0);
    });

    test('parses reversal message', () async {
      const message =
          'QJC3Q7RYBX confirmed. Reversal of transaction QJC0Q7GEBQ has been successfully reversed  on 12/10/22  at 10:22 AM and Ksh60.00 is credited to your M-PESA account. New M-PESA account balance is Ksh92.00.';
      final results = await smsService.parseMpesaMessages([message]);
      expect(results.length, 1);
      expect(results.first.type.name, 'reversal');
      expect(results.first.amount, 60.0);
    });
  });
}
