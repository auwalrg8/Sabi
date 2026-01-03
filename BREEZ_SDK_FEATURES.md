# Breez SDK Implementation Analysis - Sabi Wallet

## SDK Package Used
- **`breez_sdk_spark_flutter`** - Nodeless Lightning implementation (non-custodial, no full node required)

---

## 📂 Implementation Categories

### 1. Core SDK Infrastructure
| Component | Purpose |
|-----------|---------|
| `lib/services/breez_spark_service.dart` | Main wrapper service - handles all SDK operations |
| `lib/services/breez_api_key_service.dart` | API key management (Cloudflare Worker + local override) |
| `lib/core/extensions/config_extensions.dart` | SDK config class extensions |
| `lib/main.dart` | App initialization with `BreezSdkSparkLib.init()` |

---

### 2. Wallet Management
- **Balance Tracking**: Real-time via `balanceStream` with 3-second polling
- **Wallet Creation**: Mnemonic generation + `initializeSparkSDK()`
- **Wallet Recovery**: Import mnemonic via `initializeSparkSDK(mnemonic: ...)`
- **Providers**: `breezBalanceProvider`, `walletInfoProvider`, `breezInitializerProvider`

---

### 3. Lightning Payments

| Feature | SDK Methods Used |
|---------|-----------------|
| **Send Payments** | `prepareSendPayment()`, `sendPayment()` |
| **Create Invoices** | `receivePayment()` with `ReceivePaymentRequest` |
| **Lightning Addresses** | `registerLightningAddress()`, `getLightningAddress()`, `checkLightningAddressAvailable()` |
| **Transaction History** | `listPayments()`, `paymentStream` |

---

### 4. Payment Notifications
- `lib/services/breez_webhook_bridge_service.dart` - Firebase push notifications
- `lib/services/payment_notification_service.dart` - Local notifications
- Uses `paymentStream` to detect incoming payments and trigger alerts

---

### 5. Fiat On/Off Ramp & P2P Trading
- **Invoice Creation** for fiat-to-BTC conversion
- **TapNob Integration** for off-ramp via `sendPayment()`
- **P2P Trade Escrow** using Lightning invoices

---

### 6. VTU Services (Airtime/Data/Bills)
- Balance check via `getBalance()`
- Payment execution via `sendPayment()` + `createInvoice()`

---

### 7. Nostr Zaps Integration
- Zap payments through `sendPayment()`
- LNURL-pay resolution for zap requests

---

## 🔑 Key SDK Classes Used

```dart
BreezSdk, BreezSdkSparkLib, Config, Network, Seed, ConnectRequest
GetInfoRequest, GetInfoResponse
ReceivePaymentRequest, ReceivePaymentMethod, ReceivePaymentResponse
PrepareSendPaymentRequest, PrepareSendPaymentResponse
SendPaymentRequest, SendPaymentOptions
Payment, PaymentType, PaymentDetails, ListPaymentsRequest
LightningAddressInfo, RegisterLightningAddressRequest
```

---

## 🏗️ Architecture Highlights

| Aspect | Implementation |
|--------|----------------|
| **Singleton Pattern** | All SDK calls routed through `BreezSparkService` |
| **Real-time Updates** | `StreamController` for balance & payment streams |
| **Polling Strategy** | 3s balance refresh, 2s payment detection |
| **Secure Storage** | Hive-based encrypted mnemonic persistence |
| **API Key Layers** | Local override → dart-define → Cloudflare → cache |

---

## 📁 Main Files

| File | Role |
|------|------|
| `lib/services/breez_spark_service.dart` | **Central SDK wrapper** |
| `lib/core/providers/breez_balance_provider.dart` | Balance state management |
| `lib/core/providers/payment_provider.dart` | Payment stream provider |
| `lib/features/wallet/screens/home_screen.dart` | Main wallet UI integration |
| `lib/features/payments/screens/receive_screen.dart` | Invoice/Lightning address UI |
| `lib/features/payments/screens/send_payment_progress_screen.dart` | Send payment flow |

---

## 📋 Key SDK Methods Summary

| Method | Purpose |
|--------|---------|
| `BreezSdkSparkLib.init()` | Initialize flutter_rust_bridge |
| `connect()` | Connect to Breez SDK |
| `getInfo()` | Get balance and node info |
| `receivePayment()` | Create invoices |
| `prepareSendPayment()` | Prepare outgoing payment |
| `sendPayment()` | Execute payment |
| `listPayments()` | Get transaction history |
| `registerLightningAddress()` | Register Lightning address |
| `getLightningAddress()` | Fetch current Lightning address |
| `checkLightningAddressAvailable()` | Check username availability |
| `deleteLightningAddress()` | Remove Lightning address |
| `getPayment()` | Get specific payment details |
