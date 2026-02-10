import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/hodl_hodl/hodl_hodl.dart';

import 'create_payment_method_screen.dart';

/// Screen to manage HodlHodl payment instructions
/// Payment methods are stored in HodlHodl's servers, not locally
class HodlHodlPaymentMethodsScreen extends ConsumerStatefulWidget {
  const HodlHodlPaymentMethodsScreen({super.key});

  @override
  ConsumerState<HodlHodlPaymentMethodsScreen> createState() =>
      _HodlHodlPaymentMethodsScreenState();
}

class _HodlHodlPaymentMethodsScreenState
    extends ConsumerState<HodlHodlPaymentMethodsScreen> {
  List<Map<String, dynamic>> _instructions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInstructions();
  }

  Future<void> _loadInstructions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = HodlHodlService();
      final isConfigured = await service.isConfigured();

      if (!isConfigured) {
        setState(() {
          _loading = false;
          _error = 'Not connected to HodlHodl';
        });
        return;
      }

      final instructions = await service.getMyPaymentInstructions();

      if (mounted) {
        setState(() {
          _instructions = instructions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Payment Methods',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary, size: 24.sp),
            onPressed: _loadInstructions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreatePaymentMethodScreen(),
            ),
          ).then((_) => _loadInstructions());
        },
        backgroundColor: AppColors.primary,
        icon: Icon(Icons.add, color: Colors.white, size: 20.sp),
        label: Text(
          'Add New',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.w,
              ),
            )
          : _error != null
              ? _buildErrorState()
              : _instructions.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadInstructions,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16.w),
                        itemCount: _instructions.length,
                        itemBuilder: (context, index) {
                          return _buildInstructionCard(_instructions[index]);
                        },
                      ),
                    ),
    );
  }

  Widget _buildErrorState() {
    final isNotConnected = _error?.contains('Not connected') == true;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNotConnected ? Icons.link_off_rounded : Icons.error_outline,
              color: isNotConnected ? AppColors.primary : AppColors.accentRed,
              size: 64.sp,
            ),
            SizedBox(height: 16.h),
            Text(
              isNotConnected ? 'Not Connected' : 'Error Loading',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              isNotConnected
                  ? 'Connect your HodlHodl account first'
                  : _error ?? 'Unknown error',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            TextButton.icon(
              onPressed: _loadInstructions,
              icon: Icon(Icons.refresh, size: 20.sp),
              label: const Text('Try Again'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_off_outlined,
              color: AppColors.textSecondary,
              size: 64.sp,
            ),
            SizedBox(height: 16.h),
            Text(
              'No Payment Methods',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Add payment methods to your HodlHodl account to receive payments from trades',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreatePaymentMethodScreen(),
                  ),
                ).then((_) => _loadInstructions());
              },
              icon: Icon(Icons.add, size: 20.sp),
              label: const Text('Add Payment Method'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard(Map<String, dynamic> instruction) {
    final id = instruction['id']?.toString() ?? '';
    final name = instruction['name']?.toString() ?? 'Unknown';
    final details = instruction['details']?.toString() ?? '';
    final methodName = instruction['payment_method_name']?.toString() ?? '';
    final methodType = instruction['payment_method_type']?.toString() ?? '';
    final version = instruction['version']?.toString() ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.payment,
                  color: AppColors.primary,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (methodName.isNotEmpty || methodType.isNotEmpty)
                      Text(
                        methodName.isNotEmpty ? methodName : methodType,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                        ),
                      ),
                  ],
                ),
              ),
              // Copy ID button
              IconButton(
                icon: Icon(Icons.copy, color: Colors.white38, size: 18.sp),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: id));
                  _showSnack('Payment method ID copied');
                },
                tooltip: 'Copy ID',
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary,
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      details,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 8.h),
          Row(
            children: [
              Text(
                'ID: ${id.length > 12 ? '${id.substring(0, 12)}...' : id}',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10.sp,
                  fontFamily: 'monospace',
                ),
              ),
              if (version.isNotEmpty) ...[
                Text(
                  ' • v$version',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
