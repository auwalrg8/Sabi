import 'package:flutter/material.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/wallet/domain/models/send_transaction.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/send_success_screen.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

class SendProgressScreen extends StatefulWidget {
  final SendTransaction transaction;

  const SendProgressScreen({super.key, required this.transaction});

  @override
  State<SendProgressScreen> createState() => _SendProgressScreenState();
}

class _SendProgressScreenState extends State<SendProgressScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // ACTUAL PAYMENT EXECUTION
    _executePayment();
  }

  Future<void> _executePayment() async {
    try {
      // Convert NGN amount to sats (using the amountInSats from transaction model)
      final amountSats = widget.transaction.amountInSats.toInt();
      
      // Send payment via Breez Spark SDK with amount
      final result = await BreezSparkService.sendPayment(
        widget.transaction.recipient.identifier,
        sats: amountSats,
      );
      
      // Extract actual fees and amounts from SDK response
      final actualAmountSats = BreezSparkService.extractSendAmountSats(result);
      final actualFeeSats = BreezSparkService.extractSendFeeSats(result);
      
      debugPrint('✅ Payment sent: $actualAmountSats sats, fee: $actualFeeSats sats');
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SendSuccessScreen(transaction: widget.transaction),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Payment failed: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 80,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment Failed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentRed,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Go Back',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 201,
                      height: 201,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 4,
                        ),
                      ),
                    ),
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.flash_on,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 66),
              const Text(
                'Sending...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 29),
              const Text(
                'Please wait',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 29),
              SizedBox(
                width: 160,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
