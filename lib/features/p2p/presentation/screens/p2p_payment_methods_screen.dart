import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/p2p/data/payment_method_model.dart';
import 'package:sabi_wallet/features/p2p/services/payment_method_service.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_add_payment_method_screen.dart';

/// Screen to manage saved payment methods
class P2PPaymentMethodsScreen extends ConsumerStatefulWidget {
  final bool isSelecting;
  final PaymentMethodType? filterType;

  const P2PPaymentMethodsScreen({
    super.key,
    this.isSelecting = false,
    this.filterType,
  });

  @override
  ConsumerState<P2PPaymentMethodsScreen> createState() =>
      _P2PPaymentMethodsScreenState();
}

class _P2PPaymentMethodsScreenState
    extends ConsumerState<P2PPaymentMethodsScreen> {
  List<PaymentMethodModel> _methods = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(paymentMethodServiceProvider);
      var methods = await service.getPaymentMethods();

      if (widget.filterType != null) {
        methods = methods.where((m) => m.type == widget.filterType).toList();
      }

      if (mounted) {
        setState(() {
          _methods = methods;
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

  Future<void> _deleteMethod(PaymentMethodModel method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Delete Payment Method',
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Text(
          'Are you sure you want to delete "${method.name}"?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final service = ref.read(paymentMethodServiceProvider);
        await service.deletePaymentMethod(method.id);
        _showSnack('Payment method deleted');
        _loadMethods();
      } catch (e) {
        _showSnack('Failed to delete: $e', isError: true);
      }
    }
  }

  Future<void> _setDefault(PaymentMethodModel method) async {
    try {
      final service = ref.read(paymentMethodServiceProvider);
      await service.setDefaultPaymentMethod(method.id);
      _showSnack('${method.name} set as default');
      _loadMethods();
    } catch (e) {
      _showSnack('Failed to set default: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isSelecting ? 'Select Payment Method' : 'Payment Methods',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!widget.isSelecting)
            IconButton(
              icon: Icon(Icons.add_rounded, color: AppColors.primary, size: 24.sp),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const P2PAddPaymentMethodScreen(),
                  ),
                );
                if (result == true) {
                  _loadMethods();
                }
              },
            ),
        ],
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
              : _methods.isEmpty
                  ? _buildEmptyState()
                  : _buildMethodsList(),
      floatingActionButton: widget.isSelecting
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const P2PAddPaymentMethodScreen(),
                  ),
                );
                if (result == true) {
                  _loadMethods();
                }
              },
              backgroundColor: AppColors.primary,
              icon: Icon(Icons.add_rounded, size: 24.sp),
              label: Text(
                'Add Method',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 48.sp,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'No Payment Methods',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Add your bank accounts, mobile money, or other payment methods to receive payments from P2P trades.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 32.h),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const P2PAddPaymentMethodScreen(),
                  ),
                );
                if (result == true) {
                  _loadMethods();
                }
              },
              icon: Icon(Icons.add_rounded, size: 20.sp),
              label: Text(
                'Add Payment Method',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48.sp,
              color: Colors.red,
            ),
            SizedBox(height: 16.h),
            Text(
              'Failed to load payment methods',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
              ),
            ),
            SizedBox(height: 24.h),
            TextButton(
              onPressed: _loadMethods,
              child: Text('Retry', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodsList() {
    return RefreshIndicator(
      onRefresh: _loadMethods,
      color: AppColors.primary,
      child: ListView.separated(
        padding: EdgeInsets.all(20.w),
        itemCount: _methods.length,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          final method = _methods[index];
          return _buildMethodCard(method);
        },
      ),
    );
  }

  Widget _buildMethodCard(PaymentMethodModel method) {
    return GestureDetector(
      onTap: () {
        if (widget.isSelecting) {
          HapticFeedback.selectionClick();
          Navigator.pop(context, method);
        }
      },
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: method.isDefault
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: _getTypeColor(method.type).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                method.type.icon,
                style: TextStyle(fontSize: 24.sp),
              ),
            ),
            SizedBox(width: 16.w),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          method.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (method.isDefault)
                        Container(
                          margin: EdgeInsets.only(left: 8.w),
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            'DEFAULT',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    method.type.displayName,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                    ),
                  ),
                  if (method.displayDetails.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      method.displayDetails,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            if (!widget.isSelecting)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textSecondary,
                  size: 20.sp,
                ),
                color: AppColors.surface,
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => P2PAddPaymentMethodScreen(
                            existingMethod: method,
                          ),
                        ),
                      ).then((result) {
                        if (result == true) {
                          _loadMethods();
                        }
                      });
                      break;
                    case 'default':
                      _setDefault(method);
                      break;
                    case 'delete':
                      _deleteMethod(method);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18.sp, color: Colors.white),
                        SizedBox(width: 12.w),
                        Text('Edit', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  if (!method.isDefault)
                    PopupMenuItem(
                      value: 'default',
                      child: Row(
                        children: [
                          Icon(Icons.star_outline_rounded, size: 18.sp, color: AppColors.primary),
                          SizedBox(width: 12.w),
                          Text('Set as Default', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18.sp, color: Colors.red),
                        SizedBox(width: 12.w),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 24.sp,
              ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.bankTransfer:
        return const Color(0xFF2196F3);
      case PaymentMethodType.mobileMoney:
        return const Color(0xFF4CAF50);
      case PaymentMethodType.cash:
        return const Color(0xFFFF9800);
      case PaymentMethodType.giftCard:
        return const Color(0xFFE91E63);
      case PaymentMethodType.wallet:
        return const Color(0xFF9C27B0);
      case PaymentMethodType.other:
        return AppColors.primary;
    }
  }
}
