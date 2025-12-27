# P2P Trading Implementation Documentation

## Sabi Wallet - Peer-to-Peer Bitcoin Trading

This document provides comprehensive documentation for the P2P trading feature in Sabi Wallet, a non-custodial Bitcoin wallet focused on the Nigerian market with international support.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core Features](#core-features)
4. [Data Models](#data-models)
5. [Services](#services)
6. [Screens & UI](#screens--ui)
7. [Security Features](#security-features)
8. [Payment Methods](#payment-methods)
9. [Error Handling & Logging](#error-handling--logging)
10. [Future Enhancements](#future-enhancements)

---

## Overview

### What is P2P Trading?

P2P (Peer-to-Peer) trading allows users to buy and sell Bitcoin directly with each other without a centralized exchange. The Sabi Wallet P2P feature provides:

- **Direct Bitcoin Trading**: Buy/sell BTC using local payment methods
- **Non-Custodial Escrow**: Bitcoin held in Lightning escrow during trades
- **4-Minute Payment Window**: Protects against BTC price volatility
- **No KYC Required**: Optional Trust Profile sharing instead
- **30+ Payment Methods**: Nigerian banks, mobile money, and international options

### Key Principles

| Principle | Description |
|-----------|-------------|
| **Non-Custodial** | Users maintain control of their Bitcoin at all times |
| **Fast Settlement** | 4-minute window ensures quick trades |
| **Privacy-First** | No mandatory KYC, optional profile sharing |
| **Trust-Based** | Trade code verification and social profiles |

---

## Architecture

```
lib/features/p2p/
├── data/
│   ├── models/
│   │   ├── payment_method_international.dart   # 30+ global payment methods
│   │   ├── social_profile_model.dart           # Trust profile sharing
│   │   └── trade_code_model.dart               # Split verification codes
│   ├── merchant_model.dart                     # Trader profiles
│   ├── p2p_offer_model.dart                    # Offer definitions
│   ├── payment_method_model.dart               # Nigerian payment methods
│   └── trade_model.dart                        # Trade state management
├── presentation/
│   ├── screens/
│   │   ├── p2p_home_screen.dart               # Buy/Sell tabs
│   │   ├── p2p_create_offer_screen.dart       # Create new offers
│   │   ├── p2p_offer_detail_screen.dart       # View offer details
│   │   ├── p2p_trade_chat_screen.dart         # Active trade chat
│   │   ├── p2p_escrow_info_screen.dart        # Escrow education
│   │   ├── p2p_success_screen.dart            # Trade completion
│   │   └── social_profile_settings_screen.dart # Manage profiles
│   └── widgets/
│       ├── trade_timer_widget.dart            # Countdown timers
│       ├── trade_code_widget.dart             # Code verification UI
│       └── social_profile_widget.dart         # Profile sharing UI
├── providers/
│   ├── p2p_providers.dart                     # Riverpod providers
│   └── trade_providers.dart                   # Trade state providers
├── services/
│   └── p2p_trade_service.dart                 # Lightning integration
└── utils/
    └── p2p_logger.dart                        # Comprehensive logging
```

---

## Core Features

### 1. Differentiated Buy/Sell UX

The P2P home screen provides distinct experiences for buyers and sellers:

#### Buy BTC Tab
- Browse available sell offers
- Filter by payment method
- See seller ratings and trade history
- Quick "Buy" action buttons

#### Sell BTC Tab
- Create new sell offers
- View your active offers
- Important info card about selling
- Different card design for sell context

### 2. 4-Minute Payment Window

To protect against Bitcoin price volatility, trades have a strict 4-minute (240 seconds) payment window:

```dart
const kTradeTimerSeconds = 240;  // 4 minutes total
const kWarning2Min = 120;         // 2-minute warning
const kWarning1Min = 60;          // 1-minute warning  
const kWarning30Sec = 30;         // Final warning
```

**Timer Features:**
- Visual countdown bar with color changes
- System messages at warning thresholds
- Pulse animation when urgent (<1 minute)
- Automatic trade cancellation on expiry

### 3. Trade Code Verification (Optional)

A split 6-digit code system for additional trade security:

```dart
class TradeCode {
  final String fullCode;  // e.g., "847293"
  
  String get buyerPart => fullCode.substring(0, 3);   // "847"
  String get sellerPart => fullCode.substring(3, 6);  // "293"
}
```

**How it works:**
1. Seller enables "Trade Code" when creating offer
2. System generates random 6-digit code
3. Buyer sees first 3 digits, seller sees last 3
4. Both share their parts verbally/via chat
5. Match confirms legitimate trade

### 4. Trust Profile Sharing (Optional)

Build trust without KYC by optionally sharing social profiles:

**Supported Platforms:**
| Platform | Handle Format |
|----------|---------------|
| X (Twitter) | @username |
| Facebook | Profile URL |
| Nostr | npub1... |
| Telegram | @username |
| WhatsApp | +234 XXX... |
| Instagram | @username |
| Phone | +1234567890 |
| Email | email@example.com |

**Privacy Features:**
- Stored locally only
- Never visible on public profiles
- Consent required per trade
- Can revoke anytime
- Deleted after trade

### 5. Lightning Escrow Integration

Trades use the Breez SDK Spark for non-custodial escrow:

```dart
class P2PTradeService {
  static Future<P2PInvoice> createEscrowInvoice({
    required int amountSats,
    required String tradeId,
  }) async {
    final sdk = await BreezSparkService.getSDK();
    final invoice = await sdk.receivePayment(
      amountMsat: amountSats * 1000,
      description: 'P2P Trade: $tradeId',
    );
    return P2PInvoice(
      bolt11: invoice.lnInvoice.bolt11,
      amountSats: amountSats,
      expiresAt: DateTime.now().add(Duration(seconds: kTradeTimerSeconds)),
    );
  }
}
```

---

## Data Models

### P2POfferModel

```dart
class P2POfferModel {
  final String id;
  final String name;           // Merchant name
  final OfferType type;        // OfferType.buy or OfferType.sell
  final double rate;           // BTC/NGN rate
  final double marginPercent;  // Markup/markdown percentage
  final double minLimit;       // Minimum trade amount (NGN)
  final double maxLimit;       // Maximum trade amount (NGN)
  final String paymentMethod;  // Primary payment method
  final String currency;       // Fiat currency
  final int trades30d;         // Recent trade count
  final double completionRate; // Trade completion percentage
  final int avgReleaseMinutes; // Average BTC release time
  final bool isOnline;         // Merchant online status
  final MerchantModel merchant;// Full merchant details
}
```

### MerchantModel

```dart
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
  final int linkedPlatformsCount;      // Trust profiles linked
  final bool openToProfileSharing;     // Accepts profile requests
}
```

### TradeModel

```dart
enum TradeStatus {
  pending,
  awaitingPayment,
  paid,
  completed,
  cancelled,
  expired,
  disputed,  // Legacy - no longer used
}

class TradeModel {
  final String id;
  final String offerId;
  final String counterpartyId;
  final TradeStatus status;
  final double amountFiat;
  final double amountSats;
  final String paymentMethod;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? invoiceBolt11;
  final TradeCode? tradeCode;
}
```

### SocialProfile

```dart
enum SocialPlatform {
  x, facebook, nostr, telegram, whatsapp, instagram, phone, email
}

class SocialProfile {
  final String id;
  final SocialPlatform platform;
  final String handle;
  final bool isVerified;
  final DateTime addedAt;
}

class ProfileShareRequest {
  final String id;
  final String tradeId;
  final String requesterId;
  final List<SocialPlatform> offeredPlatforms;
  final ProfileShareStatus status;
  final ShareConsent? response;
}
```

---

## Services

### P2PTradeService

Core service for managing trades with Lightning integration:

```dart
class P2PTradeService {
  // Create a new trade from an offer
  static Future<TradeResult<ActiveTrade>> startTrade({
    required P2POfferModel offer,
    required double amountFiat,
    required int amountSats,
  });
  
  // Create escrow invoice for sellers
  static Future<P2PInvoice> createEscrowInvoice({
    required int amountSats,
    required String tradeId,
  });
  
  // Mark payment as sent (buyer)
  static Future<TradeResult<ActiveTrade>> markAsPaid(
    String tradeId, 
    {String? proofPath}
  );
  
  // Release Bitcoin (seller)
  static Future<TradeResult<ActiveTrade>> releaseBtc(String tradeId);
  
  // Cancel trade
  static Future<TradeResult<ActiveTrade>> cancelTrade(
    String tradeId, 
    String reason
  );
}
```

### SocialProfileService

Local storage for trust profiles:

```dart
class SocialProfileService {
  static Future<void> init();
  static List<SocialProfile> getProfiles();
  static bool get isSharingEnabled;
  static int get linkedPlatformsCount;
  static Future<void> setProfile(SocialProfile profile);
  static Future<void> removeProfile(SocialPlatform platform);
  static Future<void> setSharingEnabled(bool enabled);
  static bool get hasProfilesToShare;
}
```

---

## Screens & UI

### P2PHomeScreen

Main entry point with tabbed interface:

- **Buy BTC Tab**: Browse offers from sellers
- **Sell BTC Tab**: Create offers or view your listings
- Payment method filters
- Pull-to-refresh
- Empty states with CTAs

### P2PCreateOfferScreen

Multi-step wizard for creating offers:

1. **Step 1: Offer Type**
   - Buy or Sell toggle
   - Market rate display
   - Margin slider

2. **Step 2: Trade Limits**
   - Min/max amounts in NGN
   - Quick preset buttons
   - Trade code toggle
   - Profile sharing toggle

3. **Step 3: Payment Methods**
   - Nigerian methods (from provider)
   - International methods (grouped by region)
   - Multi-select support
   - Payment instructions

4. **Step 4: Review**
   - Summary of all settings
   - Submit button

### P2PTradeChatScreen

Active trade interface:

- Timer bar with countdown
- Trade info card
- Profile share request/response UI
- Shared profiles display
- Chat message list
- Action buttons (Pay/Release)
- Proof upload
- Trade options menu

### SocialProfileSettingsScreen

Manage trust profiles:

- Global sharing toggle
- Linked profiles list
- Add/edit/remove profiles
- Platform selection
- Handle validation
- Privacy notices

### P2PEscrowInfoScreen

Educational content:

- What is escrow
- Why 4 minutes
- Trade code verification
- Trade flow steps
- Risk warnings
- Safety tips

---

## Security Features

### 1. Non-Custodial Escrow

Bitcoin is locked in a Lightning HTLC (Hash Time-Locked Contract) that only releases when:
- Seller confirms payment received
- OR timer expires (returned to seller)

### 2. Trade Code Verification

Optional split-code system prevents:
- Fake payment confirmations
- Man-in-the-middle attacks
- Social engineering

### 3. 4-Minute Window

Short window protects against:
- Price volatility exploitation
- Prolonged attack windows
- Abandoned trades

### 4. Comprehensive Logging

```dart
class P2PLogger {
  static void info(String category, String message, {Map? metadata});
  static void warning(String category, String message, {Map? metadata});
  static void error(String category, String message, {String? errorCode});
  static void critical(String category, String message, {StackTrace? stack});
}
```

All trade events are logged locally for debugging and support.

---

## Payment Methods

### Nigerian Methods (Primary)

| Method | Type | Est. Time |
|--------|------|-----------|
| GTBank | Bank Transfer | ~5 min |
| OPay | Mobile Money | ~2 min |
| PalmPay | Mobile Money | ~2 min |
| Moniepoint | Mobile Money | ~2 min |
| Kuda | Digital Bank | ~3 min |
| First Bank | Bank Transfer | ~5 min |
| Access Bank | Bank Transfer | ~5 min |
| Zenith Bank | Bank Transfer | ~5 min |

### International Methods

| Region | Methods |
|--------|---------|
| **Global** | Wise, PayPal, Revolut |
| **USA** | Venmo, Zelle, Cash App |
| **Europe** | SEPA, SEPA Instant |
| **UK** | Faster Payments |
| **India** | UPI, IMPS |
| **Brazil** | Pix |
| **Canada** | Interac e-Transfer |
| **Africa** | M-Pesa, MTN MoMo, Airtel Money, Orange Money |
| **Gift Cards** | Amazon, Steam |
| **Cash** | Cash in Person |

---

## Error Handling & Logging

### Error Codes

```dart
class P2PErrorCodes {
  // Trade errors
  static const tradeCreationFailed = 'P2P_TRADE_001';
  static const tradeNotFound = 'P2P_TRADE_002';
  static const tradeExpired = 'P2P_TRADE_003';
  static const tradeCancelled = 'P2P_TRADE_004';
  
  // Invoice errors
  static const invoiceCreationFailed = 'P2P_INV_001';
  static const invoiceExpired = 'P2P_INV_002';
  static const invoicePaymentFailed = 'P2P_INV_003';
  
  // Timer errors
  static const timerExpired = 'P2P_TMR_001';
  
  // Verification errors
  static const codeVerificationFailed = 'P2P_VER_001';
  static const codeMismatch = 'P2P_VER_003';
  
  // Network errors
  static const networkError = 'P2P_NET_001';
  static const sdkNotInitialized = 'P2P_NET_002';
  
  // User errors
  static const insufficientBalance = 'P2P_USR_001';
  static const invalidAmount = 'P2P_USR_002';
}
```

### Log Persistence

Logs are stored locally using SharedPreferences:
- Maximum 500 entries retained
- Automatic cleanup of old logs
- Export capability for support

---

## Future Enhancements

### Planned Features

1. **Nostr Integration**
   - Decentralized messaging
   - Reputation across apps
   - NIP-05 verification

2. **Multi-Currency Support**
   - USD, EUR, GBP markets
   - Dynamic rate feeds

3. **Reputation System**
   - On-chain reputation proofs
   - Cross-platform ratings

4. **Automated Escrow**
   - Smart contract integration
   - Programmable release conditions

5. **Dispute Resolution**
   - Optional arbitration
   - Community moderators

### Integration Points

- **Breez SDK Spark**: Lightning payments
- **Nostr**: Decentralized identity
- **Local Storage**: SharedPreferences
- **State Management**: Riverpod

---

## File Summary

### New Files Created

| File | Purpose |
|------|---------|
| `trade_code_model.dart` | Split verification codes |
| `payment_method_international.dart` | 30+ global payment methods |
| `social_profile_model.dart` | Trust profile sharing |
| `p2p_trade_service.dart` | Lightning integration |
| `p2p_logger.dart` | Comprehensive logging |
| `trade_timer_widget.dart` | Countdown UI |
| `trade_code_widget.dart` | Code verification UI |
| `social_profile_widget.dart` | Profile sharing UI |
| `p2p_escrow_info_screen.dart` | Educational content |
| `social_profile_settings_screen.dart` | Profile management |

### Modified Files

| File | Changes |
|------|---------|
| `p2p_home_screen.dart` | Tabbed Buy/Sell UX |
| `p2p_create_offer_screen.dart` | Trade code + profile toggles |
| `p2p_trade_chat_screen.dart` | 4-min timer, profile sharing |
| `merchant_model.dart` | Added profile fields |

### Removed Files

| File | Reason |
|------|--------|
| `p2p_dispute_screen.dart` | Disputes removed from feature |

---

## Conclusion

The Sabi Wallet P2P feature provides a complete, privacy-focused trading experience that:

- **Protects traders** with 4-minute windows and optional verification
- **Builds trust** without requiring KYC through social profiles
- **Supports global users** with 30+ payment methods
- **Maintains privacy** with non-custodial escrow and local storage
- **Provides transparency** with comprehensive logging

For questions or contributions, refer to the codebase in `lib/features/p2p/`.
