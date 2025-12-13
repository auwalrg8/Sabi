import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import '../../domain/models/cash_transaction.dart';
import '../providers/cash_provider.dart';

class CashHistoryScreen extends ConsumerWidget {
  const CashHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashState = ref.watch(cashProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 25.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'Cash History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 30.w),
                itemCount: cashState.transactions.length,
                itemBuilder: (context, index) {
                  final transaction = cashState.transactions[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: _TransactionCard(transaction: transaction),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final CashTransaction transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isBuy = transaction.type == CashTransactionType.buy;
    final iconColor = isBuy ? AppColors.accentGreen : AppColors.accentRed;
    final iconBgColor =
        isBuy
            ? AppColors.accentGreen.withValues(alpha: 0.2)
            : AppColors.accentRed.withValues(alpha: 0.2);
    final formatter = NumberFormat('#,###');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
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
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBuy ? Icons.trending_up : Icons.trending_down,
              color: iconColor,
              size: 20,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBuy ? 'Bought' : 'Sold',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.formattedDate,
                  style: TextStyle(
                    color: AppColors.textTertiary,
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
                '${isBuy ? '+' : '−'}${formatter.format(transaction.amountSats)} sats',
                style: TextStyle(
                  color: isBuy ? AppColors.accentGreen : Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '${isBuy ? '−' : '+'}₦${formatter.format(transaction.amountNGN.toInt())}',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
