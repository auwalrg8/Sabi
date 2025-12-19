// Minimal models required by the added P2P screens

enum MerchantProfileTab { info, ads, feedback }

class MerchantVerification {
  final String name;
  MerchantVerification({required this.name});
}

class MerchantStats {
  final int trades30d;
  final double completionRate;
  final Duration avgReleaseTime;
  final double totalVolume;
  final String volumeCurrency;
  final int positiveFeedback;
  final int negativeFeedback;
  final double rating;

  MerchantStats({
    required this.trades30d,
    required this.completionRate,
    required this.avgReleaseTime,
    required this.totalVolume,
    this.volumeCurrency = 'NGN',
    this.positiveFeedback = 0,
    this.negativeFeedback = 0,
    this.rating = 100.0,
  });
}

class MerchantAd {
  final String id;
  final String merchantName;
  final String? merchantAvatar;
  final double pricePerBtc;
  final double minAmount;
  final double maxAmount;
  final double merchantRating;
  final int merchantTrades;
  final String paymentMethod;
  final Duration paymentWindow;
  final double satsPerFiat;

  MerchantAd({
    required this.id,
    required this.merchantName,
    this.merchantAvatar,
    required this.pricePerBtc,
    required this.minAmount,
    required this.maxAmount,
    this.merchantRating = 100.0,
    this.merchantTrades = 0,
    this.paymentMethod = 'Bank',
    this.paymentWindow = const Duration(minutes: 15),
    this.satsPerFiat = 0.0,
  });
}

class MerchantProfile {
  final String id;
  final String name;
  final String? avatar;
  final List<MerchantVerification> verifications;
  final MerchantStats stats;
  final List<MerchantAd> ads;
  final List<MerchantFeedback> feedbacks;
  final DateTime joinedAt;
  final int daysToFirstTrade;

  MerchantProfile({
    required this.id,
    required this.name,
    this.avatar,
    required this.verifications,
    required this.stats,
    required this.ads,
    required this.feedbacks,
    required this.joinedAt,
    this.daysToFirstTrade = 0,
  });
}

class MerchantFeedback {
  final String fromUserName;
  final String? fromUserAvatar;
  final bool isPositive;
  final String? comment;
  final DateTime createdAt;

  MerchantFeedback({
    required this.fromUserName,
    this.fromUserAvatar,
    this.isPositive = true,
    this.comment,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

enum TradeStatus { created, awaitingPayment, paid, releasingSoon, completed, cancelled, disputed }
enum TradeType { buy, sell }

class Trade {
  final String id;
  final String counterpartyId;
  final String counterpartyName;
  final String? counterpartyAvatar;
  final double fiatAmount;
  final double satsAmount;
  final TradeStatus status;
  final DateTime createdAt;
  final Duration? timeLeft;
  final TradeType type;

  Trade({
    required this.id,
    required this.counterpartyId,
    required this.counterpartyName,
    this.counterpartyAvatar,
    required this.fiatAmount,
    required this.satsAmount,
    this.status = TradeStatus.created,
    DateTime? createdAt,
    this.timeLeft,
    this.type = TradeType.buy,
  }) : createdAt = createdAt ?? DateTime.now();
}

enum TradeHistoryFilter { all, completed, cancelled, disputed }
