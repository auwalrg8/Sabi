/// Lightning Address constants for Sabi Wallet
///
/// This file defines the domain and formatting for Lightning Addresses
/// used throughout the app for receiving payments.

/// The domain for Sabi Wallet lightning addresses.
/// Example: username@sabiwallet.xyz
const String lightningAddressDomain = 'sabiwallet.xyz';

/// Format a username into a full lightning address.
///
/// Example: formatLightningAddress('swiftfalcon42') => 'swiftfalcon42@sabiwallet.xyz'
String formatLightningAddress(String username) =>
    '$username@$lightningAddressDomain';

/// Extract username from a full lightning address.
///
/// Example: extractUsername('user@sabiwallet.xyz') => 'user'
/// Returns the full string if no @ is found.
String extractUsername(String address) {
  final atIndex = address.indexOf('@');
  if (atIndex > 0) {
    return address.substring(0, atIndex);
  }
  return address;
}

/// Check if an address belongs to Sabi Wallet domain.
bool isSabiWalletAddress(String address) {
  return address.toLowerCase().endsWith('@$lightningAddressDomain');
}
