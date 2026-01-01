import 'package:flutter/material.dart';
import 'package:sabi_wallet/main.dart' show initializeWalletIfExists;
import 'package:sabi_wallet/services/app_state_service.dart';
import 'package:sabi_wallet/features/auth/presentation/screens/biometric_auth_screen.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/home_screen.dart';
import 'entry_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusText = 'Loading...';

  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Small delay to ensure UI is rendered
    await Future.delayed(const Duration(milliseconds: 100));

    // Check if wallet exists
    final hasWallet = AppStateService.hasWallet;

    if (hasWallet) {
      if (mounted) setState(() => _statusText = 'Recovering wallet...');

      // Initialize wallet (the heavy operation)
      final walletReady = await initializeWalletIfExists();

      if (mounted) {
        if (walletReady) {
          // Wallet recovered, go to auth then home
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => BiometricAuthScreen(child: const HomeScreen()),
            ),
          );
        } else {
          // Wallet recovery failed, go to entry
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const EntryScreen()),
          );
        }
      }
    } else {
      // No wallet, go to entry screen after brief splash
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EntryScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Sabi Wallet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Self-hosted Bitcoin Lightning',
              style: TextStyle(
                color: Color(0xFF8B92A8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFFFFA500),
                ),
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _statusText,
              style: const TextStyle(
                color: Color(0xFF8B92A8),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
