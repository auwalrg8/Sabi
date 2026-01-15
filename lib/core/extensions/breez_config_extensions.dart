import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';

/// Extension to add copyWith method to Config for easier API key injection
/// Based on Breez SDK Spark Flutter documentation pattern
extension ConfigCopyWith on Config {
  Config copyWith({
    String? apiKey,
    Network? network,
    int? syncIntervalSecs,
    MaxFee? maxDepositClaimFee,
    OptimizationConfig? optimizationConfig,
    String? lnurlDomain,
    bool? preferSparkOverLightning,
    List<ExternalInputParser>? externalInputParsers,
    bool? useDefaultExternalInputParsers,
    String? realTimeSyncServerUrl,
    bool? privateEnabledDefault,
  }) {
    return Config(
      apiKey: apiKey ?? this.apiKey,
      network: network ?? this.network,
      syncIntervalSecs: syncIntervalSecs ?? this.syncIntervalSecs,
      maxDepositClaimFee: maxDepositClaimFee ?? this.maxDepositClaimFee,
      optimizationConfig: optimizationConfig ?? this.optimizationConfig,
      lnurlDomain: lnurlDomain ?? this.lnurlDomain,
      preferSparkOverLightning:
          preferSparkOverLightning ?? this.preferSparkOverLightning,
      externalInputParsers: externalInputParsers ?? this.externalInputParsers,
      useDefaultExternalInputParsers:
          useDefaultExternalInputParsers ?? this.useDefaultExternalInputParsers,
      realTimeSyncServerUrl:
          realTimeSyncServerUrl ?? this.realTimeSyncServerUrl,
      privateEnabledDefault:
          privateEnabledDefault ?? this.privateEnabledDefault,
    );
  }
}
