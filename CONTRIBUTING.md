# Contributing to Sabi Wallet ⚡

Thank you for your interest in contributing to Sabi Wallet! We're building the most welcoming Bitcoin wallet for Africa, and we need your help.

## 🌍 Our Mission

Sabi Wallet aims to bring Bitcoin and Lightning payments to millions of Africans. Every contribution, no matter how small, helps make this vision a reality.

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.16+
- Dart 3.2+
- Git
- Android Studio or VS Code with Flutter extensions
- (Optional) Xcode for iOS development

### Setup

```bash
# 1. Fork and clone the repository
git clone https://github.com/YOUR_USERNAME/sabi_wallet.git
cd sabi_wallet

# 2. Install dependencies
flutter pub get

# 3. Copy config templates
cp lib/config/vtu_config.local.dart.example lib/config/vtu_config.local.dart
cp lib/firebase_options.dart.example lib/firebase_options.dart

# 4. Run the app
flutter run
```

### Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run a specific test file
flutter test test/social_recovery_test.dart
```

---

## 🏗️ Project Structure

```
lib/
├── features/          # Feature modules (follow Clean Architecture)
│   ├── feature_name/
│   │   ├── data/          # Data sources, repositories
│   │   ├── domain/        # Business logic, models
│   │   ├── presentation/  # UI (screens, widgets)
│   │   ├── providers/     # Riverpod state management
│   │   └── services/      # Feature-specific services
├── core/              # Shared utilities and widgets
├── services/          # Global services
└── l10n/              # Localization files
```

---

## 📝 Code Style Guide

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | `snake_case` | `home_screen.dart` |
| Classes | `PascalCase` | `HomeScreen` |
| Variables | `camelCase` | `userName` |
| Constants | `camelCase` | `primaryColor` |
| Functions | `verbNoun` | `getUserProfile()` |
| Private members | `_prefixed` | `_isLoading` |

### File Organization

```dart
// 1. Imports (alphabetically sorted)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sabi_wallet/core/...';

// 2. Part directives (if any)

// 3. Constants

// 4. Classes/Widgets
class MyWidget extends StatelessWidget {
  // Constructor first
  const MyWidget({super.key});

  // Static members
  // Instance members
  // Build method last
}
```

### Best Practices

- ✅ Keep files under 500 lines (split if larger)
- ✅ One widget per file for screens
- ✅ Use `const` constructors where possible
- ✅ Add comments for complex logic
- ✅ Write tests for business logic
- ❌ Avoid god classes
- ❌ Don't commit commented-out code

---

## 🔌 Testing Lightning Payments

### Testnet Setup

1. The app uses Breez SDK which connects to real Lightning Network
2. For testing, use small amounts (100-1000 sats)
3. Get testnet sats from: https://signet.bc-2.jp/

### Testing P2P Trades

1. Create a test offer with minimum amount
2. Use a second device/emulator as counterparty
3. Complete the full trade flow

---

## 🐛 Reporting Bugs

Please include:

1. **Description**: Clear description of the bug
2. **Steps to Reproduce**: Numbered steps
3. **Expected Behavior**: What should happen
4. **Actual Behavior**: What actually happens
5. **Screenshots**: If applicable
6. **Device Info**: Phone model, OS version, app version

---

## ✨ Submitting Changes

### Pull Request Process

1. **Fork** the repository
2. **Create a branch**: `git checkout -b feature/amazing-feature`
3. **Make changes** following our code style
4. **Test** your changes: `flutter test`
5. **Format** code: `dart format lib`
6. **Analyze**: `flutter analyze`
7. **Commit**: Use descriptive commit messages
8. **Push**: `git push origin feature/amazing-feature`
9. **Open PR**: Against `main` branch

### Commit Messages

Follow conventional commits:

```
feat: add new payment screen
fix: resolve crash on startup
docs: update README
style: format code
refactor: extract widget
test: add unit tests for recovery
```

---

## 🏷️ Good First Issues

Look for issues labeled:
- `good first issue` - Perfect for newcomers
- `help wanted` - We need help with these
- `documentation` - Improve docs
- `ui/ux` - Design improvements

---

## 🌐 Translations

Help us translate Sabi Wallet:

1. Find translation files in `lib/l10n/`
2. Add translations for your language
3. Test with: `flutter run --dart-define=LOCALE=ha` (Hausa)

Supported languages:
- English (en)
- Hausa (ha)
- Pidgin (pcm)
- Yoruba (yo)
- Igbo (ig)

---

## 💬 Community

- **GitHub Discussions**: Ask questions, share ideas
- **Issues**: Report bugs, request features
- **Nostr**: Follow project updates

---

## 📜 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

## 🙏 Thank You!

Every contributor is making Bitcoin more accessible in Africa. Your work matters!

<p align="center">
  <strong>Kaduna → Nigeria → Africa ⚡₦</strong>
</p>
