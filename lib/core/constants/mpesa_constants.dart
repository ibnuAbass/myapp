class MpesaConstants {
  static const String mpesaSender = 'MPESA';
  static const String currencySymbol = 'Ksh';
  static const String currencyCode = 'KES';
  static const String sampleAssetPath = 'assets/message-samples.txt';
}

enum TransactionType {
  received,
  sent,
  withdrawal,
  deposit,
  airtime,
  paybill,
  till,
  balanceCheck,
  failed,
  reversal,
  unknown,
}

extension TransactionTypeExtension on TransactionType {
  String get displayName {
    switch (this) {
      case TransactionType.received:
        return 'Received';
      case TransactionType.sent:
        return 'Sent';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.deposit:
        return 'Deposit';
      case TransactionType.airtime:
        return 'Airtime';
      case TransactionType.paybill:
        return 'Paybill';
      case TransactionType.till:
        return 'Till';
      case TransactionType.balanceCheck:
        return 'Balance Check';
      case TransactionType.failed:
        return 'Failed';
      case TransactionType.reversal:
        return 'Reversal';
      case TransactionType.unknown:
        return 'Unknown';
    }
  }
}
