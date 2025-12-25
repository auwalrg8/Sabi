import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/widgets/widgets.dart';
import 'package:sabi_wallet/features/wallet/domain/models/send_transaction.dart';
import 'package:sabi_wallet/l10n/app_localizations.dart';
import 'package:sabi_wallet/services/receipt_service.dart';

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
  final GlobalKey _receiptKey = GlobalKey();
  bool _isSharing = false;

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

  Future<void> _shareAsImage() async {
    setState(() => _isSharing = true);
    try {
      await ReceiptService.shareAsImage(
        _receiptKey,
        subject: 'Sabi Wallet Payment Receipt',
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _shareAsPdf() async {
    setState(() => _isSharing = true);
    try {
      final data = ReceiptData(
        type: 'send',
        recipientName: widget.transaction.recipient.name,
        recipientIdentifier: widget.transaction.recipient.identifier,
        amountSats: widget.transaction.amountInSats.toInt(),
        amountNgn:
            widget.transaction.amount > 0 ? widget.transaction.amount : null,
        feeSats: widget.transaction.feeSats,
        memo: widget.transaction.memo,
        timestamp: _completedAt,
        transactionId: widget.transaction.transactionId,
      );
      await ReceiptService.shareAsPdf(data);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.shareOptionsTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12.h),
              _buildShareOption(
                icon: Icons.image_rounded,
                title: AppLocalizations.of(context)!.shareImage,
                subtitle: AppLocalizations.of(context)!.shareImageSubtitle,
                onTap: () {
                  Navigator.pop(context);
                  _shareAsImage();
                },
              ),
              SizedBox(height: 8.h),
              _buildShareOption(
                icon: Icons.picture_as_pdf_rounded,
                title: AppLocalizations.of(context)!.sharePdf,
                subtitle: AppLocalizations.of(context)!.sharePdfSubtitle,
                onTap: () {
                  Navigator.pop(context);
                  _shareAsPdf();
                },
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textSecondary,
                size: 16.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountSats = widget.transaction.amountInSats.toStringAsFixed(0);
    final timeText =
        '${_completedAt.day}/${_completedAt.month}/${_completedAt.year} • ${_completedAt.hour.toString().padLeft(2, '0')}:${_completedAt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                  child: Row(
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.paymentSuccess,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        },
                        child: Container(
                          width: 40.w,
                          height: 40.h,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: RepaintBoundary(
                      key: _receiptKey,
                      child: Container(
                        color: AppColors.background,
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Column(
                          children: [
                            SizedBox(height: 40.h),
                            // Success animation
                            ScaleTransition(
                              scale: _pulse,
                              child: Container(
                                width: 120.w,
                                height: 120.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.accentGreen,
                                      AppColors.accentGreen.withValues(
                                        alpha: 0.7,
                                      ),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accentGreen.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 30,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 56.sp,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 24.h),
                            Text(
                              'Payment Sent!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              AppLocalizations.of(context)!.paymentSentHeadline,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(height: 32.h),
                            // Amount display
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 24.h),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.15),
                                    AppColors.primary.withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Amount sent',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13.sp,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    '$amountSats sats',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 32.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (widget.transaction.amount > 0) ...[
                                    SizedBox(height: 4.h),
                                    Text(
                                      '≈ ₦${widget.transaction.amount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(height: 20.h),
                            // Transaction details
                            SummaryCard(
                              title: 'TRANSACTION DETAILS',
                              items: [
                                SummaryItem(
                                  label: 'Recipient',
                                  value: widget.transaction.recipient.name,
                                  subtitle:
                                      widget.transaction.recipient.identifier,
                                  icon: Icons.person_outline_rounded,
                                ),
                                SummaryItem(
                                  label: 'Time',
                                  value: timeText,
                                  icon: Icons.schedule_rounded,
                                ),
                                if (widget.transaction.memo != null &&
                                    widget.transaction.memo!.isNotEmpty)
                                  SummaryItem(
                                    label: 'Note',
                                    value: widget.transaction.memo!,
                                    icon: Icons.note_alt_outlined,
                                  ),
                                if (widget.transaction.feeSats != null &&
                                    widget.transaction.feeSats! > 0)
                                  SummaryItem(
                                    label: 'Network Fee',
                                    value: '${widget.transaction.feeSats} sats',
                                    icon: Icons.bolt_rounded,
                                    valueColor: AppColors.textSecondary,
                                  ),
                              ],
                            ),
                            SizedBox(height: 24.h),
                            Text(
                              'Powered by Sabi Wallet',
                              style: TextStyle(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 11.sp,
                              ),
                            ),
                            SizedBox(height: 16.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom buttons
                Container(
                  padding: EdgeInsets.all(20.h),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56.h,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.home_rounded, size: 20.sp),
                              SizedBox(width: 8.w),
                              Text(
                                AppLocalizations.of(context)!.backToHome,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        width: double.infinity,
                        height: 52.h,
                        child: OutlinedButton(
                          onPressed:
                              _isSharing
                                  ? null
                                  : () {
                                    HapticFeedback.lightImpact();
                                    _showShareOptions();
                                  },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.share_rounded,
                                color: AppColors.primary,
                                size: 18.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                AppLocalizations.of(context)!.shareReceipt,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Loading overlay
          if (_isSharing)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(24.r),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16.h),
                      Text(
                        'Generating receipt...',
                        style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
