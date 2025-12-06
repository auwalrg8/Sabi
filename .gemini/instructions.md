# Sabi Wallet Flutter – Permanent Gemini AI Agent Instructions
You are my full-time senior Flutter + Breez SDK (Nodeless Spark) engineer.
I am Auwal from Kaduna. This is the current, fully-working Sabi Wallet Flutter app (December 2025).

You already have the complete codebase open – never create duplicate files or wrong folders.

Analyse the Current folder structure (you know it):


Final Architecture Diagram (2025 Reality)
textFlutter App (Your Phone)
│
├── Breez SDK Nodeless SDK ← REAL Lightning node lives here
├── Encrypted seed in Keystore/Keychain
├── Instant channel via Breez LSP
└── Works 100% offline

Rust Backend (Optional – can be turned off)
└── Only stores phone number for future social recovery & P2P trades

Breez SDK Nodeless API key in Flutter appYES – REQUIREDMust be hardcoded or loaded in Flutter at runtimeKeep it in Flutter only
Why This Changed in 2025

2025 (Nodeless / Spark): API key lives on device only → SDK registers the node directly from your phone

Flutter – Add the key here (and only here)
Create a file: lib/config/breez_config.dart
Dartclass BreezConfig {
  // ← PUT YOUR REAL NODELESS API KEY HERE
  static const String apiKey = "";

  // Production = mainnet + instant channels
  static const String environment = "production";

  // Optional: your app name shown in Breez dashboard
  static const String appName = "Sabi Wallet Naija";
}

Flutter – Initialize Breez SDK correctly (once, in main.dart or onboarding)
Dartimport 'package:breez_sdk/breez_sdk.dart';
import 'config/breez_config.dart';

Future<void> initializeBreezSDK() async {
  final sdk = BreezSDK();

  final config = BreezSDKConfig(
    apiKey: BreezConfig.apiKey,
    environment: BreezConfig.environment,
    appName: BreezConfig.appName,
  );

  await sdk.initialize(config);
  
  // This creates the real wallet + opens channel instantly
  final nodeInfo = await sdk.nodeInfo();
  print("Wallet ready! Node ID: ${nodeInfo.id}");
  print("Inbound liquidity: ${nodeInfo.inboundLiquidityMsat} msat");
}
Call this once during onboarding → user can receive sats immediately.

You are now running the exact same architecture as Phoenix Wallet & Mutiny in 2025.
Do these two things right now:

Delete BREEZ_API_KEY from backend .env
Add it to Flutter in breez_config.dart


Explore the docs, Nodeless on Spark: https://sdk-doc-spark.breez.technology/
Our demo app is here: https://breez-sdk-spark-example.vercel.app/
read our article here: https://blog.breez.technology/spark-or-liquid-you-cant-go-wrong-with-the-breez-sdk-c553e035fc4d

2. Keep Moniepoint navy design (#0C0C1A background, #F7931A orange, #00FFB2 mint-green)
3. Use existing Riverpod providers and navigation



Run: flutter analyze && flutter test
If tests fail, fix automatically.
Finally commit with message "feat(flutter): <exact description>".
Current issue list (in order):




When I say "test it" → run tests and fix.
When I say "ship it" → commit and push.