import 'package:flutter/material.dart';
import 'dart:async';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/home_screen.dart';

class WalletSuccessScreen extends StatefulWidget {
  const WalletSuccessScreen({super.key});

  @override
  State<WalletSuccessScreen> createState() => _WalletSuccessScreenState();
}

class _WalletSuccessScreenState extends State<WalletSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _rocketController;
  late AnimationController _scaleController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startNavigation();
  }

  void _initializeAnimations() {
    // Rocket launch animation (moves up)
    _rocketController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Scale pulse animation
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    // Fade animation for text
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Start animations
    _rocketController.forward();
    _fadeController.forward();
  }

  void _startNavigation() {
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  @override
  void dispose() {
    _rocketController.dispose();
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Animated background stars/particles
          _buildBackgroundAnimation(),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Rocket animation
                AnimatedBuilder(
                  animation: _rocketController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        0,
                        -500 * _rocketController.value,
                      ),
                      child: child,
                    );
                  },
                  child: _buildRocket(),
                ),

                const SizedBox(height: 60),

                // Success message with fade animation
                FadeTransition(
                  opacity: _fadeController,
                  child: Column(
                    children: [
                      const Text(
                        'Wallet Created!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          height: 40 / 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your Bitcoin wallet is ready to use',
                        style: TextStyle(
                          color: Color(0xFFCCCCCC),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 24 / 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Loading indicator at bottom
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Taking you to your wallet...',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRocket() {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.1).animate(_scaleController),
      child: Container(
        width: 80,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(40),
        ),
        child: const Center(
          child: Text(
            '🚀',
            style: TextStyle(fontSize: 60),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundAnimation() {
    return Stack(
      children: List.generate(
        15,
        (index) {
          final delay = (index * 100).toDouble();

          return Positioned(
            left: (index * 30).toDouble() % 400,
            top: (index * 60).toDouble() % 800,
            child: AnimatedBuilder(
              animation: _rocketController,
              builder: (context, child) {
                final opacity = (1.0 - (_rocketController.value + (delay / 3000)))
                    .clamp(0.0, 1.0)
                    .toDouble();

                return Opacity(
                  opacity: opacity * 0.3,
                  child: child,
                );
              },
              child: const Text(
                '✨',
                style: TextStyle(fontSize: 24),
              ),
            ),
          );
        },
      ),
    );
  }
}
