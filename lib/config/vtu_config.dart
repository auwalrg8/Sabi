import 'vtu_config.local.dart' as vtu_local;

/// VTU Configuration
///
/// Credentials are stored in vtu_config.local.dart (gitignored)
/// to prevent exposure in the open-source repository.
///
/// VTU.ng API v2 uses JWT authentication:
/// - Token expires after 7 days
/// - Only the latest token remains active
/// - Obtain new token before every request or at least weekly
class VtuConfig {
  VtuConfig._();

  /// VTU.ng API base URL for v2
  static const String baseUrl = 'https://vtu.ng/wp-json';

  /// VTU.ng Auth URL for JWT tokens
  static const String authUrl = 'https://vtu.ng/wp-json/jwt-auth/v1/token';

  /// VTU.ng API v2 URL
  static const String apiV2Url = 'https://vtu.ng/wp-json/api/v2';

  /// VTU.ng API email (from local config) - for JWT authentication
  static String get email => vtu_local.vtuEmail;

  /// VTU.ng API password (from local config)
  static String get password => vtu_local.vtuPassword;

  /// Agent's Lightning Address for receiving payments
  static String get lightningAddress => vtu_local.agentLightningAddress;

  /// Markup percentage on VTU prices (agent profit margin)
  static const double markupPercentage = 0.02; // 2%

  /// Minimum order amount in Naira
  static const double minOrderAmount = 50.0;

  /// Maximum order amount in Naira
  static const double maxOrderAmount = 50000.0;

  /// Token expiry duration (refresh before this)
  static const Duration tokenExpiry = Duration(days: 7);

  /// Token refresh buffer (refresh this much before expiry)
  static const Duration tokenRefreshBuffer = Duration(hours: 6);
}
