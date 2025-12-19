class MerchantModel {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isVerified;
  final bool isNostrVerified;
  final int trades30d;
  final double completionRate;
  final int avgReleaseMinutes;
  final double totalVolume;
  final int positiveFeedback;
  final int negativeFeedback;
  final DateTime joinedDate;
  final DateTime? firstTradeDate;

  MerchantModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isVerified = false,
    this.isNostrVerified = false,
    required this.trades30d,
    required this.completionRate,
    required this.avgReleaseMinutes,
    required this.totalVolume,
    this.positiveFeedback = 0,
    this.negativeFeedback = 0,
    required this.joinedDate,
    this.firstTradeDate,
  });

  double get rating => positiveFeedback + negativeFeedback > 0
      ? (positiveFeedback / (positiveFeedback + negativeFeedback)) * 100
      : 100.0;

  int get totalTrades => positiveFeedback + negativeFeedback;
}
