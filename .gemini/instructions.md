# Sabi Wallet Flutter – Permanent Gemini AI Agent Instructions
You are my full-time senior Flutter + Breez SDK (Nodeless Spark) + Nostr engineer.
I am Auwal from Kaduna. This is the current, fully-working Sabi Wallet Flutter app (December 2025).

You already have the complete codebase open – never create duplicate files or wrong folders.

Analyse the Current folder structure (you know it):

IMPLEMENT FULL NOSTR FEATURE SET (100% Production Ready – Moniepoint Style)

Add complete Nostr integration to Sabi Wallet using nostr_sdk Flutter package. Follow these exact steps:

1. Add dependency to pubspec.yaml:
   nostr_sdk: ^0.32.0

2. Create/update file: lib/services/nostr_service.dart
   - Generate or import npub/nsec
   - Save to Hive (encrypted)
   - Add relay list (wss://relay.damus.io, wss://nostr-pub.wellorder.net, etc.)
   - Implement getProfile(), sendZap(), listenForZaps()

3. Create/update screens (all in Moniepoint style):
   - ProfileScreen: show npub (shortened), copy button, orange “Add/Edit Nostr” button
   - EditNostrScreen: paste npub/nsec, scan QR, Nostr Wallet Connect
   - ZapsTab: clean feed with avatar left, orange ⚡ zap button right
   - ZapSlider: 21 → 210 → 1k → 10k → custom sats + memo

4. In HomeScreen:
   - Zaps tab
   - Show banner if npub missing: “Add Nostr for zaps & recovery” (orange button)

5. In ReceiveScreen:
   - Add toggle: “Receive via Nostr npub” (shows npub QR)

6. In Settings:
   - Add “Nostr Profile” section with edit button

7. Zap flow:
   - One-tap zap slider on every post
   - On zap sent: mint-green confetti + haptic
   - On zap received: show “You just got zapped 1,000 sats!” notification

8. Profile stats:
   - “Zapped 127 times · 84,321 sats received”

9. Run:
   flutter clean && flutter pub get && flutter run

After completion, reply “”Nostr features 100% implemented with screenshots of:
- Profile page with npub
- Zaps tab with feed
- Zap slider
- Receive screen with npub toggle

This completes Sabi Wallet as the first full Bitcoin + Lightning + Nostr wallet for Nigeria — Moniepoint-style, production-ready.

Do it NOW — no more delays.





2. Keep Moniepoint navy design (#0C0C1A background, #F7931A orange, #00FFB2 mint-green)
3. Use existing Riverpod providers and navigation



Run: flutter analyze && flutter test
If tests fail, fix automatically.
Finally commit with message "feat(flutter): <exact description>".




When I say "test it" → run tests and fix.
When I say "ship it" → commit and push.