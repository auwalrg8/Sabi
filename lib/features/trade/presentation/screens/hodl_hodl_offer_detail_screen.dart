import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/hodl_hodl/hodl_hodl.dart';

import 'hodl_hodl_trade_chat_screen.dart';

/// P2P Offer Detail Screen
/// Shows full offer information and allows user to accept the trade
class HodlHodlOfferDetailScreen extends ConsumerStatefulWidget {
  final HodlHodlOffer offer;

  const HodlHodlOfferDetailScreen({
    Key? key,
    required this.offer,
  }) : super(key: key);

  @override
  ConsumerState<HodlHodlOfferDetailScreen> createState() => _HodlHodlOfferDetailScreenState();
}

class _HodlHodlOfferDetailScreenState extends ConsumerState<HodlHodlOfferDetailScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  bool _isAccepting = false;
  String? _selectedPaymentMethodId;
  String? _selectedPaymentMethodVersion;
  
  // For selling BTC - user's own payment instructions
  List<Map<String, dynamic>>? _userPaymentInstructions;
  bool _isLoadingUserPaymentMethods = false;
  String? _userPaymentError;

  // Whether user is selling BTC (accepting a buy offer)
  bool get _isSellingBtc => widget.offer.side == 'buy';

  @override
  void initState() {
    super.initState();
    // Pre-select first payment method if available (for buying BTC)
    if (!_isSellingBtc && widget.offer.paymentMethodInstructions.isNotEmpty) {
      _selectedPaymentMethodId = widget.offer.paymentMethodInstructions.first.id;
      _selectedPaymentMethodVersion = widget.offer.paymentMethodInstructions.first.version;
    }
    // Set default amount to minimum
    _amountController.text = widget.offer.minAmount;
    
    // If selling BTC, load user's payment instructions
    if (_isSellingBtc) {
      _loadUserPaymentInstructions();
    }
  }
  
  Future<void> _loadUserPaymentInstructions() async {
    setState(() {
      _isLoadingUserPaymentMethods = true;
      _userPaymentError = null;
    });
    
    try {
      final service = ref.read(hodlHodlServiceProvider);
      final instructions = await service.getMyPaymentInstructions();
      
      if (mounted) {
        setState(() {
          _userPaymentInstructions = instructions;
          _isLoadingUserPaymentMethods = false;
          // Pre-select first instruction if available
          if (instructions.isNotEmpty) {
            _selectedPaymentMethodId = instructions.first['id']?.toString();
            _selectedPaymentMethodVersion = instructions.first['version']?.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUserPaymentMethods = false;
          _userPaymentError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBuyingBtc = widget.offer.side == 'sell';
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isBuyingBtc ? 'Buy Bitcoin' : 'Sell Bitcoin',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trader card
                    _buildTraderCard(),
                    SizedBox(height: 16.h),
                    
                    // Price info
                    _buildPriceCard(),
                    SizedBox(height: 16.h),
                    
                    // Trade limits
                    _buildLimitsCard(),
                    SizedBox(height: 16.h),
                    
                    // Payment method
                    _buildPaymentMethodCard(),
                    SizedBox(height: 16.h),
                    
                    // Terms & description
                    if (widget.offer.description != null && widget.offer.description!.isNotEmpty)
                      _buildDescriptionCard(),
                    SizedBox(height: 16.h),
                    
                    // Amount input
                    _buildAmountInput(),
                    SizedBox(height: 16.h),
                    
                    // Comment input
                    _buildCommentInput(),
                    SizedBox(height: 24.h),
                    
                    // Escrow info
                    _buildEscrowInfo(),
                  ],
                ),
              ),
            ),
            
            // Accept button
            _buildAcceptButton(isBuyingBtc),
          ],
        ),
      ),
    );
  }

  Widget _buildTraderCard() {
    final trader = widget.offer.trader;
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56.w,
            height: 56.h,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Center(
              child: Text(
                trader.login.isNotEmpty ? trader.login[0].toUpperCase() : '?',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      trader.login,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (trader.verified) ...[
                      SizedBox(width: 6.w),
                      Icon(Icons.verified, color: AppColors.accentGreen, size: 18.sp),
                    ],
                    if (trader.strongHodler) ...[
                      SizedBox(width: 4.w),
                      Icon(Icons.star, color: AppColors.accentYellow, size: 16.sp),
                    ],
                  ],
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    _buildStatChip(Icons.swap_horiz, '${trader.tradesCount} trades'),
                    SizedBox(width: 12.w),
                    if (trader.rating != null)
                      _buildStatChip(Icons.thumb_up, '${(trader.rating! * 100).toStringAsFixed(0)}%'),
                  ],
                ),
              ],
            ),
          ),
          // Online indicator
          Column(
            children: [
              Container(
                width: 12.w,
                height: 12.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: trader.onlineStatus == 'online'
                      ? AppColors.accentGreen
                      : trader.onlineStatus == 'recently_online'
                          ? AppColors.accentYellow
                          : Colors.grey,
                  boxShadow: [
                    BoxShadow(
                      color: (trader.onlineStatus == 'online'
                              ? AppColors.accentGreen
                              : trader.onlineStatus == 'recently_online'
                                  ? AppColors.accentYellow
                                  : Colors.grey)
                          .withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                trader.onlineStatus == 'online'
                    ? 'Online'
                    : trader.onlineStatus == 'recently_online'
                        ? 'Recent'
                        : 'Offline',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white54, size: 14.sp),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.15),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price per Bitcoin',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_getCurrencySymbol(widget.offer.currencyCode)}${_formatNumber(double.tryParse(widget.offer.price) ?? 0)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 8.w),
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Text(
                  widget.offer.currencyCode,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.white54, size: 14.sp),
              SizedBox(width: 6.w),
              Text(
                '${widget.offer.paymentWindowMinutes} min payment window',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Icon(Icons.confirmation_number, color: Colors.white54, size: 14.sp),
              SizedBox(width: 6.w),
              Text(
                '${widget.offer.confirmations} confirmations',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLimitsCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Minimum',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${_getCurrencySymbol(widget.offer.currencyCode)}${_formatNumber(double.tryParse(widget.offer.minAmount) ?? 0)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40.h,
            color: Colors.white12,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Maximum',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${_getCurrencySymbol(widget.offer.currencyCode)}${_formatNumber(double.tryParse(widget.offer.maxAmount) ?? 0)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    // When selling BTC, show user's own payment instructions
    if (_isSellingBtc) {
      return _buildUserPaymentMethodCard();
    }
    
    // When buying BTC, show seller's payment instructions
    final methods = widget.offer.paymentMethodInstructions;
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pay to (Seller\\'s Payment Method)',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 12.h),
          if (methods.isEmpty)
            Text(
              'No payment methods specified',
              style: TextStyle(color: Colors.white70, fontSize: 14.sp),
            )
          else
            ...methods.map((method) => _buildPaymentMethodItem(method)).toList(),
        ],
      ),
    );
  }\n\n  Widget _buildUserPaymentMethodCard() {\n    return Container(\n      padding: EdgeInsets.all(16.w),\n      decoration: BoxDecoration(\n        color: AppColors.surface,\n        borderRadius: BorderRadius.circular(20.r),\n      ),\n      child: Column(\n        crossAxisAlignment: CrossAxisAlignment.start,\n        children: [\n          Row(\n            children: [\n              Expanded(\n                child: Text(\n                  'Receive payment to (Your Payment Method)',\n                  style: TextStyle(\n                    color: Colors.white54,\n                    fontSize: 12.sp,\n                  ),\n                ),\n              ),\n              if (_userPaymentError != null)\n                GestureDetector(\n                  onTap: _loadUserPaymentInstructions,\n                  child: Icon(Icons.refresh, color: AppColors.primary, size: 20.sp),\n                ),\n            ],\n          ),\n          SizedBox(height: 12.h),\n          if (_isLoadingUserPaymentMethods)\n            Center(\n              child: SizedBox(\n                width: 24.w,\n                height: 24.h,\n                child: CircularProgressIndicator(\n                  color: AppColors.primary,\n                  strokeWidth: 2,\n                ),\n              ),\n            )\n          else if (_userPaymentError != null)\n            Column(\n              children: [\n                Text(\n                  'Failed to load payment methods',\n                  style: TextStyle(color: AppColors.accentRed, fontSize: 13.sp),\n                ),\n                SizedBox(height: 8.h),\n                TextButton(\n                  onPressed: _loadUserPaymentInstructions,\n                  child: Text('Retry', style: TextStyle(color: AppColors.primary)),\n                ),\n              ],\n            )\n          else if (_userPaymentInstructions == null || _userPaymentInstructions!.isEmpty)\n            Column(\n              children: [\n                Text(\n                  'You need to add a payment method first',\n                  style: TextStyle(color: Colors.white70, fontSize: 14.sp),\n                ),\n                SizedBox(height: 12.h),\n                TextButton.icon(\n                  onPressed: () {\n                    Navigator.pushNamed(context, '/create-payment-method').then((_) {\n                      _loadUserPaymentInstructions();\n                    });\n                  },\n                  icon: Icon(Icons.add, color: AppColors.primary),\n                  label: Text('Add Payment Method', style: TextStyle(color: AppColors.primary)),\n                ),\n              ],\n            )\n          else\n            ..._userPaymentInstructions!.map((instruction) => _buildUserPaymentItem(instruction)).toList(),\n        ],\n      ),\n    );\n  }\n\n  Widget _buildUserPaymentItem(Map<String, dynamic> instruction) {\n    final id = instruction['id']?.toString() ?? '';\n    final version = instruction['version']?.toString() ?? '';\n    final name = instruction['name']?.toString() ?? 'Unknown';\n    final paymentMethodName = instruction['payment_method']?['name']?.toString() ?? \n                              instruction['payment_method_name']?.toString() ?? '';\n    final isSelected = _selectedPaymentMethodId == id;\n    \n    return GestureDetector(\n      onTap: () {\n        setState(() {\n          _selectedPaymentMethodId = id;\n          _selectedPaymentMethodVersion = version;\n        });\n      },\n      child: Container(\n        margin: EdgeInsets.only(bottom: 8.h),\n        padding: EdgeInsets.all(12.w),\n        decoration: BoxDecoration(\n          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.03),\n          borderRadius: BorderRadius.circular(12.r),\n          border: Border.all(\n            color: isSelected ? AppColors.primary : Colors.white12,\n          ),\n        ),\n        child: Row(\n          children: [\n            Icon(\n              Icons.payment,\n              color: isSelected ? AppColors.primary : Colors.white54,\n              size: 20.sp,\n            ),\n            SizedBox(width: 12.w),\n            Expanded(\n              child: Column(\n                crossAxisAlignment: CrossAxisAlignment.start,\n                children: [\n                  Text(\n                    name,\n                    style: TextStyle(\n                      color: Colors.white,\n                      fontSize: 14.sp,\n                      fontWeight: FontWeight.w500,\n                    ),\n                  ),\n                  if (paymentMethodName.isNotEmpty)\n                    Text(\n                      paymentMethodName,\n                      style: TextStyle(\n                        color: Colors.white54,\n                        fontSize: 11.sp,\n                      ),\n                    ),\n                ],\n              ),\n            ),\n            if (isSelected)\n              Icon(Icons.check_circle, color: AppColors.primary, size: 20.sp),\n          ],\n        ),\n      ),\n    );\n  }

  Widget _buildPaymentMethodItem(HodlHodlPaymentMethodInstruction method) {
    final isSelected = _selectedPaymentMethodId == method.id;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethodId = method.id;
          _selectedPaymentMethodVersion = method.version;
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.payment,
              color: isSelected ? AppColors.primary : Colors.white54,
              size: 20.sp,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.paymentMethodName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (method.paymentMethodType.isNotEmpty)
                    Text(
                      method.paymentMethodType,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11.sp,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primary, size: 20.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white54, size: 16.sp),
              SizedBox(width: 8.w),
              Text(
                'Terms & Description',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            widget.offer.description ?? '',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14.sp,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount (${widget.offer.currencyCode})',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              prefixText: '${_getCurrencySymbol(widget.offer.currencyCode)} ',
              prefixStyle: TextStyle(
                color: Colors.white54,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
              hintText: 'Enter amount',
              hintStyle: TextStyle(
                color: Colors.white24,
                fontSize: 18.sp,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 14.h,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              _buildQuickAmountButton('Min', widget.offer.minAmount),
              SizedBox(width: 8.w),
              _buildQuickAmountButton('Max', widget.offer.maxAmount),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountButton(String label, String amount) {
    return GestureDetector(
      onTap: () {
        _amountController.text = amount;
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Message to trader (optional)',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _commentController,
            maxLines: 2,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
            ),
            decoration: InputDecoration(
              hintText: 'Introduce yourself...',
              hintStyle: TextStyle(
                color: Colors.white24,
                fontSize: 14.sp,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 12.h,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscrowInfo() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.accentGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: AppColors.accentGreen, size: 24.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Non-Custodial Escrow',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Funds are locked in a 2-of-3 multisig. Neither party nor Hodl Hodl can steal your BTC.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptButton(bool isBuyingBtc) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56.h,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isBuyingBtc ? AppColors.accentGreen : AppColors.accentRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              elevation: 0,
            ),
            onPressed: _isAccepting ? null : _acceptOffer,
            child: _isAccepting
                ? SizedBox(
                    width: 24.w,
                    height: 24.h,
                    child: CircularProgressIndicator(
                      color: isBuyingBtc ? Colors.black : Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    isBuyingBtc ? 'Accept & Buy BTC' : 'Accept & Sell BTC',
                    style: TextStyle(
                      color: isBuyingBtc ? Colors.black : Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _acceptOffer() async {
    // Validate
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null) {
      _showError('Invalid amount');
      return;
    }

    final minAmount = double.tryParse(widget.offer.minAmount) ?? 0;
    final maxAmount = double.tryParse(widget.offer.maxAmount) ?? double.infinity;
    
    if (amount < minAmount || amount > maxAmount) {
      _showError('Amount must be between ${widget.offer.minAmount} and ${widget.offer.maxAmount}');
      return;
    }

    if (_selectedPaymentMethodId == null) {
      _showError('Please select a payment method');
      return;
    }

    // Check API configuration
    final isConfigured = await ref.read(hodlHodlServiceProvider).isConfigured();
    if (!isConfigured) {
      _showError('Please configure your Hodl Hodl API key first');
      return;
    }

    setState(() => _isAccepting = true);
    HapticFeedback.mediumImpact();

    try {
      final contract = await ref.read(hodlHodlContractNotifierProvider.notifier).acceptOffer(
        offer: widget.offer,
        paymentMethodInstructionId: _selectedPaymentMethodId!,
        paymentMethodInstructionVersion: _selectedPaymentMethodVersion ?? '',
        fiatAmount: amount,
        comment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
      );

      if (contract != null && mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HodlHodlTradeChatScreen(contract: contract),
          ),
        );
      } else {
        _showError('Failed to create contract. Please try again.');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }

  String _getCurrencySymbol(String code) {
    switch (code) {
      case 'NGN':
        return '₦';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return code;
    }
  }

  String _formatNumber(double number) {
    return number
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
