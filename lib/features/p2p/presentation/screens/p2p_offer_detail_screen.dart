import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/providers/p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_trade_chat_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_merchant_profile_screen.dart';

/// P2P Offer Detail Screen - Binance/NoOnes inspired
class P2POfferDetailScreen extends ConsumerStatefulWidget {
  final P2POfferModel offer;

  const P2POfferDetailScreen({super.key, required this.offer});

  @override
  ConsumerState<P2POfferDetailScreen> createState() =>
      _P2POfferDetailScreenState();
}

class _P2POfferDetailScreenState extends ConsumerState<P2POfferDetailScreen> {
  final TextEditingController _amountController = TextEditingController();
  final formatter = NumberFormat('#,###');
  double _amount = 0;
  int _selectedPaymentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Set default to min limit
    _amount = widget.offer.minLimit.toDouble();
    _amountController.text = formatter.format(widget.offer.minLimit);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _receiveBtc => _amount / widget.offer.pricePerBtc;
  double get _receiveSats => _receiveBtc * 100000000;

  bool get _isValidAmount {
    return _amount >= widget.offer.minLimit && _amount <= widget.offer.maxLimit;
  }

  void _onAmountChanged(String value) {
    final cleanValue = value.replaceAll(',', '').replaceAll('₦', '');
    final parsed = double.tryParse(cleanValue) ?? 0;
    setState(() => _amount = parsed);
  }

