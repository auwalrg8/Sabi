import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

class UnclaimedDepositsScreen extends ConsumerStatefulWidget {
  const UnclaimedDepositsScreen({super.key});

  @override
  ConsumerState<UnclaimedDepositsScreen> createState() =>
      _UnclaimedDepositsScreenState();
}

class _UnclaimedDepositsScreenState
    extends ConsumerState<UnclaimedDepositsScreen> {
  List<DepositInfo>? _deposits;
  bool _loading = true;
  String? _error;
  RecommendedFees? _recommendedFees;

  @override
  void initState() {
    super.initState();
    _loadDeposits();
  }

  Future<void> _loadDeposits() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final deposits = await BreezSparkService.listUnclaimedDeposits();
      final fees = await BreezSparkService.getRecommendedFees();
      if (mounted) {
        setState(() {
          _deposits = deposits;
          _recommendedFees = fees;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _claimDeposit(DepositInfo deposit) async {
    // Get required fee from claim error if available
    int requiredFee = 0;
    if (deposit.claimError != null) {
      if (deposit.claimError case DepositClaimError_MaxDepositClaimFeeExceeded feeError) {
        requiredFee = feeError.requiredFeeSats.toInt();
      }
    }

    if (requiredFee == 0) {
      // Use fastest recommended fee
      requiredFee = (_recommendedFees?.fastestFee.toInt() ?? 10) * 200; // Estimate vbytes
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Claim Deposit',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount: ${deposit.amountSats} sats',
              style: const TextStyle(color: Colors.white),
            ),
            SizedBox(height: 8.h),
            Text(
              'Claim fee: ~$requiredFee sats',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 16.h),
            Text(
              'Do you want to claim this deposit?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF7931A),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Claim'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await BreezSparkService.claimDeposit(
          txid: deposit.txid,
          vout: deposit.vout,
          maxFeeSats: requiredFee,
        );
        _showSnack('Deposit claimed successfully!');
        _loadDeposits();
      } catch (e) {
        _showSnack(
          'Failed to claim: ${e.toString().replaceAll('Exception: ', '')}',
          isError: true,
        );
      }
    }
  }

  Future<void> _refundDeposit(DepositInfo deposit) async {
    final addressController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Refund Deposit',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount: ${deposit.amountSats} sats',
              style: const TextStyle(color: Colors.white),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: addressController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter Bitcoin address',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            onPressed: () {
              if (addressController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid address')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Refund'),
          ),
        ],
      ),
    );

    if (confirmed == true && addressController.text.trim().isNotEmpty) {
      try {
        final feeSatPerVbyte = _recommendedFees?.halfHourFee.toInt() ?? 5;
        await BreezSparkService.refundDeposit(
          txid: deposit.txid,
          vout: deposit.vout,
          destinationAddress: addressController.text.trim(),
          feeSatPerVbyte: feeSatPerVbyte,
        );
        _showSnack('Refund transaction broadcast!');
        _loadDeposits();
      } catch (e) {
        _showSnack(
          'Refund failed: ${e.toString().replaceAll('Exception: ', '')}',
          isError: true,
        );
      }
    }
    addressController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              'Pending Deposits',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: _loadDeposits,
            icon: Icon(
              Icons.refresh_rounded,
              color: AppColors.primary,
              size: 24.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: const Color(0xFFF7931A),
              strokeWidth: 2.w,
            ),
            SizedBox(height: 16.h),
            Text(
              'Loading deposits...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 48.sp,
            ),
            SizedBox(height: 16.h),
            Text(
              'Failed to load deposits',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _error!,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            TextButton.icon(
              onPressed: _loadDeposits,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_deposits == null || _deposits!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.accentGreen,
              size: 64.sp,
            ),
            SizedBox(height: 16.h),
            Text(
              'No Pending Deposits',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'All your on-chain deposits have been claimed',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDeposits,
      color: const Color(0xFFF7931A),
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: _deposits!.length,
        itemBuilder: (context, index) {
          final deposit = _deposits![index];
          return _buildDepositCard(deposit);
        },
      ),
    );
  }

  Widget _buildDepositCard(DepositInfo deposit) {
    String statusText = 'Pending claim';
    Color statusColor = Colors.orange;

    if (deposit.claimError != null) {
      if (deposit.claimError case DepositClaimError_MaxDepositClaimFeeExceeded _) {
        statusText = 'Fee too high - manual claim needed';
        statusColor = Colors.orange;
      } else if (deposit.claimError case DepositClaimError_MissingUtxo _) {
        statusText = 'UTXO not found';
        statusColor = Colors.red;
      } else if (deposit.claimError case DepositClaimError_Generic _) {
        statusText = 'Claim failed';
        statusColor = Colors.red;
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFF7931A).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7931A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.currency_bitcoin_rounded,
                  color: const Color(0xFFF7931A),
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${deposit.amountSats} sats',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Text(
                  'TX: ',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${deposit.txid.substring(0, 8)}...${deposit.txid.substring(deposit.txid.length - 8)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: deposit.txid));
                    _showSnack('Transaction ID copied');
                  },
                  child: Icon(
                    Icons.copy_rounded,
                    color: AppColors.textSecondary,
                    size: 16.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _refundDeposit(deposit),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    'Refund',
                    style: TextStyle(fontSize: 13.sp),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _claimDeposit(deposit),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF7931A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    'Claim',
                    style: TextStyle(fontSize: 13.sp),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
