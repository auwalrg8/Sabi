# Sabi Wallet - Complete Project Documentation

## 🌍 Overview

**Sabi Wallet** is Nigeria's first non-custodial Bitcoin + Lightning + Nostr wallet, built with a focus on the Nigerian market. The app provides seamless Bitcoin/Lightning payments with Naira balance display, social recovery (eliminating seed phrase complexity), P2P trading, and deep Nostr integration for social features.

- **Platform**: Cross-platform (Android, iOS, Windows, macOS, Linux)
- **Framework**: Flutter 3.7+
- **License**: MIT (100% Open Source)
- **Target Launch**: April 2026 (MVP), February 2026 (Kaduna closed beta)

---

## 🏗️ Architecture

### Project Structure

```
lib/
├── main.dart                    # App entry point & service initialization
├── app.dart                     # Root widget configuration
├── config/                      # App configuration (Breez API keys, etc.)
├── core/                        # Core utilities
│   ├── constants/               # Colors, lightning address formats
│   ├── models/                  # Shared data models
│   ├── services/                # Core services
│   ├── theme/                   # App theming
│   ├── utils/                   # Utility functions
│   └── widgets/                 # Reusable widgets
├── features/                    # Feature modules (Clean Architecture)
│   ├── agent/                   # Agent/merchant features
│   ├── auth/                    # Authentication (PIN, biometric)
│   ├── cash/                    # Buy/Sell BTC with Naira
│   ├── common/                  # Shared feature components
│   ├── home/                    # Home widgets & providers
│   ├── nostr/                   # Nostr social integration
│   ├── notifications/           # Push notifications
│   ├── onboarding/              # Wallet creation & recovery
│   ├── p2p/                     # Peer-to-peer trading
│   ├── profile/                 # User profile & settings
│   ├── recovery/                # Social recovery system
│   ├── vtu/                     # Virtual top-up (airtime/data)
│   ├── wallet/                  # Core wallet screens
│   └── zaps/                    # Lightning zaps
├── l10n/                        # Localization (en, ha, yo, pcm)
└── services/                    # Global services
```

### Feature Architecture Pattern

Each feature follows **Clean Architecture**:
```
feature/
├── data/           # Data sources, repositories, models
├── domain/         # Business logic, entities
├── presentation/   # UI (screens, widgets, providers)
├── providers/      # Riverpod state management
└── utils/          # Feature-specific utilities
```

---

## ⚡ Core Technologies

### 1. Breez SDK Spark (Nodeless Lightning)

The wallet uses **Breez SDK Spark** for non-custodial Lightning payments without running a full node.

```dart
// Key features in breez_spark_service.dart
class BreezSparkService {
  // Wallet initialization with BIP39 mnemonic
  static Future<void> initializeSparkSDK({String? mnemonic});
  
  // Balance management
  static Future<int> getBalance();
  static Stream<int> get balanceStream;
  
  // Payments
  static Future<Map<String, dynamic>> sendPayment(String invoice, {int? sats});
  static Future<ReceivePaymentResponse> receive(int amountSats, {String? description});
  
  // Lightning Address
  static Future<StoredLightningAddress?> registerLightningAddress(String username);
  
  // Transaction history
  static Future<List<PaymentRecord>> listPayments({int limit = 50});
}
```

### 2. Nostr Integration

Full Nostr protocol support for social features using `nostr_dart`:

```dart
// Key features in nostr_service.dart
class NostrService {
  // Key management
  static Future<String> generateNewKeys();
  static Future<String?> getNpub();
  static Future<String?> getNsec();
  
  // Social feed
  static Future<List<NostrFeedPost>> fetchGlobalFeed({int limit = 50});
  static Future<List<NostrFeedPost>> fetchFollowsFeed(String hexPubkey);
  
  // Author metadata (profiles)
  static Future<Map<String, String>> fetchAuthorMetadataDirect(String pubkey);
  
  // Zaps (NIP-57)
  static Future<void> sendZap({required String toNpub, required int amount});
  
  // Currency conversion (Naira display)
  static double satsToNaira(int sats);
  static String formatNaira(double amount);
}
```

### 3. State Management (Riverpod)

Riverpod is used throughout for reactive state management:

```dart
// Example providers
final balanceNotifierProvider = AsyncNotifierProvider<BalanceNotifier, int>();
final recentTransactionsProvider = AsyncNotifierProvider<TransactionsNotifier, List<PaymentRecord>>();
final cashProvider = StateNotifierProvider<CashNotifier, CashState>();
final p2pOffersProvider = StateNotifierProvider<P2POffersNotifier, List<P2POffer>>();
```