  void _setPresetAmount(double amount) {
    setState(() {
      _amount = amount;
      _amountController.text = formatter.format(amount.toInt());
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch exchange rates for real-time updates
    ref.watch(exchangeRatesProvider);
    final userOffers = ref.watch(userOffersProvider);
    final isOwner = userOffers.any((o) => o.id == widget.offer.id);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C1A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20.sp,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Buy BTC',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions:
            isOwner
                ? [
                  PopupMenuButton<String>(
                    color: const Color(0xFF0C0C1A),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _showEditDialog(context);
                      } else if (value == 'cancel') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (_) => AlertDialog(
                                backgroundColor: const Color(0xFF0C0C1A),
                                title: const Text('Cancel Offer'),
                                content: const Text(
                                  'Are you sure you want to cancel this offer?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text('No'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, true),
                                    child: const Text('Yes'),
                                  ),
                                ],
                              ),
                        );
                        if (confirm == true) {
                          await ref
                              .read(userOffersProvider.notifier)
                              .removeOffer(widget.offer.id);
                          if (mounted) Navigator.pop(context);
                        }
                      }
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit Offer'),
                          ),
                          const PopupMenuItem(
                            value: 'cancel',
                            child: Text('Cancel Offer'),
                          ),
                        ],
                  ),
                ]
                : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Merchant Card
                  _MerchantInfoCard(
                    offer: widget.offer,
                    onProfileTap: () {
                      if (widget.offer.merchant != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => P2PMerchantProfileScreen(
                                  merchant: widget.offer.merchant!,
                                ),
                          ),
                        );
                      }
                    },
                  ),
                  SizedBox(height: 20.h),

                  // Price Info
                  _PriceInfoRow(
                    label: 'Price',
                    value:
                        '₦${formatter.format(widget.offer.pricePerBtc.toInt())}',
                    valueColor: const Color(0xFF00FFB2),
                  ),
                  SizedBox(height: 12.h),
                  _PriceInfoRow(
                    label: 'Available',
                    value:
                        '${(widget.offer.availableSats ?? 0).toStringAsFixed(0)} sats',
                  ),
                  SizedBox(height: 12.h),
                  _PriceInfoRow(
                    label: 'Limits',
                    value:
                        '₦${formatter.format(widget.offer.minLimit)} - ₦${formatter.format(widget.offer.maxLimit)}',
                  ),
                  SizedBox(height: 24.h),

                  // Amount Input
                  Text(
                    'I want to pay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111128),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color:
                            _isValidAmount
                                ? const Color(0xFF00FFB2).withOpacity(0.3)
                                : const Color(0xFFFF6B6B).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '₦',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '0',
                              hintStyle: TextStyle(color: Color(0xFF6B6B80)),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: _onAmountChanged,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            'NGN',
                            style: TextStyle(
                              color: const Color(0xFFA1A1B2),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Quick amount buttons
                  Row(
                    children: [
                      _QuickAmountButton(
                        label: 'Min',
                        onTap:
                            () => _setPresetAmount(
                              widget.offer.minLimit.toDouble(),
                            ),
                      ),
                      SizedBox(width: 8.w),
                      _QuickAmountButton(
                        label: '₦100K',
                        onTap: () => _setPresetAmount(100000),
                      ),
                      SizedBox(width: 8.w),
                      _QuickAmountButton(
                        label: '₦500K',
                        onTap: () => _setPresetAmount(500000),
                      ),
                      SizedBox(width: 8.w),
                      _QuickAmountButton(
                        label: 'Max',
                        onTap:
                            () => _setPresetAmount(
                              widget.offer.maxLimit.toDouble(),
                            ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  // You receive
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FFB2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: const Color(0xFF00FFB2).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You will receive',
                              style: TextStyle(
                                color: const Color(0xFFA1A1B2),
                                fontSize: 12.sp,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '${formatter.format(_receiveSats.toInt())} sats',
                              style: TextStyle(
                                color: const Color(0xFF00FFB2),
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7931A).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            Icons.currency_bitcoin,
                            color: const Color(0xFFF7931A),
                            size: 24.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Payment Method Selection
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildPaymentMethods(),
                  SizedBox(height: 24.h),

                  // Payment Instructions
                  if (widget.offer.paymentInstructions != null) ...[
                    Text(
                      'Payment Instructions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111128),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: const Color(0xFFA1A1B2),
                            size: 20.sp,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              widget.offer.paymentInstructions!,
                              style: TextStyle(
                                color: const Color(0xFFA1A1B2),
                                fontSize: 13.sp,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                  ],

                  // Trade Terms
                  _buildTradeTerms(),
                ],
              ),
            ),
          ),

          // Bottom CTA
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF111128),
              border: Border(
                top: BorderSide(color: const Color(0xFF2A2A3E), width: 1),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isValidAmount ? () => _startTrade(context) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFB2),
                    disabledBackgroundColor: const Color(0xFF2A2A3E),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    'Buy BTC with ₦${formatter.format(_amount.toInt())}',
                    style: TextStyle(
                      color:
                          _isValidAmount
                              ? const Color(0xFF0C0C1A)
                              : const Color(0xFF6B6B80),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final notifier = ref.read(userOffersProvider.notifier);
    final current = widget.offer;
    final marginController = TextEditingController(
      text: (current.marginPercent ?? 0).toString(),
    );
    final minController = TextEditingController(
      text: current.minLimit.toString(),
    );
    final maxController = TextEditingController(
      text: current.maxLimit.toString(),
    );
    final instrController = TextEditingController(
      text: current.paymentInstructions ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFF0C0C1A),
            title: const Text('Edit Offer'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: marginController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Margin %'),
                  ),
                  TextField(
                    controller: minController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min Limit (₦)',
                    ),
                  ),
                  TextField(
                    controller: maxController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Limit (₦)',
                    ),
                  ),
                  TextField(
                    controller: instrController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Payment Instructions',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final updated = widget.offer.copyWith(
                    marginPercent:
                        double.tryParse(marginController.text) ??
                        widget.offer.marginPercent,
                    minLimit:
                        int.tryParse(minController.text) ??
                        widget.offer.minLimit,
                    maxLimit:
                        int.tryParse(maxController.text) ??
                        widget.offer.maxLimit,
                    paymentInstructions:
                        instrController.text.isEmpty
                            ? null
                            : instrController.text,
                  );
                  await notifier.updateOffer(updated);
                  Navigator.pop(context, true);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Offer updated')));
      setState(() {});
    }
  }

  Widget _buildPaymentMethods() {
    // Build unique list of payment methods (avoid duplicates)
    final methodsSet = <String>{widget.offer.paymentMethod};
    if (widget.offer.acceptedMethods != null) {
      for (final m in widget.offer.acceptedMethods!) {
        methodsSet.add(m.name);
      }
    }
    final methods = methodsSet.toList();

    return Column(
      children:
          methods.asMap().entries.map((entry) {
            final index = entry.key;
            final method = entry.value;
            final isSelected = _selectedPaymentIndex == index;

            return GestureDetector(
              onTap: () => setState(() => _selectedPaymentIndex = index),
              child: Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF111128),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color:
                        isSelected
                            ? const Color(0xFFF7931A)
                            : const Color(0xFF2A2A3E),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20.w,
                      height: 20.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isSelected
                                  ? const Color(0xFFF7931A)
                                  : const Color(0xFFA1A1B2),
                          width: 2,
                        ),
                      ),
                      child:
                          isSelected
                              ? Center(
                                child: Container(
                                  width: 10.w,
                                  height: 10.h,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF7931A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                              : null,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        method,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.account_balance,
                      color: const Color(0xFFA1A1B2),
                      size: 20.sp,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildTradeTerms() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trade Terms',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12.h),
          _TermRow(
            icon: Icons.timer,
            label: 'Payment Window',
            value: '30 minutes',
          ),
          SizedBox(height: 8.h),
          _TermRow(
            icon: Icons.security,
            label: 'Escrow',
            value: 'Protected',
            valueColor: const Color(0xFF00FFB2),
          ),
          if (widget.offer.requiresKyc == true) ...[
            SizedBox(height: 8.h),
            _TermRow(
              icon: Icons.verified_user,
              label: 'KYC Required',
              value: 'Yes',
              valueColor: const Color(0xFFF7931A),
            ),
          ],
        ],
      ),
    );
  }

  void _startTrade(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => P2PTradeChatScreen(
              offer: widget.offer,
              tradeAmount: _amount,
              receiveSats: _receiveSats,
            ),
      ),
    );
  }
}

