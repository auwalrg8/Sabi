/// Hodl Hodl API Data Models
/// Based on the Hodl Hodl API v1 documentation

/// Trader information
class HodlHodlTrader {
  final String login;
  final String onlineStatus;
  final double? rating;
  final int tradesCount;
  final String url;
  final bool verified;
  final String? verifiedBy;
  final bool strongHodler;
  final String country;
  final String countryCode;
  final int? averagePaymentTimeMinutes;
  final int? averageReleaseTimeMinutes;
  final int? daysSinceLastTrade;
  final int blockedBy;

  HodlHodlTrader({
    required this.login,
    required this.onlineStatus,
    this.rating,
    required this.tradesCount,
    required this.url,
    required this.verified,
    this.verifiedBy,
    required this.strongHodler,
    required this.country,
    required this.countryCode,
    this.averagePaymentTimeMinutes,
    this.averageReleaseTimeMinutes,
    this.daysSinceLastTrade,
    required this.blockedBy,
  });

  factory HodlHodlTrader.fromJson(Map<String, dynamic> json) {
    return HodlHodlTrader(
      login: json['login'] ?? '',
      onlineStatus: json['online_status'] ?? 'offline',
      rating: json['rating'] != null ? double.tryParse(json['rating'].toString()) : null,
      tradesCount: json['trades_count'] ?? 0,
      url: json['url'] ?? '',
      verified: json['verified'] ?? false,
      verifiedBy: json['verified_by'],
      strongHodler: json['strong_hodler'] ?? false,
      country: json['country'] ?? '',
      countryCode: json['country_code'] ?? '',
      averagePaymentTimeMinutes: json['average_payment_time_minutes'],
      averageReleaseTimeMinutes: json['average_release_time_minutes'],
      daysSinceLastTrade: json['days_since_last_trade'],
      blockedBy: json['blocked_by'] ?? 0,
    );
  }
}

/// Payment method instruction
class HodlHodlPaymentMethodInstruction {
  final String id;
  final String version;
  final String paymentMethodId;
  final String paymentMethodType;
  final String paymentMethodName;
  final String? details;

  HodlHodlPaymentMethodInstruction({
    required this.id,
    required this.version,
    required this.paymentMethodId,
    required this.paymentMethodType,
    required this.paymentMethodName,
    this.details,
  });

  factory HodlHodlPaymentMethodInstruction.fromJson(Map<String, dynamic> json) {
    return HodlHodlPaymentMethodInstruction(
      id: json['id']?.toString() ?? '',
      version: json['version'] ?? '',
      paymentMethodId: json['payment_method_id']?.toString() ?? '',
      paymentMethodType: json['payment_method_type'] ?? '',
      paymentMethodName: json['payment_method_name'] ?? '',
      details: json['details'],
    );
  }
}

/// Fee breakdown
class HodlHodlFee {
  final String authorFeeRate;
  final String intermediaryFeeRate;
  final String yourFeeRate;
  final String transactionFee;
  final String exchangeFeePercent;

  HodlHodlFee({
    required this.authorFeeRate,
    required this.intermediaryFeeRate,
    required this.yourFeeRate,
    required this.transactionFee,
    required this.exchangeFeePercent,
  });

  factory HodlHodlFee.fromJson(Map<String, dynamic> json) {
    return HodlHodlFee(
      authorFeeRate: json['author_fee_rate'] ?? '0',
      intermediaryFeeRate: json['intermediary_fee_rate'] ?? '0',
      yourFeeRate: json['your_fee_rate'] ?? '0',
      transactionFee: json['transaction_fee'] ?? '0',
      exchangeFeePercent: json['exchange_fee_percent'] ?? '0',
    );
  }
}

