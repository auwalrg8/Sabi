import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/features/cash/domain/models/cash_transaction.dart';

class CashState {
  final bool isBuying;
  final double selectedAmount;
  final double btcPrice;
  final double buyRate;
  final double sellRate;
  final String? currentReference;
  final List<CashTransaction> transactions;
  final bool isProcessing;
  final String? bankName;
  final String? accountNumber;
  final String? accountName;

  CashState({
    this.isBuying = true,
    this.selectedAmount = 0,
    this.btcPrice = 162397475,
    this.buyRate = 1618,
    this.sellRate = 1598,
    this.currentReference,
    this.transactions = const [],
    this.isProcessing = false,
    this.bankName,
    this.accountNumber,
    this.accountName,
  });

  CashState copyWith({
    bool? isBuying,
    double? selectedAmount,
    double? btcPrice,
    double? buyRate,
    double? sellRate,
    String? currentReference,
    List<CashTransaction>? transactions,
    bool? isProcessing,
    String? bankName,
    String? accountNumber,
    String? accountName,
  }) {
    return CashState(
      isBuying: isBuying ?? this.isBuying,
      selectedAmount: selectedAmount ?? this.selectedAmount,
      btcPrice: btcPrice ?? this.btcPrice,
      buyRate: buyRate ?? this.buyRate,
      sellRate: sellRate ?? this.sellRate,
      currentReference: currentReference ?? this.currentReference,
      transactions: transactions ?? this.transactions,
      isProcessing: isProcessing ?? this.isProcessing,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
    );
  }

  double get fee {
    return (selectedAmount * 0.006) + 100;
  }

  double get totalToPay {
    if (isBuying) {
      return selectedAmount + fee;
    } else {
      return selectedAmount;
    }
  }

  double get amountToReceive {
    if (isBuying) {
      return selectedAmount;
    } else {
      return selectedAmount - fee;
    }
  }

  int get estimatedSats {
    if (selectedAmount == 0) return 0;
    if (isBuying) {
      return ((selectedAmount / buyRate) * 100000000).round();
    } else {
      return ((selectedAmount / sellRate) * 100000000).round();
    }
  }

  int get bitcoinToSell {
    if (selectedAmount == 0) return 0;
    return ((selectedAmount / sellRate) * 100000000).round();
  }
}

class CashNotifier extends StateNotifier<CashState> {
  CashNotifier() : super(CashState()) {
    _loadMockTransactions();
  }

  void toggleBuySell(bool isBuying) {
    state = state.copyWith(isBuying: isBuying, selectedAmount: 0);
  }

  void setAmount(double amount) {
    state = state.copyWith(selectedAmount: amount);
  }

  void refreshPrice() {
    final variation = (state.btcPrice * 0.001);
    state = state.copyWith(
      btcPrice: state.btcPrice + variation,
      buyRate: state.buyRate + (variation / 100000),
      sellRate: state.sellRate + (variation / 100000),
    );
  }

  void setBankAccount({
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) {
    state = state.copyWith(
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
    );
  }

  String generateReference() {
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    final prefix = state.isBuying ? 'BUY' : 'SELL';
    final ref = 'SAB-$prefix-${random.toRadixString(36).toUpperCase()}';
    state = state.copyWith(currentReference: ref);
    return ref;
  }

  Future<void> processPayment() async {
    state = state.copyWith(isProcessing: true);
    await Future.delayed(const Duration(seconds: 3));

    final transaction = CashTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: state.isBuying ? CashTransactionType.buy : CashTransactionType.sell,
      amountNGN: state.selectedAmount,
      amountSats: state.estimatedSats,
      timestamp: DateTime.now(),
      reference: state.currentReference,
    );

    state = state.copyWith(
      transactions: [transaction, ...state.transactions],
      isProcessing: false,
      selectedAmount: 0,
      currentReference: null,
    );
  }

  void _loadMockTransactions() {
    final mockTransactions = [
      CashTransaction(
        id: '1',
        type: CashTransactionType.buy,
        amountNGN: 100700,
        amountSats: 61700,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        reference: 'SAB-BUY-1A2B3C',
      ),
      CashTransaction(
        id: '2',
        type: CashTransactionType.sell,
        amountNGN: 79500,
        amountSats: 50000,
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
        reference: 'SAB-SELL-4D5E6F',
      ),
      CashTransaction(
        id: '3',
        type: CashTransactionType.buy,
        amountNGN: 195000,
        amountSats: 120000,
        timestamp: DateTime(2024, 11, 18, 16, 45),
        reference: 'SAB-BUY-7G8H9I',
      ),
    ];

    state = state.copyWith(transactions: mockTransactions);
  }
}

final cashProvider = StateNotifierProvider<CashNotifier, CashState>((ref) {
  return CashNotifier();
});