/// Merchant Info Card
class _MerchantInfoCard extends StatelessWidget {
  final P2POfferModel offer;
  final VoidCallback onProfileTap;

  const _MerchantInfoCard({required this.offer, required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onProfileTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            Container(
              width: 56.w,
              height: 56.h,
              decoration: BoxDecoration(
                color: _getAvatarColor(offer.name),
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child:
                  offer.merchant?.avatarUrl != null
                      ? CachedNetworkImage(
                        imageUrl: offer.merchant!.avatarUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildInitial(),
                      )
                      : _buildInitial(),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        offer.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (offer.merchant?.isVerified == true) ...[
                        SizedBox(width: 6.w),
                        Icon(
                          Icons.verified,
                          color: const Color(0xFF00FFB2),
                          size: 18.sp,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: const Color(0xFFF7931A),
                        size: 14.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${offer.ratingPercent}%',
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 13.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        '${offer.trades} trades',
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 13.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Container(
                        width: 6.w,
                        height: 6.h,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00FFB2),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Online',
                        style: TextStyle(
                          color: const Color(0xFF00FFB2),
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: const Color(0xFFA1A1B2),
              size: 24.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitial() {
    return Center(
      child: Text(
        offer.name.isNotEmpty ? offer.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFFF7931A),
      const Color(0xFF00FFB2),
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
    ];
    return colors[name.hashCode % colors.length];
  }
}

/// Price Info Row
class _PriceInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _PriceInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Quick Amount Button
class _QuickAmountButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAmountButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: const Color(0xFF2A2A3E)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFFA1A1B2),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Term Row
class _TermRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _TermRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFA1A1B2), size: 18.sp),
        SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 13.sp),
        ),
        const Spacer(),
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
