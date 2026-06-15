import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../../core/constants/mpesa_constants.dart';

class SmsService {
  static const _uuid = Uuid();
  static const MethodChannel _channel = MethodChannel('com.mpesatracker2/sms');

  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<bool> hasSmsPermission() async {
    return Permission.sms.isGranted;
  }

  Future<List<MpesaTransaction>> readMpesaMessages() async {
    if (!await hasSmsPermission()) {
      final granted = await requestSmsPermission();
      if (!granted) return [];
    }

    try {
      final List<dynamic>? messages = await _channel.invokeMethod('readSms');
      if (messages == null || messages.isEmpty) return [];

      final mpesaTransactions = <MpesaTransaction>[];
      for (final msg in messages) {
        if (msg is! Map) continue;

        final address = (msg['address'] as String? ?? '').toUpperCase();
        final body = msg['body'] as String? ?? '';
        final dateMs = msg['date'] as int?;

        if (!_isFromMpesaSender(address) &&
            !body.toUpperCase().contains('M-PESA')) {
          continue;
        }

        final transaction = _parseMessage(
          body,
          dateMs != null ? DateTime.fromMillisecondsSinceEpoch(dateMs) : null,
        );
        if (transaction != null) {
          mpesaTransactions.add(transaction);
        }
      }
      return mpesaTransactions;
    } catch (_) {
      return [];
    }
  }

  bool _isFromMpesaSender(String address) {
    final normalized = address.replaceAll('-', '').replaceAll(' ', '');
    return normalized == MpesaConstants.mpesaSender ||
        normalized.contains('MPESA') ||
        normalized == '234700';
  }

  Future<List<MpesaTransaction>> parseMpesaMessages(
    List<String> messages,
  ) async {
    final transactions = <MpesaTransaction>[];
    for (final message in messages) {
      final transaction = _parseMessage(message, null);
      if (transaction != null) transactions.add(transaction);
    }
    return transactions;
  }

  Future<List<String>> loadSampleMessagesFromAsset() async {
    final content = await rootBundle.loadString(MpesaConstants.sampleAssetPath);
    return _extractMessagesFromSampleFile(content);
  }

  List<String> _extractMessagesFromSampleFile(String content) {
    final messages = <String>[];
    final buffer = StringBuffer();

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('--CATEGORY=')) {
        if (buffer.isNotEmpty) {
          final msg = _cleanSampleMessage(buffer.toString());
          if (msg.isNotEmpty) messages.add(msg);
          buffer.clear();
        }
        continue;
      }
      if (trimmed.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(trimmed);
    }

    if (buffer.isNotEmpty) {
      final msg = _cleanSampleMessage(buffer.toString());
      if (msg.isNotEmpty) messages.add(msg);
    }

