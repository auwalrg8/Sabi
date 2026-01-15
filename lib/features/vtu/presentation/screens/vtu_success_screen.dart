import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import '../../data/models/models.dart';
import 'vtu_order_history_screen.dart';

class VtuSuccessScreen extends StatefulWidget {
  final VtuOrder order;

  const VtuSuccessScreen({super.key, required this.order});

  @override
  State<VtuSuccessScreen> createState() => _VtuSuccessScreenState();
}

class _VtuSuccessScreenState extends State<VtuSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (widget.order.serviceType) {
      case VtuServiceType.airtime:
        final network = NetworkProvider.values.firstWhere(
          (n) => n.code == widget.order.networkCode,
          orElse: () => NetworkProvider.mtn,
        );
        return Color(network.primaryColor);
      case VtuServiceType.data:
        final network = NetworkProvider.values.firstWhere(
          (n) => n.code == widget.order.networkCode,
          orElse: () => NetworkProvider.mtn,
        );
        return Color(network.primaryColor);
      case VtuServiceType.electricity:
        return const Color(0xFF1E88E5);
      case VtuServiceType.cableTv:
        if (widget.order.cableTvProvider != null) {
          final provider = CableTvProvider.values.firstWhere(
            (p) => p.code == widget.order.cableTvProvider,
            orElse: () => CableTvProvider.dstv,
          );
          return Color(provider.primaryColor);
        }
        return const Color(0xFF0033A1);
    }
  }

  IconData get _serviceIcon {
    switch (widget.order.serviceType) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  children: [
                    SizedBox(height: 40.h),

                    // Success Animation
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: Container(
                              width: 120.w,
                              height: 120.h,
                              decoration: BoxDecoration(
                                color: _accentColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _accentColor,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                Icons.check,
                                color: _accentColor,
                                size: 60.sp,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 24.h),

                    AnimatedBuilder(
                      animation: _fadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeAnimation.value,
                          child: Column(
                            children: [
                              Text(
                                'Order Successful!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Your ${widget.order.serviceType.name} has been processed successfully',
                                style: TextStyle(
                                  color: const Color(0xFFA1A1B2),
                                  fontSize: 14.sp,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 32.h),

                    // Order Details Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.w),
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
                                  color: _accentColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Icon(
                                  _serviceIcon,
                                  color: _accentColor,
                                  size: 24.sp,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.order.serviceName,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      widget.order.recipient,
                                      style: TextStyle(
                                        color: const Color(0xFFA1A1B2),
                                        fontSize: 13.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(
                                    widget.order.status.color,
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  widget.order.status.name,
                                  style: TextStyle(
                                    color: Color(widget.order.status.color),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20.h),
                          Divider(color: const Color(0xFF2A2A3E)),
                          SizedBox(height: 16.h),

                          _DetailRow(
                            label: 'Order ID',
                            value:
                                widget.order.id.substring(0, 8).toUpperCase(),
                          ),
                          SizedBox(height: 12.h),
                          _DetailRow(
                            label: 'Amount',
                            value: RateService.formatNaira(
                              widget.order.amountNaira,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          _DetailRow(
                            label: 'Payment',
                            value: '${widget.order.amountSats} sats',
                            valueColor: const Color(0xFFF7931A),
                          ),
                          SizedBox(height: 12.h),
                          _DetailRow(
                            label: 'Date',
                            value: _formatDate(widget.order.createdAt),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Success Notice
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: const Color(0xFF10B981),
                            size: 18.sp,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              'Payment completed. Your order has been delivered.',
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
                ),
              ),
            ),

            // Bottom Button
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: const Color(0xFF111128),
                border: Border(
                  top: BorderSide(color: const Color(0xFF2A2A3E), width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: () {
                          // Pop back to home
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Done',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VtuOrderHistoryScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'View Order History',
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
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
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:${date.minute.toString().padLeft(2, '0')} $ampm';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 13.sp),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
