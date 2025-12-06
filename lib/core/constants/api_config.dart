class ApiConfig {
  // Toggle during development
  static const bool isDev = true;

  // Rust backend (Nodeless Spark) - Base URL selection
  static final String baseUrl = isDev ? 'http://localhost:3000' : 'https://api.sabi.money';
}

class ApiEndpoints {
  static const String walletCreate = '/api/v1/wallets/create';
  static String walletByUser(String userId) => '/api/v1/wallets/$userId';
  static const String rates = '/api/v1/rates';
  static const String healthBreez = '/api/v1/health/breez';
}