    return messages;
  }

  String _cleanSampleMessage(String raw) {
    var message = raw.trim();
    if (message.startsWith('{') && message.contains('":"')) {
      final match = RegExp(r'":"(.+)$').firstMatch(message);
      if (match != null) {
        message = match.group(1) ?? message;
        if (message.endsWith('"')) {
          message = message.substring(0, message.length - 1);
        }
      }
    }
    return message.trim();
  }

  MpesaTransaction? _parseMessage(String message, [DateTime? fallbackDate]) {
    final trimmedMessage = _cleanSampleMessage(message.trim());
    if (trimmedMessage.isEmpty) return null;

    final lower = trimmedMessage.toLowerCase();

    TransactionType type = TransactionType.unknown;
    double amount = 0;
    String? senderName;
    String? senderPhone;
    String? recipientName;
    String? recipientPhone;
    String? businessName;
    String? businessNumber;
    double? balance;
    double? transactionCost;
    DateTime? dateTime;
    var transactionId = '';

    final idMatch = RegExp(
      r'^([A-Z0-9]+)',
      caseSensitive: false,
    ).firstMatch(trimmedMessage);
    if (idMatch != null) {
      transactionId = (idMatch.group(1) ?? '').toUpperCase();
    }

    if (lower.contains('your account balance was')) {
      type = TransactionType.balanceCheck;
      balance = _parseAmount(trimmedMessage, r'Ksh([\d,]+\.?\d*)');
      dateTime = _parseDate(trimmedMessage);
    } else if (lower.contains('you have received')) {
      type = TransactionType.received;
      amount = _parseAmount(trimmedMessage, r'received Ksh([\d,]+\.?\d*)') ?? 0;
      final senderMatch = RegExp(
        r'from\s+([A-Z\s]+?)\s+([\d\*]{9,12})',
        caseSensitive: false,
      ).firstMatch(trimmedMessage);
      if (senderMatch != null) {
        senderName = senderMatch.group(1)?.trim();
        senderPhone = senderMatch.group(2);
      }
      balance = _parseAmount(
        trimmedMessage,
        r'New M-PESA balance is Ksh([\d,]+\.?\d*)',
      );
      dateTime = _parseDate(trimmedMessage);
    } else if (lower.contains('withdraw ksh')) {
      type = TransactionType.withdrawal;
      amount = _parseAmount(trimmedMessage, r'Withdraw Ksh([\d,]+\.?\d*)') ?? 0;
      final agentMatch = RegExp(
        r'from\s+(\d+)\s*-\s*(.+?)(?:New M-PESA|$)',
        caseSensitive: false,
      ).firstMatch(trimmedMessage);
      if (agentMatch != null) {
        businessNumber = agentMatch.group(1);
        businessName = agentMatch.group(2)?.trim();
      }
      transactionCost = _parseAmount(
        trimmedMessage,
        r'Transaction cost, Ksh([\d,]+\.?\d*)',
      );
      balance = _parseAmount(
        trimmedMessage,
        r'New M-PESA balance is Ksh([\d,]+\.?\d*)',
      );
      dateTime = _parseDate(trimmedMessage);
    } else if (lower.contains('sent to safaricom offers') ||
        lower.contains('for account tunukiwa')) {
      type = TransactionType.airtime;
      amount = _parseAmount(trimmedMessage, r'Ksh([\d,]+\.?\d*)\s*sent') ?? 0;
      businessName = 'Safaricom Offers';
      balance = _parseAmount(
        trimmedMessage,
        r'New M-PESA balance is Ksh([\d,]+\.?\d*)',
      );
      dateTime = _parseDate(trimmedMessage);
    } else if (lower.contains('give ksh') && lower.contains('cash to')) {
      type = TransactionType.deposit;
      amount = _parseAmount(trimmedMessage, r'Give Ksh([\d,]+\.?\d*)') ?? 0;
      final businessMatch = RegExp(
        r'cash to\s+(.+?)(?:New M-PESA|$)',
        caseSensitive: false,
      ).firstMatch(trimmedMessage);
      businessName = businessMatch?.group(1)?.trim();
      balance = _parseAmount(
        trimmedMessage,
        r'New M-PESA balance is Ksh([\d,]+\.?\d*)',
      );
      dateTime = _parseDate(trimmedMessage);
    } else if (lower.contains('reversal') || lower.contains('reversed')) {
      type = TransactionType.reversal;
      amount =
          _parseAmount(trimmedMessage, r'Ksh([\d,]+\.?\d*)\s+is credited') ?? 0;
      balance = _parseAmount(trimmedMessage, r'balance is Ksh([\d,]+\.?\d*)');
      dateTime = _parseDate(trimmedMessage);
    } else if (lower.contains('paid to')) {
      type = lower.contains('pay to pochi')
          ? TransactionType.till
          : TransactionType.paybill;
      amount = _parseAmount(trimmedMessage, r'Ksh([\d,]+\.?\d*)\s*paid') ?? 0;
      final businessMatch = RegExp(
        r'paid to\s+(.+?)\s+on',
        caseSensitive: false,
      ).firstMatch(trimmedMessage);
      businessName = businessMatch?.group(1)?.trim();
      transactionCost = _parseAmount(
        trimmedMessage,
        r'Transaction cost, Ksh([\d,]+\.?\d*)',
      );
      balance = _parseAmount(
        trimmedMessage,
        r'New M-PESA balance is Ksh([\d,]+\.?\d*)',
      );
      dateTime = _parseDate(trimmedMessage);
    } else if (lower.contains('sent to') && lower.contains('for account')) {
      type = TransactionType.paybill;
      amount = _parseAmount(trimmedMessage, r'Ksh([\d,]+\.?\d*)\s*sent') ?? 0;
      final businessMatch = RegExp(
        r'sent to\s+(.+?)\s+for account\s+(\S+)',
        caseSensitive: false,
      ).firstMatch(trimmedMessage);
      if (businessMatch != null) {
        businessName = businessMatch.group(1)?.trim();
        businessNumber = businessMatch.group(2);
      }
      transactionCost = _parseAmount(
        trimmedMessage,
        r'Transaction cost, Ksh([\d,]+\.?\d*)',
      );
      balance = _parseAmount(
        trimmedMessage,
        r'New M-PESA balance is Ksh([\d,]+\.?\d*)',
      );
      dateTime = _parseDate(trimmedMessage);
    } else if (lower.contains('sent to') && !lower.contains('paid to')) {
      type = TransactionType.sent;
      amount = _parseAmount(trimmedMessage, r'Ksh([\d,]+\.?\d*)\s*sent') ?? 0;
      final recipientMatch = RegExp(
        r'sent to\s+([A-Za-z\s]+?)\s+([\d\*]{9,12})',
        caseSensitive: false,
      ).firstMatch(trimmedMessage);
      if (recipientMatch != null) {
        recipientName = recipientMatch.group(1)?.trim();
        recipientPhone = recipientMatch.group(2);
      }
      transactionCost = _parseAmount(
        trimmedMessage,
        r'Transaction cost, Ksh([\d,]+\.?\d*)',
      );
      balance = _parseAmount(
        trimmedMessage,
        r'New M-PESA balance is Ksh([\d,]+\.?\d*)',
      );
      dateTime = _parseDate(trimmedMessage);
    } else if (lower.contains('failed') &&
        lower.contains('not have enough money')) {
      type = TransactionType.failed;
      amount = _parseAmount(trimmedMessage, r'pay Ksh([\d,]+\.?\d*)') ?? 0;
      balance = _parseAmount(trimmedMessage, r'balance is Ksh([\d,]+\.?\d*)');
    } else if (lower.contains('wrong pin')) {
      type = TransactionType.failed;
    }

    if (type == TransactionType.unknown) return null;

    return MpesaTransaction(
      id: _uuid.v4(),
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
      dateTime: dateTime ?? fallbackDate ?? DateTime.now(),
      rawMessage: trimmedMessage,
      transactionId: transactionId,
    );
  }

  double? _parseAmount(String message, String pattern) {
    final match = RegExp(pattern, caseSensitive: false).firstMatch(message);
    if (match == null) return null;
    final str = match.group(1)?.replaceAll(',', '') ?? '0';
    return double.tryParse(str);
  }

  DateTime? _parseDate(String message) {
    final pattern = RegExp(
      r'(\d{1,2})/(\d{1,2})/(\d{2,4})\s+at\s+(\d{1,2}):(\d{2})\s*(AM|PM)?',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(message);
    if (match == null) return null;

    try {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final yearStr = match.group(3)!;
      final year = yearStr.length == 2
          ? 2000 + int.parse(yearStr)
          : int.parse(yearStr);
      var hour = int.parse(match.group(4)!);
      final minute = int.parse(match.group(5)!);
      final period = match.group(6)?.toUpperCase();

      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }
}
