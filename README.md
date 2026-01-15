# Sabi Wallet ⚡₦

<p align="center">
  <img src="assets/icons/app_icon.png" alt="Sabi Wallet Logo" width="120"/>
</p>

<p align="center">
  <strong>The first non-custodial Bitcoin + Lightning + Nostr wallet built in Kaduna, Nigeria</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#screenshots">Screenshots</a> •
  <a href="#installation">Installation</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#download">Download</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue" alt="Platform"/>
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License"/>
  <img src="https://img.shields.io/badge/Flutter-3.x-blue" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Bitcoin-Lightning-orange" alt="Bitcoin Lightning"/>
</p>

---

## ⚡ What is Sabi Wallet?

Sabi Wallet is an open-source, non-custodial Bitcoin Lightning wallet designed specifically for Africa. It combines:

- **Lightning Network** for instant, low-fee Bitcoin payments
- **Nostr Protocol** for decentralized social identity and messaging
- **P2P Trading** for buying/selling Bitcoin with local currencies
- **Social Recovery** for seedless wallet backup using trusted contacts

**100% open source – MIT License**

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🇳🇬 **Naira Balance** | See your balance in Naira (tap to toggle sats) |
| ⚡ **Instant Payments** | Lightning-fast payments with low fees |
| 💬 **Nostr Integration** | Social feed, zaps, DMs, and profile management |
| 🔄 **P2P Trading** | Buy/sell Bitcoin with Naira, escrow-protected |
| 🛡️ **Social Recovery** | Pick 3 trusted contacts - no seed phrase needed |
| 📲 **Lightning Address** | Get your own `username@sabi.wallet` address |
| 🏦 **Bill Payments** | Airtime, data, electricity, cable TV |
| 🌍 **Multi-language** | Hausa, Pidgin, Yoruba, Igbo, English |

---

## 📱 Screenshots

<p align="center">
  <img src="docs/screenshots/home.png" width="200" alt="Home Screen"/>
  <img src="docs/screenshots/send.png" width="200" alt="Send Screen"/>
  <img src="docs/screenshots/receive.png" width="200" alt="Receive Screen"/>
  <img src="docs/screenshots/p2p.png" width="200" alt="P2P Trading"/>
</p>

---

## 🚀 Installation

### Prerequisites

- Flutter SDK 3.16+ 
- Dart 3.2+
- Android Studio / Xcode
- Git

### Quick Start

```bash
# Clone the repository
git clone https://github.com/AuwalRG8/sabi_wallet.git
cd sabi_wallet

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Configuration

1. Copy configuration templates:
```bash
cp lib/config/vtu_config.local.dart.example lib/config/vtu_config.local.dart
cp lib/firebase_options.dart.example lib/firebase_options.dart
```

2. Set up your Breez SDK API key in `lib/config/breez_config.dart`

3. Configure Firebase for push notifications (optional)

---

## 🏗️ Architecture

Sabi Wallet follows **Clean Architecture** principles:

```
lib/
├── main.dart                    # App entry point
├── app.dart                     # App configuration
├── config/                      # Configuration files
├── core/                        # Shared utilities
│   ├── constants/               # App constants, colors
│   ├── extensions/              # Dart extensions
│   ├── services/                # Core services
│   ├── theme/                   # App theming
│   ├── utils/                   # Utility functions
│   └── widgets/                 # Reusable widgets
├── features/                    # Feature modules
│   ├── agent/                   # AI assistant
│   ├── auth/                    # Authentication
│   ├── cash/                    # Fiat operations
│   ├── home/                    # Dashboard
│   ├── nostr/                   # Nostr social
│   │   ├── data/                # Data sources
│   │   ├── domain/              # Business logic
│   │   ├── presentation/        # UI (screens, widgets)
│   │   ├── providers/           # State management
│   │   └── services/            # Feature services
│   ├── onboarding/              # User onboarding
│   ├── p2p/                     # P2P trading
│   ├── profile/                 # User profile
│   ├── recovery/                # Social recovery
│   ├── vtu/                     # Bill payments
│   ├── wallet/                  # Core wallet
│   └── zaps/                    # Lightning zaps
├── l10n/                        # Localization
└── services/                    # Global services
    ├── firebase/                # Firebase services
    └── nostr/                   # Nostr services
```

### Key Technologies

| Technology | Purpose |
|------------|---------|
| **Flutter** | Cross-platform UI framework |
| **Riverpod** | State management |
| **Breez SDK** | Lightning Network integration |
| **Nostr** | Decentralized social protocol |
| **Firebase** | Push notifications |
| **Hive** | Local storage |

---

## 🤝 Contributing

We welcome contributions from the Bitcoin and Flutter community!

1. Read our [CONTRIBUTING.md](CONTRIBUTING.md) guide
2. Check out [Good First Issues](https://github.com/AuwalRG8/sabi_wallet/labels/good%20first%20issue)
3. Join our community discussions

### Development Setup

```bash
# Run tests
flutter test

# Check code quality
flutter analyze

# Format code
dart format lib
```

---

## 📥 Download

| Platform | Link |
|----------|------|
| Android APK | [Download Latest](https://github.com/AuwalRG8/sabi_wallet/releases) |
| iOS | Coming Soon |

---

## 🌍 Community

- **Geyser Fund**: [Support the project](https://geyser.fund/project/sabi-wallet)
- **GitHub**: [github.com/AuwalRG8/sabi_wallet](https://github.com/AuwalRG8/sabi_wallet)
- **Nostr**: Follow `npub1...` (coming soon)

---

## 📜 License

MIT License - see [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

- [Breez SDK](https://breez.technology/) - Lightning infrastructure
- [Nostr Protocol](https://nostr.com/) - Decentralized social
- [Tapnob](https://tapnob.com/) - Fiat liquidity

---

<p align="center">
  <strong>Built with ❤️ in Kaduna, Nigeria 🇳🇬</strong>
</p>

<p align="center">
  <em>Kaduna → Nigeria → Africa ⚡₦</em>
</p>
