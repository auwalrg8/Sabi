import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import '../../data/models/models.dart';
import '../providers/vtu_providers.dart';
import '../widgets/refund_dialog.dart';

class VtuOrderHistoryScreen extends ConsumerStatefulWidget {
  const VtuOrderHistoryScreen({super.key});

  @override
  ConsumerState<VtuOrderHistoryScreen> createState() =>
      _VtuOrderHistoryScreenState();
}

class _VtuOrderHistoryScreenState extends ConsumerState<VtuOrderHistoryScreen> {
  VtuServiceType? _filterType;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(vtuOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'VTU Orders',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.read(vtuOrdersProvider.notifier).refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Tabs
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: _filterType == null,
                      onTap: () => setState(() => _filterType = null),
                    ),
                    SizedBox(width: 8.w),
                    _FilterChip(
                      label: 'Airtime',
                      isSelected: _filterType == VtuServiceType.airtime,
                      onTap:
                          () => setState(
                            () => _filterType = VtuServiceType.airtime,
                          ),
                      color: const Color(0xFF00C853),
                    ),
                    SizedBox(width: 8.w),
                    _FilterChip(
                      label: 'Data',
                      isSelected: _filterType == VtuServiceType.data,
                      onTap:
                          () =>
                              setState(() => _filterType = VtuServiceType.data),
                      color: const Color(0xFF2196F3),
                    ),
                    SizedBox(width: 8.w),
                    _FilterChip(
                      label: 'Electricity',
                      isSelected: _filterType == VtuServiceType.electricity,
                      onTap:
                          () => setState(
                            () => _filterType = VtuServiceType.electricity,
                          ),
                      color: const Color(0xFFFF9800),
                    ),
                  ],
                ),
              ),
            ),

            // Orders List
            Expanded(
              child: ordersAsync.when(
                loading:
                    () => const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF7931A),
                      ),
                    ),
                error:
                    (error, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: const Color(0xFFFF4D4F),
                            size: 48.sp,
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'Failed to load orders',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          TextButton(
                            onPressed:
                                () =>
                                    ref
                                        .read(vtuOrdersProvider.notifier)
                                        .refresh(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                data: (orders) {
                  final filteredOrders =
                      _filterType != null
                          ? orders
                              .where((o) => o.serviceType == _filterType)
                              .toList()
                          : orders;

                  if (filteredOrders.isEmpty) {
                    return _EmptyState(filterType: _filterType);
                  }

                  return RefreshIndicator(
                    onRefresh:
                        () => ref.read(vtuOrdersProvider.notifier).refresh(),
                    color: const Color(0xFFF7931A),
                    child: ListView.separated(
                      padding: EdgeInsets.all(16.w),
                      itemCount: filteredOrders.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12.h),
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        return _OrderCard(order: order);
                      },
                    ),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? const Color(0xFFF7931A);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? chipColor.withOpacity(0.15)
                  : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? chipColor : const Color(0xFF2A2A3E),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? chipColor : const Color(0xFFA1A1B2),
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VtuServiceType? filterType;

  const _EmptyState({this.filterType});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: const Color(0xFF6B7280),
              size: 40.sp,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            filterType != null
                ? 'No ${filterType!.name} orders yet'
                : 'No orders yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your VTU orders will appear here',
            style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final VtuOrder order;

  const _OrderCard({required this.order});

  Color get _serviceColor {
    switch (order.serviceType) {
      case VtuServiceType.airtime:
        if (order.networkCode != null) {
          final network = NetworkProvider.values.firstWhere(
            (n) => n.code == order.networkCode,
            orElse: () => NetworkProvider.mtn,
          );
          return Color(network.primaryColor);
        }
        return const Color(0xFF00C853);
      case VtuServiceType.data:
        if (order.networkCode != null) {
          final network = NetworkProvider.values.firstWhere(
            (n) => n.code == order.networkCode,
            orElse: () => NetworkProvider.mtn,
          );
          return Color(network.primaryColor);
        }
        return const Color(0xFF2196F3);
      case VtuServiceType.electricity:
        return const Color(0xFF1E88E5);
      case VtuServiceType.cableTv:
        if (order.cableTvProvider != null) {
          final provider = CableTvProvider.values.firstWhere(
            (p) => p.code == order.cableTvProvider,
            orElse: () => CableTvProvider.dstv,
          );
          return Color(provider.primaryColor);
        }
        return const Color(0xFF0033A1);
    }
  }

  IconData get _serviceIcon {
    switch (order.serviceType) {
      case VtuServiceType.airtime:
        return Icons.phone_android;
      case VtuServiceType.data:
        return Icons.wifi;
      case VtuServiceType.electricity:
        return Icons.bolt;
      case VtuServiceType.cableTv:
        return Icons.tv;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.h,
                decoration: BoxDecoration(
                  color: _serviceColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(_serviceIcon, color: _serviceColor, size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.serviceName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      order.recipient,
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Color(order.status.color).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  order.status.name,
                  style: TextStyle(
                    color: Color(order.status.color),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Divider(color: const Color(0xFF2A2A3E), height: 1),
          SizedBox(height: 14.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount',
                    style: TextStyle(
                      color: const Color(0xFF6B7280),
                      fontSize: 11.sp,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    RateService.formatNaira(order.amountNaira),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Payment',
                    style: TextStyle(
                      color: const Color(0xFF6B7280),
                      fontSize: 11.sp,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Icon(
                        Icons.flash_on,
                        color: const Color(0xFFF7931A),
                        size: 14.sp,
                      ),
                      Text(
                        '${order.amountSats} sats',
                        style: TextStyle(
                          color: const Color(0xFFF7931A),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Date',
                    style: TextStyle(
                      color: const Color(0xFF6B7280),
                      fontSize: 11.sp,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _formatDate(order.createdAt),
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (order.status == VtuOrderStatus.pending ||
              order.status == VtuOrderStatus.processing) ...[
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF7931A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: const Color(0xFFF7931A),
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      order.status == VtuOrderStatus.pending
                          ? 'Awaiting payment confirmation'
                          : 'Being processed by agent',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (order.token != null) ...[
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: const Color(0xFF00C853),
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Token',
                          style: TextStyle(
                            color: const Color(0xFF6B7280),
                            fontSize: 11.sp,
                          ),
                        ),
                        Text(
                          order.token!,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (order.errorMessage != null) ...[
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D4F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: const Color(0xFFFF4D4F),
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      order.errorMessage!,
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Refund section - show for failed orders
          if (order.canRequestRefund) ...[
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _requestRefund(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7931A).withOpacity(0.15),
                  foregroundColor: const Color(0xFFF7931A),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    side: const BorderSide(color: Color(0xFFF7931A)),
                  ),
                  elevation: 0,
                ),
                icon: Icon(Icons.receipt_long, size: 18.sp),
                label: Text(
                  'Request Refund',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          // Show pending refund status
          if (order.hasRefundPending) ...[
            SizedBox(height: 14.h),
            GestureDetector(
              onTap: () => RefundDialog.show(context, order),
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA726).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: const Color(0xFFFFA726).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      color: const Color(0xFFFFA726),
                      size: 18.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Refund Requested',
                            style: TextStyle(
                              color: const Color(0xFFFFA726),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Tap to view refund invoice',
                            style: TextStyle(
                              color: const Color(0xFFA1A1B2),
                              fontSize: 11.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: const Color(0xFF6B7280),
                      size: 14.sp,
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Show completed refund status
          if (order.refundStatus == RefundStatus.completed) ...[
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: const Color(0xFF66BB6A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: const Color(0xFF66BB6A),
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Refund completed - ${order.amountSats} sats credited',
                      style: TextStyle(
                        color: const Color(0xFF66BB6A),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _requestRefund(BuildContext context, WidgetRef ref) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF111128),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Text(
              'Request Refund?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will generate a Lightning invoice for ${order.amountSats} sats.',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Share the invoice with the agent to receive your refund.',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: const Color(0xFF6B7280),
                    fontSize: 14.sp,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7931A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'Request Refund',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFF7931A)),
          ),
    );

    try {
      final updatedOrder = await ref
          .read(vtuOrdersProvider.notifier)
          .requestRefund(order.id);

      Navigator.pop(context); // Close loading

      if (updatedOrder != null && context.mounted) {
        // Show refund dialog
        RefundDialog.show(context, updatedOrder);
      }
    } catch (e) {
      Navigator.pop(context); // Close loading

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request refund: $e'),
            backgroundColor: const Color(0xFFFF4D4F),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}';
    }
  }
}
