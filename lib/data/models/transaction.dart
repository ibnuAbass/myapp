import 'package:equatable/equatable.dart';
import '../../core/constants/mpesa_constants.dart';

class MpesaTransaction extends Equatable {
  final String id;
  final TransactionType type;
  final double amount;
  final String? senderName;
  final String? senderPhone;
  final String? recipientName;
  final String? recipientPhone;
  final String? businessName;
  final String? businessNumber;
  final double? balance;
  final double? transactionCost;
  final DateTime dateTime;
  final String rawMessage;
  final String transactionId;

  const MpesaTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.senderName,
    this.senderPhone,
    this.recipientName,
    this.recipientPhone,
    this.businessName,
    this.businessNumber,
    this.balance,
    this.transactionCost,
    required this.dateTime,
    required this.rawMessage,
    required this.transactionId,
  });

  bool get isIncome =>
      type == TransactionType.received ||
      type == TransactionType.deposit ||
      type == TransactionType.reversal;

  bool get isExpense =>
      type == TransactionType.sent ||
      type == TransactionType.withdrawal ||
      type == TransactionType.airtime ||
      type == TransactionType.paybill ||
      type == TransactionType.till;

  String get displayAmount =>
      '${MpesaConstants.currencySymbol}${amount.toStringAsFixed(2)}';

  String? get counterparty {
    if (isExpense) {
      return _firstNonEmpty([
            recipientName,
            businessName,
            recipientPhone,
            businessNumber,
          ]) ??
          _extractPartyFromRawMessage(isExpense: true);
    }
    if (isIncome) {
      return _firstNonEmpty([senderName, businessName, senderPhone]) ??
          _extractPartyFromRawMessage(isExpense: false);
    }
    return null;
  }

  String? _extractPartyFromRawMessage({required bool isExpense}) {
    if (isExpense) {
      final paybillViaSent = RegExp(
        r'sent to\s+(.+?)\s+for account\s+(\S+)',
        caseSensitive: false,
      ).firstMatch(rawMessage);
      if (paybillViaSent != null) {
        return paybillViaSent.group(1)?.trim();
      }

      final paidTo = RegExp(
        r'paid to\s+(.+?)\s+on',
        caseSensitive: false,
      ).firstMatch(rawMessage);
      if (paidTo != null) return paidTo.group(1)?.trim();

      final sentToPhone = RegExp(
        r'sent to\s+(.+?)\s+([\d\*]{9,12})',
        caseSensitive: false,
      ).firstMatch(rawMessage);
      if (sentToPhone != null) return sentToPhone.group(1)?.trim();

      final withdraw = RegExp(
        r'Withdraw Ksh[\d,]+\.?\d*\s+from\s+\d+\s*-\s*(.+?)(?:New M-PESA|$)',
        caseSensitive: false,
      ).firstMatch(rawMessage);
      if (withdraw != null) return withdraw.group(1)?.trim();
    } else {
      final received = RegExp(
        r'received Ksh[\d,]+\.?\d*\s+from\s+(.+?)\s+[\d\*]{9,12}',
        caseSensitive: false,
      ).firstMatch(rawMessage);
      if (received != null) return received.group(1)?.trim();

      final deposit = RegExp(
        r'Give Ksh[\d,]+\.?\d*\s+cash to\s+(.+?)(?:New M-PESA|$)',
        caseSensitive: false,
      ).firstMatch(rawMessage);
      if (deposit != null) return deposit.group(1)?.trim();
    }
    return null;
  }

  String? get counterpartyKey => counterparty?.trim().toUpperCase();

  bool matchesCounterpartyLabel(String label) {
    final key = counterpartyKey;
    if (key == null) return false;
    return key == label.trim().toUpperCase();
  }

  String get counterpartyDisplay {
    final party = counterparty;
    if (party == null) return type.displayName;
    return _toTitleCase(party);
  }

  String get displayParty {
    final party = counterparty;
    if (party != null) return _toTitleCase(party);
    return type.displayName;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String _toTitleCase(String input) {
    return input
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'amount': amount,
      'senderName': senderName,
      'senderPhone': senderPhone,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'businessName': businessName,
      'businessNumber': businessNumber,
      'balance': balance,
      'transactionCost': transactionCost,
      'dateTime': dateTime.toIso8601String(),
      'rawMessage': rawMessage,
      'transactionId': transactionId,
    };
  }

  factory MpesaTransaction.fromJson(Map<String, dynamic> json) {
    return MpesaTransaction(
      id: json['id'] as String,
      type: TransactionType.values[json['type'] as int],
      amount: (json['amount'] as num).toDouble(),
      senderName: json['senderName'] as String?,
      senderPhone: json['senderPhone'] as String?,
      recipientName: json['recipientName'] as String?,
      recipientPhone: json['recipientPhone'] as String?,
      businessName: json['businessName'] as String?,
      businessNumber: json['businessNumber'] as String?,
      balance: json['balance'] != null
          ? (json['balance'] as num).toDouble()
          : null,
      transactionCost: json['transactionCost'] != null
          ? (json['transactionCost'] as num).toDouble()
          : null,
      dateTime: DateTime.parse(json['dateTime'] as String),
      rawMessage: json['rawMessage'] as String,
      transactionId: json['transactionId'] as String,
    );
  }

  @override
  List<Object?> get props => [id, type, amount, dateTime, transactionId];
}
