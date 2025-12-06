import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:intl/intl.dart';
import '../providers/cash_provider.dart';
import 'payment_processing_screen.dart';

class ReviewPayScreen extends ConsumerStatefulWidget {
  const ReviewPayScreen({super.key});

  @override
  ConsumerState<ReviewPayScreen> createState() => _ReviewPayScreenState();
}

class _ReviewPayScreenState extends ConsumerState<ReviewPayScreen> {
  Timer? _timer;
  int _remainingSeconds = 15 * 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.accentGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cashState = ref.watch(cashProvider);
    final formatter = NumberFormat('#,###');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Review & Pay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 17),
                    Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: const Color(0x1A111128),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.accentRed),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: AppColors.accentRed,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Complete payment in',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _formatTime(_remainingSeconds),
                                style: const TextStyle(
                                  color: AppColors.accentRed,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 17),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildRow(
                            'You pay',
                            '₦${formatter.format(cashState.totalToPay.toInt())}',
                            isTitle: true,
                          ),
                          const SizedBox(height: 12),
                          _buildRow(
                            'You get',
                            '~${formatter.format(cashState.estimatedSats)} sats',
                            valueColor: AppColors.accentGreen,
                            isTitle: true,
                          ),
                          const SizedBox(height: 12),
                          _buildRow(
                            'Fee',
                            '₦${formatter.format(cashState.fee.toInt())}',
                            valueSize: 12,
                            labelColor: const Color(0xFF6B7280),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 17),
                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 17),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildPaymentDetail(context, 'Bank', 'GTBank', false),
                          const SizedBox(height: 16),
                          _buildPaymentDetail(
                            context,
                            'Account Number',
                            '069 420 1337',
                            false,
                          ),
                          const SizedBox(height: 16),
                          _buildPaymentDetail(
                            context,
                            'Account Name',
                            'Sabi Wallet Limited',
                            false,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 1,
                            color: const Color(0xFF1F2937),
                          ),
                          const SizedBox(height: 16),
                          _buildPaymentDetail(
                            context,
                            'Reference',
                            cashState.currentReference ?? 'SAB-BUY-9K2M7P',
                            true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 17),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(36),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.qr_code_2,
                              size: 120,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Scan with GTBank or Opay app',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(31, 0, 31, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PaymentProcessingScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'I Have Paid',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Upload proof of payment after clicking',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    Color? valueColor,
    Color? labelColor,
    double? valueSize,
    bool isTitle = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor ?? AppColors.textTertiary,
            fontSize: isTitle ? 14 : 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: valueSize ?? (isTitle ? 17 : 12),
            fontWeight: isTitle ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentDetail(
    BuildContext context,
    String label,
    String value,
    bool isHighlighted,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: isHighlighted ? AppColors.primary : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () => _copyToClipboard(context, value, label),
          icon: Icon(
            Icons.copy,
            size: 18,
            color: isHighlighted ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
