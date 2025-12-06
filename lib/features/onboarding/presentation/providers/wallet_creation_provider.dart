// lib/features/onboarding/presentation/providers/wallet_creation_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WalletCreationState {
  final bool isLoading;
  final String? errorMessage;

  WalletCreationState({this.isLoading = false, this.errorMessage});

  WalletCreationState copyWith({
    bool? isLoading,
    String? errorMessage,
  }) {
    return WalletCreationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class WalletCreationNotifier extends StateNotifier<WalletCreationState> {
  WalletCreationNotifier() : super(WalletCreationState());

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void setError(String? message) {
    state = state.copyWith(errorMessage: message, isLoading: false);
  }
}

final walletCreationProvider = StateNotifierProvider<WalletCreationNotifier, WalletCreationState>((ref) {
  return WalletCreationNotifier();
});
