# Sabi Wallet — Backend Overview (Frontend Developer README)

This short README explains the backend endpoints and flows the Flutter frontend consumes.

Summary
- Base URL (dev): `http://localhost:3000`
- Base URL (prod example): `https://api.sabi.money`
- The backend owns Breez SDK integration — frontend talks only to the backend.

Primary Endpoints

1) Create Wallet
- POST `/api/v1/wallets/create`
- Request JSON:
  ```json
  {
    "device_id": "test-device-001",
    "phone": "+2348012345678"
  }
  ```
- Success (200):
  ```json
  {
    "wallet_id": "<uuidv7>",
    "invite_code": "SABI-XXXXX",
    "node_id": "<node_pubkey>"
  }
  ```
- Failure (400): `{ "error": "validation message" }`
- Failure (500): `{ "error": "Server error" }`

2) Get Wallet Info
- GET `/api/v1/wallets/:user_id`
- Returns wallet info or error object.

3) Rates
- GET `/api/v1/rates`
- Returns:
  ```json
  { "naira_to_btc": 0.00001234, "last_updated_at": "..." }
  ```
- Interpretation: `1 NGN = naira_to_btc BTC`. To convert sats → NGN frontend computes:
  - BTC = sats / 1e8
  - NGN = BTC / naira_to_btc  (since naira_to_btc = NGN in BTC units)

Other endpoints (overview)
- POST `/recovery/request` — initiate Nostr recovery shares
- POST `/recovery/submit` — submit encrypted recovery share
- POST `/webhook/breez` — Breez webhooks
- POST `/webhook/paystack` — Paystack webhooks
- POST `/ussd` — USSD callback (x-www-form-urlencoded)

Authentication
- Public endpoints (including `/wallet/create` and `/wallet/:user_id`) do NOT require client auth.
- Admin endpoints under `/admin/*` require `Authorization: Bearer <JWT>`.

Notes for Frontend Implementation
- The backend manages Breez SDK; the frontend should NOT expect any Breez secrets or mnemonics.
- After creating a wallet the frontend should call `GET /wallet/:user_id` and use returned `connection_details` and balances.
- Error format: `{ "error": "message" }` with appropriate HTTP status codes.

Local Testing
1. Start backend locally: `http://localhost:3000`
2. Run Flutter app and exercise onboarding → "Get Started".

If you need typed models or sample responses for a specific endpoint, paste the endpoint name and I'll add the model and sample tests to the repo.
