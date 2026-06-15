import 'package:equatable/equatable.dart';

abstract class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

class LoadTransactions extends TransactionEvent {
  const LoadTransactions();
}

class RefreshTransactions extends TransactionEvent {
  const RefreshTransactions();
}

class ImportSampleTransactions extends TransactionEvent {
  const ImportSampleTransactions();
}

class ClearAllTransactions extends TransactionEvent {
  const ClearAllTransactions();
}

class ReadSmsFromDevice extends TransactionEvent {
  const ReadSmsFromDevice();
}

class CheckSmsPermission extends TransactionEvent {
  const CheckSmsPermission();
}
