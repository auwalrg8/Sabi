// ignore_for_file: unused_element
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

class WalletCreationAnimationScreen extends ConsumerStatefulWidget {
  const WalletCreationAnimationScreen({super.key});

  @override
  ConsumerState<WalletCreationAnimationScreen> createState() =>
      _WalletCreationAnimationScreenState();
}

class _WalletCreationAnimationScreenState
    extends ConsumerState<WalletCreationAnimationScreen> {
  int _currentStep = 0;
  final _storage = const FlutterSecureStorage();
  final _audio = AudioPlayer();
  bool _hasLottie = false;

  final List<String> _steps = [
    'Creating your wallet...',
    'Opening Lightning channel...',
    'Your wallet is ready!',
  ];

  @override
  void initState() {
    super.initState();
    _detectAssetsAndStart();
  }

  Future<void> _detectAssetsAndStart() async {
    // Try to load lottie asset presence
    try {
      await DefaultAssetBundle.of(
        context,
      ).loadString('assets/anim/rocket_launch.json');
      _hasLottie = true;
    } catch (_) {
      _hasLottie = false;
    }

    await _startAnimation();
  }

  Future<void> _startAnimation() async {
    // Step 1: Creating your wallet
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _currentStep = 1);

    // Step 2: Opening Lightning channel
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _currentStep = 2);

    // Step 3: Ready + confetti
    await Future.delayed(const Duration(milliseconds: 1500));

    // Play short success sound (if available)
    try {
      await _audio.play(AssetSource('audio/cha_ching.mp3'));
    } catch (_) {}

    // Save flag so we never show this again
    await _storage.write(key: 'has_seen_creation_animation', value: 'true');

    // Navigate to Home
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _currentStep == 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rocket/Lightning animation or Lottie
                  _buildAnimation(isReady),
                  const SizedBox(height: 40),

                  // Text sequence
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      _steps[_currentStep],
                      key: ValueKey<int>(_currentStep),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),

                  if (_currentStep < 2) ...[
                    const SizedBox(height: 20),
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Confetti overlay when ready
          // Confetti during creation removed for nodeless era.
        ],
      ),
    );
  }

  Widget _buildAnimation(bool isReady) {
    if (_hasLottie) {
      return SizedBox(
        width: 220,
        height: 220,
        child: Lottie.asset(
          'assets/anim/rocket_launch.json',
          repeat: true,
          animate: true,
        ),
      );
    }

    return Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color:
                isReady
                    ? AppColors.accentGreen.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
                  isReady
                      ? Icons.check_circle_outline
                      : Icons.rocket_launch_outlined,
                  size: 80,
                  color: isReady ? AppColors.accentGreen : AppColors.primary,
                )
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(
                  duration: 2000.ms,
                  color: Colors.white.withValues(alpha: 0.3),
                )
                .then()
                .shake(hz: 2, duration: 500.ms),
          ),
        )
        .animate()
        .scale(duration: 600.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 400.ms);
  }
}

class _ConfettiOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(
        30,
        (index) => _ConfettiPiece(
          delay: Duration(milliseconds: index * 50),
          horizontalOffset: (index % 10 - 5) * 40.0,
        ),
      ),
    );
  }
}

class _ConfettiPiece extends StatelessWidget {
  final Duration delay;
  final double horizontalOffset;

  const _ConfettiPiece({required this.delay, required this.horizontalOffset});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF98FF98), // Mint-green
      const Color(0xFF98FF98),
      const Color(0xFF98FF98),
      const Color(0xFF98FF98),
    ];

    return Positioned(
      top: -20,
      left: MediaQuery.of(context).size.width / 2 + horizontalOffset,
      child: Container(
            width: 8,
            height: 16,
            decoration: BoxDecoration(
              color: colors[horizontalOffset.toInt().abs() % colors.length],
              borderRadius: BorderRadius.circular(2),
            ),
          )
          .animate(delay: delay)
          .moveY(
            begin: 0,
            end: MediaQuery.of(context).size.height + 50,
            duration: 2500.ms,
            curve: Curves.easeIn,
          )
          .fadeOut(begin: 0.8),
    );
  }
}