---

## 📱 Key Features

### 1. Wallet Home Screen

**Location**: `lib/features/wallet/presentation/screens/home_screen.dart`

- **Balance display** in Naira (tap to see sats)
- **Quick actions**: Send, Receive, Scan QR
- **Recent transactions** with live polling
- **Suggestions slider** for onboarding tips
- **Bottom navigation**: Home, Cash, P2P, Profile

### 2. Send/Receive Payments

**Send Flow**:
1. `send_screen.dart` - Enter recipient (Lightning address/invoice/npub)
2. `send_amount_screen.dart` - Enter amount with Naira/sats conversion
3. `send_confirmation_screen.dart` - Review and confirm
4. `send_progress_screen.dart` - Payment processing
5. `payment_success_screen.dart` - Success confirmation

**Receive Flow**:
1. `receive_screen.dart` - Generate Lightning invoice or show Lightning address
2. QR code display with amount
3. Real-time payment detection via polling

### 3. Cash (Buy/Sell BTC)

**Location**: `lib/features/cash/presentation/screens/cash_screen.dart`

Integration with **Tapnob** for fiat on/off ramp:
- Live BTC/NGN and USD/NGN rates
- Quick amount selection chips
- WebView integration for Tapnob checkout
- Transaction history

```dart
// Rate service fetches live prices
class RateService {
  static Future<double> getBtcToNgnRate();
  static Future<double> getUsdToNgnRate();
}
```

### 4. P2P Trading

**Location**: `lib/features/p2p/presentation/screens/`

Binance/NoOnes-inspired P2P marketplace:
- Buy/Sell toggle
- Filter by payment method (Bank Transfer, Opay, Palmpay, etc.)
- Merchant profiles with reputation
- Trade chat with escrow
- Dispute resolution

Key screens:
- `p2p_home_screen.dart` - Offer listings
- `p2p_offer_detail_screen.dart` - Trade details
- `p2p_trade_chat_screen.dart` - In-trade messaging
- `p2p_create_offer_screen.dart` - Create new offers

### 5. Social Recovery (No Seed Phrase)

**Location**: `lib/features/recovery/`

Revolutionary **Shamir's Secret Sharing** implementation:

```dart
class SocialRecoveryService {
  // Split mnemonic into 5 shares (3-of-5 threshold)
  static Future<List<String>> splitMnemonicIntoShares(String mnemonic);
  
  // Reconstruct from 3+ shares
  static Future<String> reconstructMnemonic(List<String> shares);
  
  // Guardian management
  static Future<void> addGuardian(RecoveryContact contact);
  static Future<List<RecoveryContact>> getGuardians();
  
  // Share distribution via Nostr encrypted DMs
  static Future<void> sendShareToGuardian(RecoveryContact guardian, String share);
}
```

**Flow**:
1. User selects 5 trusted contacts (Nostr follows or device contacts)
2. Wallet splits seed phrase into 5 encrypted shares
3. Each share is sent via Nostr encrypted DM (NIP-04)
4. To recover: collect 3+ shares from guardians

### 6. Nostr Feed & Zaps

**Location**: `lib/features/nostr/nostr_feed_screen.dart`

Full social feed with real Lightning zaps:
- Global feed from multiple relays
- Follow-based filtering
- Image support with NSFW blur
- **Real zapping** via LNURL-pay protocol:
  1. Fetch author's `lud16` (Lightning address) from profile
  2. Resolve to LNURL callback
  3. Request invoice
  4. Pay via Breez SDK
- Like/reaction support (NIP-25)

### 7. VTU (Virtual Top-Up)

**Location**: `lib/features/vtu/`

Pay for airtime, data, and utilities with Bitcoin:
- All major Nigerian networks (MTN, Airtel, Glo, 9mobile)
- Data bundles
- Electricity bill payments

### 8. Authentication

**Location**: `lib/features/auth/presentation/screens/`

- **PIN-based** authentication (4-digit)
- **Biometric** support (fingerprint/face)
- Secure storage using `flutter_secure_storage`

---

## 🌐 Localization

**Supported Languages**:
- English (`app_en.arb`)
- Hausa (`app_ha.arb`)
- Yoruba (`app_yo.arb`)
- Pidgin English (`app_pcm.arb`)

Located in `lib/l10n/` with Flutter's built-in localization.

---

## 🔐 Security

### Secure Storage

