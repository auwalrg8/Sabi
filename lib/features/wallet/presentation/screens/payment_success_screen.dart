import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/wallet/domain/models/send_transaction.dart';
import 'package:sabi_wallet/l10n/app_localizations.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final SendTransaction transaction;

  const PaymentSuccessScreen({super.key, required this.transaction});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;
  late final DateTime _completedAt;

  @override
  void initState() {
    super.initState();
    _completedAt = DateTime.now();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _shareReceipt(String option) {
    final message = '''Payment Receipt

Recipient: ${widget.transaction.recipient.name}
Identifier: ${widget.transaction.recipient.identifier}
Amount: ${widget.transaction.amountInSats.toStringAsFixed(0)} sats
Memo: ${widget.transaction.memo ?? '—'}
Shared as: $option''';
    Share.share(message, subject: 'Sabi Payment Receipt');
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.shareOptionsTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                onTap: () {
                  Navigator.pop(context);
                  _shareReceipt('Image');
                },
                leading: const Icon(Icons.image, color: AppColors.primary),
                title: Text(
                  AppLocalizations.of(context)!.shareImage,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  AppLocalizations.of(context)!.shareImageSubtitle,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              ListTile(
                onTap: () {
                  Navigator.pop(context);
                  _shareReceipt('PDF');
                },
                leading: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
                title: Text(
                  AppLocalizations.of(context)!.sharePdf,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  AppLocalizations.of(context)!.sharePdfSubtitle,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountText = '${widget.transaction.amountInSats.toStringAsFixed(0)} sats';
    final timeText = '${_completedAt.day}/${_completedAt.month}/${_completedAt.year} • ${_completedAt.hour.toString().padLeft(2, '0')}:${_completedAt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 44),
                  Text(
                    AppLocalizations.of(context)!.paymentSuccess,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: ScaleTransition(
                  scale: _pulse,
                  child: Container(
                    width: 160.w,
                    height: 160.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accentGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGreen.withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                AppLocalizations.of(context)!.paymentSentHeadline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(20.h),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDetailRow(AppLocalizations.of(context)!.recipient, widget.transaction.recipient.name),
                    const SizedBox(height: 12),
                    _buildDetailRow(AppLocalizations.of(context)!.identifier, widget.transaction.recipient.identifier),
                    const SizedBox(height: 12),
                    _buildDetailRow(AppLocalizations.of(context)!.amount, amountText),
                    const SizedBox(height: 12),
                    _buildDetailRow(AppLocalizations.of(context)!.transactionTime, timeText),
                    if (widget.transaction.memo != null && widget.transaction.memo!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(AppLocalizations.of(context)!.memo, widget.transaction.memo!),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
                child: Text(
                  AppLocalizations.of(context)!.backToHome,
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _showShareOptions,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
                child: Text(
                  AppLocalizations.of(context)!.shareReceipt,
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
