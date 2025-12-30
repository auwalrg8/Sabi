# Sabi Wallet - Firebase Cloud Functions

This directory contains the Firebase Cloud Functions that power push notifications for Sabi Wallet.

## Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Sabi Wallet   │────▶│  Cloud Functions │────▶│      FCM        │
│   (Flutter)     │     │   (Node.js)      │     │  (Push Service) │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                        │
        │                       ▼                        │
        │               ┌─────────────────┐              │
        │               │   Firestore     │              │
        │               │ (Device Tokens) │              │
        │               └─────────────────┘              │
        │                                                │
        └────────────────────────────────────────────────┘
                         Push Notification
```

## Features

### Notification Types Supported

| Type | Priority | Description |
|------|----------|-------------|
| `payment_received` | MAX | Lightning payment arrived |
| `p2p_trade_started` | HIGH | New P2P trade initiated |
| `p2p_payment_marked` | HIGH | Buyer marked fiat payment |
| `p2p_payment_confirmed` | HIGH | Seller confirmed payment |
| `p2p_funds_released` | HIGH | Trade completed |
| `p2p_trade_cancelled` | DEFAULT | Trade was cancelled |
| `p2p_trade_disputed` | HIGH | Dispute raised |
| `p2p_new_message` | DEFAULT | New trade chat message |
| `p2p_new_inquiry` | DEFAULT | New offer inquiry |
| `zap_received` | DEFAULT | Received a Nostr zap |
| `dm_received` | DEFAULT | New encrypted DM |
| `vtu_order_complete` | DEFAULT | VTU purchase succeeded |
| `vtu_order_failed` | DEFAULT | VTU purchase failed |

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/registerDevice` | POST | Register device FCM token |
| `/unregisterDevice` | POST | Remove device registration |
| `/breezPaymentWebhook` | POST | Lightning payment webhook |
| `/p2pTradeWebhook` | POST | P2P trade event webhook |
| `/zapWebhook` | POST | Zap notification webhook |
| `/dmWebhook` | POST | DM notification webhook |
| `/vtuWebhook` | POST | VTU order status webhook |
| `/healthCheck` | GET | Health check |
| `/sendTestNotification` | POST | Test notification (debug) |

## Setup Instructions

### Prerequisites

1. **Firebase CLI** installed globally:
   ```bash
   npm install -g firebase-tools
   ```

2. **Firebase Project** created at [Firebase Console](https://console.firebase.google.com/)

3. **Blaze Plan** enabled (required for Cloud Functions)

### Installation

1. Navigate to the functions directory:
   ```bash
   cd firebase/functions
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Login to Firebase:
   ```bash
   firebase login
   ```

4. Select your project:
   ```bash
   firebase use sabi-wallet
   ```

### Local Development

1. Start the emulators:
   ```bash
   npm run serve
   ```

2. Test endpoints at:
   - Functions: `http://localhost:5001/sabi-wallet/us-central1/`
   - Firestore UI: `http://localhost:4000`

### Deployment

1. Build the TypeScript:
   ```bash
   npm run build
   ```

2. Deploy to Firebase:
   ```bash
   npm run deploy
   ```

   Or from project root:
   ```bash
   cd firebase
   firebase deploy --only functions
   ```

3. Your endpoints will be available at:
   ```
   https://us-central1-sabi-wallet.cloudfunctions.net/
   ```

## Firestore Structure

```
/devices/{fcmToken}
  - fcmToken: string
  - nostrPubkey: string
  - platform: "ios" | "android"
  - registeredAt: timestamp
  - lastActive: timestamp

/pubkey_devices/{nostrPubkey}
  - tokens: string[]  // Array of FCM tokens
  - updatedAt: timestamp
```

## Webhook Payloads

### Payment Received Webhook
```json
{
  "nostrPubkey": "abc123...",
  "amountSats": 10000,
  "amountNaira": 5000,
  "paymentHash": "hash...",
  "description": "Coffee payment"
}
```

### P2P Trade Webhook
```json
{
  "nostrPubkey": "abc123...",
  "tradeId": "trade-uuid",
  "eventType": "trade_started|payment_marked|payment_confirmed|funds_released|trade_cancelled|trade_disputed|new_message|new_inquiry",
  "amount": "50000",
  "counterpartyName": "satoshi"
}
```

### Zap Webhook
```json
{
  "nostrPubkey": "abc123...",
  "amountSats": 1000,
  "senderName": "satoshi",
  "senderPubkey": "xyz789...",
  "message": "Nice post!",
  "eventId": "event-id"
}
```

### VTU Webhook
```json
{
  "nostrPubkey": "abc123...",
  "orderId": "order-uuid",
  "orderType": "airtime|data|electricity",
  "status": "complete|failed",
  "amount": "1000",
  "phoneNumber": "08012345678"
}
```

## Integration with External Services

### Breez SDK Webhook

Configure Breez SDK to send payment notifications to:
```
POST https://us-central1-sabi-wallet.cloudfunctions.net/breezPaymentWebhook
```

### Nostr Relay Bridge

For real-time Nostr event notifications, you can:
1. Run a relay watcher service that subscribes to user events
2. Call the appropriate webhook when events arrive

Example (pseudocode):
```javascript
// When DM received for user
await fetch('https://...cloudfunctions.net/dmWebhook', {
  method: 'POST',
  body: JSON.stringify({
    nostrPubkey: recipientPubkey,
    senderName: 'satoshi',
    senderPubkey: senderPubkey,
    preview: 'Hey, saw your offer...'
  })
});
```

## Security Considerations

1. **Firestore Rules**: All collections are locked to Admin SDK only
2. **CORS**: Configured for your app domain
3. **Token Cleanup**: Stale tokens auto-cleaned after 30 days
4. **Rate Limiting**: Consider adding rate limiting for production

## Monitoring

- View logs: `firebase functions:log`
- Firebase Console: Functions → Logs
- Set up alerts for error rates

## Troubleshooting

### "Invalid FCM token" errors
- Token may have expired or app was uninstalled
- Tokens are auto-cleaned, no action needed

### Notifications not received
1. Check device has notification permissions
2. Verify FCM token is registered in Firestore
3. Check Cloud Functions logs for errors
4. Ensure app is properly configured (google-services.json / GoogleService-Info.plist)

### iOS notifications not working
1. Ensure APNs key is uploaded to Firebase
2. Check Push Notification capability is enabled in Xcode
3. Verify background modes are set in Info.plist