```dart
class SecureStorage {
  // Encrypted key storage
  static Future<void> saveMnemonic(String mnemonic);
  static Future<String?> getMnemonic();
  
  // PIN storage
  static Future<void> savePin(String pin);
  static Future<bool> validatePin(String pin);
}
```

### Encryption

- **Hive boxes** encrypted with AES-256
- **Nostr keys** stored in `flutter_secure_storage`
- **Mnemonic** encrypted before storage

---

## 🎨 Design System

### Color Palette

```dart
class AppColors {
  static const primary = Color(0xFFF7931A);      // Bitcoin Orange
  static const background = Color(0xFF0C0C1A);  // Deep Navy
  static const surface = Color(0xFF111128);     // Card Navy
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFA1A1B2);
  static const accentGreen = Color(0xFF00FFB2); // Success
  static const accentRed = Color(0xFFFF4D4F);   // Error
}
```

### Typography

- **Font**: Inter (Regular, Medium, SemiBold, Bold)
- **Scaling**: `flutter_screenutil` for responsive sizing

---

## 📦 Key Dependencies

```yaml
# Core
flutter_riverpod: ^2.4.9          # State management
breez_sdk_spark_flutter           # Lightning SDK
nostr_dart: ^0.6.5                # Nostr protocol
bip39: ^1.0.6                     # Mnemonic generation

# UI
flutter_screenutil: ^5.9.3        # Responsive sizing
skeletonizer: ^2.1.2              # Loading skeletons
cached_network_image: ^3.3.1      # Image caching
flutter_confetti: ^0.2.0          # Celebration effects

# Security
flutter_secure_storage: ^9.2.4    # Secure key storage
local_auth: ^2.3.0                # Biometrics
encrypt: ^5.0.3                   # AES encryption
hive_flutter: ^1.1.0              # Encrypted local DB

# Networking
http: ^0.13.6                     # HTTP client

# Utilities
permission_handler: ^11.3.1       # Runtime permissions
share_plus: ^9.0.0                # Social sharing
qr_flutter: ^4.1.0                # QR generation
mobile_scanner: ^5.2.3            # QR scanning
```

---

## 🔌 External Integrations

| Service | Purpose | Integration |
|---------|---------|-------------|
| **Breez SDK Spark** | Lightning payments | Native SDK |
| **Tapnob** | Fiat on/off ramp | WebView |
| **Nostr Relays** | Social features | WebSocket |
| **Currency API** | Live rates | REST API |

### Nostr Relays

```dart
static final List<String> _defaultRelays = [
  'wss://nos.lol',
  'wss://nostr.mom',
  'wss://relay.snort.social',
  'wss://relay.f7z.io',
  'wss://eden.nostr.land',
  'wss://relay.nostr.bg',
  'wss://relay.damus.io',
  'wss://relay.primal.net',
  'wss://nostr.wine',
  'wss://relay.nostriches.org',
];
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.7+
- Dart SDK 3.0+
- Android Studio / Xcode for mobile builds

### Installation

```bash
# Clone repository
git clone https://github.com/auwalrg8/sabi.git
cd sabi_wallet

# Install dependencies
flutter pub get

# Run code generation (for Riverpod)
flutter pub run build_runner build

# Run the app
flutter run
```

### Configuration

Create `lib/config/breez_config.dart`:
```dart
class BreezConfig {
  static const String apiKey = 'YOUR_BREEZ_API_KEY';
}
```

---

## 📱 Screens Overview

| Screen | Path | Description |
|--------|------|-------------|
| Splash | `splash_screen.dart` | App loading |
| Entry | `entry_screen.dart` | Choose create/restore |
| Onboarding | `onboarding_carousel_screen.dart` | Feature tour |
| Home | `home_screen.dart` | Main dashboard |
| Send | `send_screen.dart` | Payment sending |
| Receive | `receive_screen.dart` | Payment receiving |
| Cash | `cash_screen.dart` | Buy/Sell BTC |
| P2P | `p2p_home_screen.dart` | P2P marketplace |
| Nostr Feed | `nostr_feed_screen.dart` | Social feed |
| Profile | `profile_screen.dart` | User settings |
| Recovery | `guardian_management_screen.dart` | Social recovery |
| VTU | `airtime_screen.dart` | Top-up services |

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

---

## 🔗 Links

- **Geyser Fund**: https://geyser.fund/project/sabi-wallet
- **GitHub (App)**: https://github.com/auwalrg8/sabi
- **GitHub (Backend)**: https://github.com/auwalrg8/sabi-wallet-backend

---

**Built with ❤️ in Kaduna, Nigeria 🇳🇬**

*Kaduna → Nigeria → Africa ⚡₦*
