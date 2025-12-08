import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/home_screen.dart';
import 'seed_recovery_screen.dart';

class EntryScreen extends ConsumerStatefulWidget {
  const EntryScreen({super.key});

  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen> {
  bool _isLoading = false;

  Future<void> _createNewWallet() async {
    setState(() => _isLoading = true);

    try {
      // Generate new wallet
      await BreezSparkService.initializeSparkSDK();
      
      // Mark onboarding complete
      await BreezSparkService.setOnboardingComplete();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating wallet: $e'),
            backgroundColor: const Color(0xFFFF4D4F),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreWallet() async {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SeedRecoveryScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Welcome to Sabi Wallet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Self-custodial Bitcoin & Lightning in your pocket',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Buttons
              Column(
                children: [
                  // Create Wallet Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createNewWallet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFA500),
                        disabledBackgroundColor: const Color(0xFFFFA500).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black.withValues(alpha: 0.8),
                                ),
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.add, color: Colors.black),
                      label: Text(
                        _isLoading ? 'Creating...' : "Let's Sabi ₿",
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Restore Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _restoreWallet,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFF1F2937),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Restore',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