/// Offer from Hodl Hodl marketplace
class HodlHodlOffer {
  final String id;
  final String version;
  final String assetCode;
  final bool searchable;
  final String country;
  final String countryCode;
  final bool workingNow;
  final String side; // 'buy' or 'sell'
  final String? title;
  final String? description;
  final String currencyCode;
  final String price;
  final String amountSource;
  final String minAmount;
  final String maxAmount;
  final String? firstTradeLimit;
  final String? balance;
  final String? minAmountSats;
  final String? maxAmountSats;
  final HodlHodlFee fee;
  final int paymentWindowMinutes;
  final int confirmations;
  final List<HodlHodlPaymentMethodInstruction> paymentMethodInstructions;
  final HodlHodlTrader trader;

  HodlHodlOffer({
    required this.id,
    required this.version,
    required this.assetCode,
    required this.searchable,
    required this.country,
    required this.countryCode,
    required this.workingNow,
    required this.side,
    this.title,
    this.description,
    required this.currencyCode,
    required this.price,
    required this.amountSource,
    required this.minAmount,
    required this.maxAmount,
    this.firstTradeLimit,
    this.balance,
    this.minAmountSats,
    this.maxAmountSats,
    required this.fee,
    required this.paymentWindowMinutes,
    required this.confirmations,
    required this.paymentMethodInstructions,
    required this.trader,
  });

  factory HodlHodlOffer.fromJson(Map<String, dynamic> json) {
    return HodlHodlOffer(
      id: json['id'] ?? '',
      version: json['version'] ?? '',
      assetCode: json['asset_code'] ?? 'BTC',
      searchable: json['searchable'] ?? true,
      country: json['country'] ?? '',
      countryCode: json['country_code'] ?? '',
      workingNow: json['working_now'] ?? false,
      side: json['side'] ?? 'sell',
      title: json['title'],
      description: json['description'],
      currencyCode: json['currency_code'] ?? '',
      price: json['price'] ?? '0',
      amountSource: json['amount_source'] ?? 'fiat',
      minAmount: json['min_amount'] ?? '0',
      maxAmount: json['max_amount'] ?? '0',
      firstTradeLimit: json['first_trade_limit'],
      balance: json['balance'],
      minAmountSats: json['min_amount_sats'],
      maxAmountSats: json['max_amount_sats'],
      fee: HodlHodlFee.fromJson(json['fee'] ?? {}),
      paymentWindowMinutes: json['payment_window_minutes'] ?? 60,
      confirmations: json['confirmations'] ?? 1,
      paymentMethodInstructions: (json['payment_method_instructions'] as List<dynamic>?)
              ?.map((e) => HodlHodlPaymentMethodInstruction.fromJson(e))
              .toList() ??
          [],
      trader: HodlHodlTrader.fromJson(json['trader'] ?? {}),
    );
  }

  /// Returns the primary payment method name
  String get primaryPaymentMethod {
    if (paymentMethodInstructions.isNotEmpty) {
      return paymentMethodInstructions.first.paymentMethodName;
    }
    return 'Unknown';
  }
}

/// Escrow information for a contract
class HodlHodlEscrow {
  final String? address;
  final String? witnessScript;
  final int index;
  final bool youConfirmed;
  final bool counterpartyConfirmed;
  final int confirmations;
  final String? amountDeposited;
  final String? amountReleased;
  final String? depositTransactionId;
  final String? releaseTransactionId;

  HodlHodlEscrow({
    this.address,
    this.witnessScript,
    required this.index,
    required this.youConfirmed,
    required this.counterpartyConfirmed,
    required this.confirmations,
    this.amountDeposited,
    this.amountReleased,
    this.depositTransactionId,
    this.releaseTransactionId,
  });

  factory HodlHodlEscrow.fromJson(Map<String, dynamic> json) {
    return HodlHodlEscrow(
      address: json['address'],
      witnessScript: json['witness_script'],
      index: json['index'] ?? 0,
      youConfirmed: json['you_confirmed'] ?? false,
      counterpartyConfirmed: json['counterparty_confirmed'] ?? false,
      confirmations: json['confirmations'] ?? 0,
      amountDeposited: json['amount_deposited'],
      amountReleased: json['amount_released'],
      depositTransactionId: json['deposit_transaction_id'],
      releaseTransactionId: json['release_transaction_id'],
    );
  }
}

