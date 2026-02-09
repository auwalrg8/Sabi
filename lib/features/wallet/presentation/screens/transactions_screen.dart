import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/wallet/presentation/providers/pending_payments_provider.dart';
import 'package:sabi_wallet/features/wallet/presentation/providers/recent_transactions_provider.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/payment_detail_screen.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/payment_debug_screen.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/unclaimed_deposits_screen.dart';
import 'package:sabi_wallet/core/utils/date_utils.dart' as date_utils;
import 'package:sabi_wallet/l10n/app_localizations.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(allTransactionsNotifierProvider);
    final pendingAsync = ref.watch(pendingPaymentsProvider);
    final pendingPayments =
        pendingAsync.valueOrNull ?? const <PendingPaymentRecord>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (pendingPayments.isNotEmpty)
              _buildPendingSection(context, pendingPayments),
            Expanded(
              child: paymentsAsync.when(
                data: (payments) {
                  if (payments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 80.sp,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'No transactions yet',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Your transaction history will appear here',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    backgroundColor: AppColors.surface,
                    color: AppColors.primary,
                    onRefresh: () async {
                      await ref
                          .read(allTransactionsNotifierProvider.notifier)
                          .refresh();
                    },
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 12.h,
                      ),
                      itemCount: payments.length,
                      itemBuilder: (context, index) {
                        final payment = payments[index];
                        final isInbound = payment.isIncoming;
                        final amountColor =
                            isInbound
                                ? AppColors.accentGreen
                                : const Color(0xFFFF4D4F);
                        final amountPrefix = isInbound ? '+' : '-';

                        final timeStr = date_utils.formatTransactionTime(
                          payment.paymentTime,
                        );

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        PaymentDetailScreen(payment: payment),
                              ),
                            );
                          },
                          child: Container(
                            margin: EdgeInsets.only(bottom: 12.h),
                            padding: EdgeInsets.all(16).w,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48.w,
                                  height: 48.h,
                                  decoration: BoxDecoration(
                                    color:
                                        isInbound
                                            ? AppColors.accentGreen.withValues(
                                              alpha: 0.1,
                                            )
                                            : const Color(
                                              0xFFFF4D4F,
                                            ).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isInbound
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    color: amountColor,
                                    size: 24.sp,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isInbound
                                            ? AppLocalizations.of(
                                              context,
                                            )!.received
                                            : AppLocalizations.of(
                                              context,
                                            )!.sent,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$amountPrefix${payment.amountSats} sats',
                                      style: TextStyle(
                                        color: amountColor,
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading:
                    () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                error:
                    (error, stack) => Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 60.sp,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'Failed to load transactions',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16.sp,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              error.toString(),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.sp,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16.h),
                            ElevatedButton(
                              onPressed:
                                  () =>
                                      ref
                                          .read(
                                            allTransactionsNotifierProvider
                                                .notifier,
                                          )
                                          .refresh(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 10.w),
          Text(
            'All Transactions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Bitcoin pending deposits button
          Material(
            color: Colors.transparent,
            child: Tooltip(
              message: 'Pending Bitcoin Deposits',
              child: IconButton(
                icon: const Icon(
                  Icons.currency_bitcoin_rounded,
                  color: Color(0xFFF7931A),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UnclaimedDepositsScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
          // Debug button - tap 3 times to show
          Material(
            color: Colors.transparent,
            child: Tooltip(
              message: 'Payment Debug Info',
              child: IconButton(
                icon: const Icon(
                  Icons.bug_report_outlined,
                  color: AppColors.primary,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PaymentDebugScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSection(
    BuildContext context,
    List<PendingPaymentRecord> pendingPayments,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.paymentPending,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${pendingPayments.length} ${l10n.pending.toLowerCase()}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Column(
            children:
                pendingPayments
                    .map((payment) => _buildPendingTile(context, payment))
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTile(BuildContext context, PendingPaymentRecord payment) {
    final statusText = _formatPendingDuration(payment.startedAt);
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(16.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.h,
            decoration: BoxDecoration(
              color: AppColors.accentYellow.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.hourglass_top,
              color: AppColors.accentYellow,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.recipientName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${AppLocalizations.of(context)!.pending} • $statusText',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${payment.amountSats} sats',
            style: TextStyle(
              color: AppColors.accentYellow,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPendingDuration(DateTime startedAt) {
    final diff = DateTime.now().difference(startedAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
