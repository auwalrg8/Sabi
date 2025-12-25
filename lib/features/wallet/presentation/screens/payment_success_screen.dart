import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/widgets/widgets.dart';
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
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
              ),
              ListTile(
                onTap: () {
                  Navigator.pop(context);
                  _shareReceipt('PDF');
                },
                leading: const Icon(
                  Icons.picture_as_pdf,
                  color: AppColors.primary,
                ),
                title: Text(
                  AppLocalizations.of(context)!.sharePdf,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  AppLocalizations.of(context)!.sharePdfSubtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                  ),
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
    final amountSats = widget.transaction.amountInSats.toStringAsFixed(0);
    final timeText =
        '${_completedAt.day}/${_completedAt.month}/${_completedAt.year} • ${_completedAt.hour.toString().padLeft(2, '0')}:${_completedAt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                      Navigator.of(context).popUntil((route) => route.isFirst);
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
                              AppColors.accentGreen.withValues(alpha: 0.7),
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

                    // Success message
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
                          color: AppColors.primary.withValues(alpha: 0.3),
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
                          subtitle: widget.transaction.recipient.identifier,
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
                        if (widget.transaction.feeSats > 0)
                          SummaryItem(
                            label: 'Network Fee',
                            value: '${widget.transaction.feeSats} sats',
                            icon: Icons.bolt_rounded,
                            valueColor: AppColors.textSecondary,
                          ),
                      ],
                    ),

                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Container(
              padding: EdgeInsets.all(20.h),
              child: Column(
                children: [
                  // Back to home button
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

                  // Share receipt button
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: OutlinedButton(
                      onPressed: () {
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
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
        ),
        SizedBox(height: 6.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientDetailRow() {
    final identifier = widget.transaction.recipient.identifier;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.recipient,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
        ),
        SizedBox(height: 6.h),
        Text(
          widget.transaction.recipient.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          identifier,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }
}