/// Volume breakdown for a contract
class HodlHodlVolumeBreakdown {
  final String volumeWithFee;
  final String goesToSeller;
  final String goesToBuyer;
  final String exchangeFee;
  final String exchangeFeeInFiat;
  final String exchangeFeePercent;
  final String transactionFee;
  final String transactionFeeInFiat;

  HodlHodlVolumeBreakdown({
    required this.volumeWithFee,
    required this.goesToSeller,
    required this.goesToBuyer,
    required this.exchangeFee,
    required this.exchangeFeeInFiat,
    required this.exchangeFeePercent,
    required this.transactionFee,
    required this.transactionFeeInFiat,
  });

  factory HodlHodlVolumeBreakdown.fromJson(Map<String, dynamic> json) {
    return HodlHodlVolumeBreakdown(
      volumeWithFee: json['volume_with_fee'] ?? '0',
      goesToSeller: json['goes_to_seller'] ?? '0',
      goesToBuyer: json['goes_to_buyer'] ?? '0',
      exchangeFee: json['exchange_fee'] ?? '0',
      exchangeFeeInFiat: json['exchange_fee_in_fiat'] ?? '0',
      exchangeFeePercent: json['exchange_fee_percent'] ?? '0',
      transactionFee: json['transaction_fee'] ?? '0',
      transactionFeeInFiat: json['transaction_fee_in_fiat'] ?? '0',
    );
  }
}

/// Payment method instruction in contract
class HodlHodlContractPaymentInstruction {
  final String paymentMethodId;
  final String paymentMethodName;
  final String details;

  HodlHodlContractPaymentInstruction({
    required this.paymentMethodId,
    required this.paymentMethodName,
    required this.details,
  });

  factory HodlHodlContractPaymentInstruction.fromJson(Map<String, dynamic> json) {
    return HodlHodlContractPaymentInstruction(
      paymentMethodId: json['payment_method_id']?.toString() ?? '',
      paymentMethodName: json['payment_method_name'] ?? '',
      details: json['details'] ?? '',
    );
  }
}

/// Contract/trade on Hodl Hodl
class HodlHodlContract {
  final String id;
  final String yourRole; // 'buyer' or 'seller'
  final bool canBeCanceled;
  final String offerId;
  final String price;
  final String value; // fiat value
  final String currencyCode;
  final String volume; // BTC amount
  final String assetCode;
  final String? comment;
  final bool currentUserHasUnreleasedFunds;
  final String? releaseAddress;
  final int confirmations;
  final int? paymentWindowTimeLeftSeconds;
  final int? paymentTimeMinutes;
  final int paymentWindowMinutes;
  final int depositingWindowMinutes;
  final int? depositingWindowTimeLeftSeconds;
  final String status; // pending, depositing, in_progress, paid, completed, canceled, disputed, resolved
  final String? disputeStatus;
  final HodlHodlContractPaymentInstruction? paymentMethodInstruction;
  final HodlHodlVolumeBreakdown volumeBreakdown;
  final String country;
  final String countryCode;
  final String createdAt;
  final HodlHodlTrader counterparty;
  final HodlHodlEscrow escrow;

  HodlHodlContract({
    required this.id,
    required this.yourRole,
    required this.canBeCanceled,
    required this.offerId,
    required this.price,
    required this.value,
    required this.currencyCode,
    required this.volume,
    required this.assetCode,
    this.comment,
    required this.currentUserHasUnreleasedFunds,
    this.releaseAddress,
    required this.confirmations,
    this.paymentWindowTimeLeftSeconds,
    this.paymentTimeMinutes,
    required this.paymentWindowMinutes,
    required this.depositingWindowMinutes,
    this.depositingWindowTimeLeftSeconds,
    required this.status,
    this.disputeStatus,
    this.paymentMethodInstruction,
    required this.volumeBreakdown,
    required this.country,
    required this.countryCode,
    required this.createdAt,
    required this.counterparty,
    required this.escrow,
  });

