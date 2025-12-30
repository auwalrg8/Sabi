# Offline Push Notification Implementation

## Problem

Push notifications only work when the app is running (foreground or background), but not when the app is killed/closed. This is because:

1. **Breez SDK Spark is "nodeless"** - Unlike the regular Breez SDK which has `registerWebhook()` for server-side payment notifications, Spark SDK relies entirely on client-side polling
2. **Polling stops when app is killed** - The `_startPaymentPolling()` timer stops executing when the app is terminated
3. **Client-side wallet** - The wallet state is only accessible when the SDK is initialized with the user's mnemonic

## Current Architecture

```
[User's App] <-- Polling every 2 seconds --> [Breez SDK Spark]
     |
     v
[Payment Detected] --> [Webhook Bridge] --> [Vercel API] --> [FCM Push]
     ^
     |
[THIS ONLY WORKS WHEN APP IS RUNNING]
```

## Implemented Solutions

### 1. Android WorkManager Background Sync

Added WorkManager to periodically wake the app and trigger sync:

- **Frequency**: Every 15 minutes (Android minimum)
- **Behavior**: Sends wake-up request to server which can send FCM data message
- **Limitation**: Not real-time, 15-minute delay minimum

Files modified:
- `lib/services/background_payment_sync_service.dart` (new)
- `lib/main.dart` (initialization)
- `pubspec.yaml` (workmanager dependency)
- `android/app/src/main/AndroidManifest.xml` (permissions)

### 2. FCM Background Handler Enhancement

Improved the FCM background message handler to process payment notifications:

- Handles `payment_received` message type
- Shows local notification with amount in sats and Naira
- Handles `sync` and `wake_device` message types

File modified:
- `lib/services/firebase_notification_service.dart`

## What's Still Needed (Server-Side)

For **true real-time offline notifications**, you need server-side infrastructure:

### Option A: LNURL Server Webhook (Recommended)

Since users have Lightning Addresses (`@sabi.bg`), configure your LNURL server to send webhooks when payments are received:

1. **LNURL Server** receives incoming payment
2. **Webhook** sent to `https://vercel-api-one-sigma.vercel.app/api/lnurl-payment`
3. **Vercel API** looks up user's FCM token by Lightning Address
4. **FCM Push** sent to user's device

Required Vercel API endpoints:
```
POST /api/lnurl-payment
{
  "lightningAddress": "user@sabi.bg",
  "amountSats": 1000,
  "paymentHash": "...",
  "timestamp": "..."
}
```

### Option B: Wake Device Endpoint

Create an endpoint that the background sync calls to request a wake-up push:

```
POST /api/webhook/wake-device
{
  "nostrPubkey": "...",
  "fcmToken": "...",
  "lastSyncTime": 1234567890,
  "reason": "background_sync"
}
```

Response: Send FCM data message to wake the app

## Testing

### Test WorkManager Background Sync

1. Kill the app completely
2. Wait 15 minutes
3. Check device logs for `[Background] WorkManager task started`
4. Check Vercel API logs for `/webhook/wake-device` requests

### Test FCM Background Handler

1. Send a test FCM data message:
```json
{
  "data": {
    "type": "payment_received",
    "amountSats": "1000",
    "amountNaira": "1500"
  }
}
```
2. With app killed, the notification should still appear

## Battery Optimization

Android may delay or skip WorkManager tasks due to battery optimization. Users should be encouraged to:

1. **Disable battery optimization** for Sabi Wallet
2. Or add the app to the "unrestricted" battery usage list

The app can request this with:
```dart
import 'package:permission_handler/permission_handler.dart';
await Permission.ignoreBatteryOptimizations.request();
```

## Limitations

| Feature | Status |
|---------|--------|
| Foreground notifications | ✅ Works |
| Background (app not killed) | ✅ Works via FCM |
| App killed - with LNURL webhook | ✅ Works if server configured |
| App killed - polling only | ⚠️ 15-min delay minimum |

## Recommended Next Steps

1. **Configure LNURL server** to send webhooks on payment receipt
2. **Create Vercel API endpoint** `/api/lnurl-payment` to handle LNURL webhooks
3. **Test end-to-end** with app killed, receive payment, verify notification appears
4. **Consider adding** battery optimization exemption request on onboarding
