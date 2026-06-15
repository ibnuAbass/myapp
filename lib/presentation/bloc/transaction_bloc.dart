import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/services/sms_service.dart';
import 'transaction_event.dart';
import 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository _repository;
  final SmsService _smsService;

  TransactionBloc(this._repository, this._smsService)
    : super(const TransactionInitial()) {
    on<LoadTransactions>(_onLoadTransactions);
    on<RefreshTransactions>(_onRefreshTransactions);
    on<ImportSampleTransactions>(_onImportSampleTransactions);
    on<ClearAllTransactions>(_onClearAllTransactions);
    on<ReadSmsFromDevice>(_onReadSmsFromDevice);
    on<CheckSmsPermission>(_onCheckSmsPermission);
  }

  Future<void> _onLoadTransactions(
    LoadTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    emit(const TransactionLoading());
    try {
      if (!await _smsService.hasSmsPermission()) {
        final granted = await _smsService.requestSmsPermission();
        if (!granted) {
          emit(const SmsPermissionDenied());
          return;
        }
      }
      await _syncSmsTransactions(emit);
    } catch (e) {
      emit(TransactionError(e.toString()));
    }
  }

  Future<void> _onRefreshTransactions(
    RefreshTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      final hasPermission = await _smsService.hasSmsPermission();
      if (hasPermission) {
        await _syncSmsTransactions(emit);
        return;
      }
      final transactions = await _repository.getTransactions();
      _emitLoadedState(emit, transactions);
    } catch (e) {
      emit(TransactionError(e.toString()));
    }
  }

  Future<void> _onImportSampleTransactions(
    ImportSampleTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    emit(const TransactionLoading());
    try {
      final sampleMessages = await _smsService.loadSampleMessagesFromAsset();
      final newTransactions = await _smsService.parseMpesaMessages(
        sampleMessages,
      );
      await _mergeAndSave(newTransactions);
      final allTransactions = await _repository.getTransactions();
      _emitLoadedState(emit, allTransactions);
    } catch (e) {
      emit(TransactionError(e.toString()));
    }
  }

  Future<void> _onClearAllTransactions(
    ClearAllTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    emit(const TransactionLoading());
    try {
      await _repository.clearTransactions();
      _emitLoadedState(emit, []);
    } catch (e) {
      emit(TransactionError(e.toString()));
    }
  }

  Future<void> _onReadSmsFromDevice(
    ReadSmsFromDevice event,
    Emitter<TransactionState> emit,
  ) async {
    emit(const TransactionLoading());
    try {
      if (!await _smsService.hasSmsPermission()) {
        final granted = await _smsService.requestSmsPermission();
        if (!granted) {
          emit(const SmsPermissionDenied());
          return;
        }
      }
      await _syncSmsTransactions(emit);
    } catch (e) {
      emit(TransactionError(e.toString()));
    }
  }

  Future<void> _onCheckSmsPermission(
    CheckSmsPermission event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      final hasPermission = await _smsService.hasSmsPermission();
      final transactions = await _repository.getTransactions();
      _emitLoadedState(emit, transactions, hasSmsPermission: hasPermission);
    } catch (e) {
      emit(TransactionError(e.toString()));
    }
  }

  Future<void> _syncSmsTransactions(Emitter<TransactionState> emit) async {
    final mpesaTransactions = await _smsService.readMpesaMessages();
    final newCount = await _mergeAndSave(mpesaTransactions);
    final allTransactions = await _repository.getTransactions();
    _emitLoadedState(
      emit,
      allTransactions,
      hasSmsPermission: true,
      newTransactionsCount: newCount,
    );
  }

  Future<int> _mergeAndSave(List<MpesaTransaction> incoming) async {
    final existing = await _repository.getTransactions();
    final existingIds = existing.map((t) => t.transactionId).toSet();
    final unique = incoming
        .where((t) => t.transactionId.isNotEmpty && !existingIds.contains(t.transactionId))
        .toList();

    if (unique.isNotEmpty) {
      await _repository.saveTransactions([...existing, ...unique]);
    }
    return unique.length;
  }

  void _emitLoadedState(
    Emitter<TransactionState> emit,
    List<MpesaTransaction> transactions, {
    bool hasSmsPermission = false,
    int newTransactionsCount = 0,
  }) {
    final trackable = _repository.getTrackableTransactions(transactions);

    emit(
      TransactionLoaded(
        transactions: trackable,
        totalIncome: _repository.getTotalIncome(trackable),
        totalExpenses: _repository.getTotalExpenses(trackable),
        currentBalance: _repository.getCurrentBalance(transactions),
        spendingByCounterparty: _repository.getSpendingByCounterparty(
          trackable,
        ),
        incomeByCounterparty: _repository.getIncomeByCounterparty(trackable),
        dailySpending: _repository.getDailySpending(trackable),
        dailyIncome: _repository.getDailyIncome(trackable),
        hasSmsPermission: hasSmsPermission,
        newTransactionsCount: newTransactionsCount,
      ),
    );
  }
}