  factory HodlHodlContract.fromJson(Map<String, dynamic> json) {
    return HodlHodlContract(
      id: json['id'] ?? '',
      yourRole: json['your_role'] ?? 'buyer',
      canBeCanceled: json['can_be_canceled'] ?? false,
      offerId: json['offer_id'] ?? '',
      price: json['price'] ?? '0',
      value: json['value'] ?? '0',
      currencyCode: json['currency_code'] ?? '',
      volume: json['volume'] ?? '0',
      assetCode: json['asset_code'] ?? 'BTC',
      comment: json['comment'],
      currentUserHasUnreleasedFunds: json['current_user_has_unreleased_funds'] ?? false,
      releaseAddress: json['release_address'],
      confirmations: json['confirmations'] ?? 0,
      paymentWindowTimeLeftSeconds: json['payment_window_time_left_seconds'],
      paymentTimeMinutes: json['payment_time_minutes'],
      paymentWindowMinutes: json['payment_window_minutes'] ?? 60,
      depositingWindowMinutes: json['depositing_window_minutes'] ?? 30,
      depositingWindowTimeLeftSeconds: json['depositing_window_time_left_seconds'],
      status: json['status'] ?? 'pending',
      disputeStatus: json['dispute_status'],
      paymentMethodInstruction: json['payment_method_instruction'] != null
          ? HodlHodlContractPaymentInstruction.fromJson(json['payment_method_instruction'])
          : null,
      volumeBreakdown: HodlHodlVolumeBreakdown.fromJson(json['volume_breakdown'] ?? {}),
      country: json['country'] ?? '',
      countryCode: json['country_code'] ?? '',
      createdAt: json['created_at'] ?? '',
      counterparty: HodlHodlTrader.fromJson(json['counterparty'] ?? {}),
      escrow: HodlHodlEscrow.fromJson(json['escrow'] ?? {}),
    );
  }

  /// Get human-readable status
  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending Confirmation';
      case 'depositing':
        return 'Awaiting Deposit';
      case 'in_progress':
        return 'In Progress';
      case 'paid':
        return 'Payment Sent';
      case 'completed':
        return 'Completed';
      case 'canceled':
        return 'Canceled';
      case 'disputed':
        return 'Disputed';
      case 'resolved':
        return 'Resolved';
      default:
        return status;
    }
  }

  /// Check if buyer can mark as paid
  bool get canMarkAsPaid => yourRole == 'buyer' && status == 'in_progress';

  /// Check if seller can release funds
  bool get canReleaseFunds => yourRole == 'seller' && status == 'paid';
}

/// Chat message in a contract
class HodlHodlChatMessage {
  final String text;
  final String author;
  final bool fromAdmin;
  final String sentAt;

  HodlHodlChatMessage({
    required this.text,
    required this.author,
    required this.fromAdmin,
    required this.sentAt,
  });

  factory HodlHodlChatMessage.fromJson(Map<String, dynamic> json) {
    return HodlHodlChatMessage(
      text: json['text'] ?? '',
      author: json['author'] ?? '',
      fromAdmin: json['from_admin'] ?? false,
      sentAt: json['sent_at'] ?? '',
    );
  }
}

/// API response wrapper
class HodlHodlApiResponse<T> {
  final String status;
  final T? data;
  final String? errorCode;
  final String? message;

  HodlHodlApiResponse({
    required this.status,
    this.data,
    this.errorCode,
    this.message,
  });

  bool get isSuccess => status == 'success';
  bool get isError => status == 'error';
}
