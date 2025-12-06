import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/models/transaction.dart';

part 'wallet_provider.g.dart';

@riverpod
class WalletNotifier extends _$WalletNotifier {
  @override
  WalletState build() => WalletState(
    balanceBtc: 0.005, // Mock – replace with real wallet API
    balanceNgn: 15000.0,
    transactions: [
      Transaction(
        id: '1',
        type: 'receive',
        amountBtc: 0.001,
        amountNgn: 2500.0,
        counterparty: 'Auwal Abubakar',
        date: DateTime.now().subtract(const Duration(hours: 2)),
        icon: 'assets/icons/receive.png',
      ),
      Transaction(
        id: '2',
        type: 'send',
        amountBtc: 0.002,
        amountNgn: 5000.0,
        counterparty: '+234 803 456 7890',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'pending',
        icon: 'assets/icons/send.png',
      ),
      // Add more mocks from Figma (5-10 transactions)
    ],
  );

  void updateBalance(double btc, double ngn) =>
      state = state.copyWith(balanceBtc: btc, balanceNgn: ngn);

  void addTransaction(Transaction tx) =>
      state = state.copyWith(transactions: [...state.transactions, tx]);
}

class WalletState {
  final double balanceBtc;
  final double balanceNgn;
  final List<Transaction> transactions;

  const WalletState({
    required this.balanceBtc,
    required this.balanceNgn,
    required this.transactions,
  });

  WalletState copyWith({
    double? balanceBtc,
    double? balanceNgn,
    List<Transaction>? transactions,
  }) => WalletState(
    balanceBtc: balanceBtc ?? this.balanceBtc,
    balanceNgn: balanceNgn ?? this.balanceNgn,
    transactions: transactions ?? this.transactions,
  );
}
