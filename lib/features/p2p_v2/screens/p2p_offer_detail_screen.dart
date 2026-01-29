import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/nostr/nostr_service.dart';
import '../providers/p2p_provider.dart';
import 'p2p_trade_screen.dart';

/// P2P v2 Offer Detail Screen
/// 
/// Shows full offer details and allows:
/// - Viewing offer information
/// - Initiating a trade (for buyers)
/// - Managing offer (for sellers - their own offers)
class P2PV2OfferDetailScreen extends ConsumerStatefulWidget {
  final String offerId;
  final bool isMyOffer;

  const P2PV2OfferDetailScreen({
    super.key,
    required this.offerId,
    this.isMyOffer = false,
  });

  @override
  ConsumerState<P2PV2OfferDetailScreen> createState() => _P2PV2OfferDetailScreenState();
}

class _P2PV2OfferDetailScreenState extends ConsumerState<P2PV2OfferDetailScreen> {
  final _amountController = TextEditingController();
  String? _selectedPaymentMethod;
  bool _isInitiatingTrade = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offer = ref.watch(p2pOfferProvider(widget.offerId));
    
    if (offer == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            'Offer not found',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16.sp),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, offer),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seller info card
                    _buildSellerCard(offer),
                    
                    SizedBox(height: 20.h),
                    
                    // Price and limits
                    _buildPriceSection(offer),
                    
                    SizedBox(height: 20.h),
                    
                    // Payment methods
                    _buildPaymentMethodsSection(offer),
                    
                    SizedBox(height: 20.h),
                    
                    // Terms/Description
                    if (offer.description.isNotEmpty)
                      _buildTermsSection(offer),
                    
                    SizedBox(height: 20.h),
                    
                    // Trade input (for buyers viewing seller's offer)
                    if (!widget.isMyOffer && offer.type == P2POfferType.sell)
                      _buildTradeInput(offer),
                  ],
                ),
              ),
            ),
            
            // Bottom action button
            if (!widget.isMyOffer && offer.type == P2POfferType.sell)
              _buildBottomButton(offer),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, NostrP2POffer offer) {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(Icons.arrow_back, color: Colors.white, size: 20.sp),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isMyOffer ? 'My Offer' : 'Offer Details',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  offer.title,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildTypeBadge(offer),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(NostrP2POffer offer) {
    final isBuy = offer.type == P2POfferType.buy;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isBuy
            ? AppColors.accentGreen.withOpacity(0.2)
            : AppColors.accentRed.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        isBuy ? 'BUY' : 'SELL',
        style: TextStyle(
          color: isBuy ? AppColors.accentGreen : AppColors.accentRed,
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSellerCard(NostrP2POffer offer) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56.w,
            height: 56.h,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: offer.sellerAvatar != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: offer.sellerAvatar!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _buildAvatarFallback(offer),
                    ),
                  )
                : _buildAvatarFallback(offer),
          ),
          SizedBox(width: 16.w),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.sellerName ?? 'Anonymous',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(Icons.star, color: AppColors.accentYellow, size: 14.sp),
                    SizedBox(width: 4.w),
                    Text(
                      '${offer.sellerCompletionRate.toStringAsFixed(0)}% completion',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  '${offer.sellerTradeCount} trades completed',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          
          // Online indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8.w,
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4.w),
                Text(
                  'Online',
                  style: TextStyle(
                    color: AppColors.accentGreen,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(NostrP2POffer offer) {
    final initial = (offer.sellerName ?? 'A')[0].toUpperCase();
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 24.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPriceSection(NostrP2POffer offer) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            offer.formattedPrice,
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16.h),
          Divider(color: AppColors.borderColor, height: 1),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('Min Amount', _formatSats(offer.minAmountSats)),
              ),
              Container(
                width: 1,
                height: 40.h,
                color: AppColors.borderColor,
              ),
              Expanded(
                child: _buildInfoItem('Max Amount', _formatSats(offer.maxAmountSats)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11.sp,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsSection(NostrP2POffer offer) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Methods',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: offer.paymentMethods.map((method) {
              final isSelected = _selectedPaymentMethod == method;
              return GestureDetector(
                onTap: widget.isMyOffer ? null : () => setState(() => _selectedPaymentMethod = method),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.2)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getPaymentIcon(method),
                        size: 16.sp,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        method,
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          fontSize: 13.sp,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          
          // Payment details (if available)
          if (offer.paymentAccountDetails != null && 
              _selectedPaymentMethod != null &&
              offer.paymentAccountDetails!.containsKey(_selectedPaymentMethod)) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textTertiary, size: 16.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      offer.paymentAccountDetails![_selectedPaymentMethod]!,
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
        ],
      ),
    );
  }

  Widget _buildTermsSection(NostrP2POffer offer) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terms & Instructions',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            offer.description,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeInput(NostrP2POffer offer) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Amount (sats)',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: Colors.white, fontSize: 18.sp),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
              suffixText: 'sats',
              suffixStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
            ),
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: 8.h),
          
          // Quick amount buttons
          Row(
            children: [
              _buildQuickAmountButton(offer.minAmountSats ?? 10000, 'Min'),
              SizedBox(width: 8.w),
              _buildQuickAmountButton(
                ((offer.minAmountSats ?? 10000) + (offer.maxAmountSats ?? 100000)) ~/ 2,
                'Mid',
              ),
              SizedBox(width: 8.w),
              _buildQuickAmountButton(offer.maxAmountSats ?? 100000, 'Max'),
            ],
          ),
          
          // Fiat equivalent
          if (_amountController.text.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Text(
              '≈ ${_calculateFiatAmount(offer)} ${offer.currency}',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAmountButton(int amount, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _amountController.text = amount.toString();
          setState(() {});
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Text(
            '$label\n${_formatSats(amount)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.sp,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton(NostrP2POffer offer) {
    final amount = int.tryParse(_amountController.text) ?? 0;
    final isValid = amount >= (offer.minAmountSats ?? 0) &&
        amount <= (offer.maxAmountSats ?? double.maxFinite) &&
        _selectedPaymentMethod != null;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderColor, width: 1),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52.h,
          child: ElevatedButton(
            onPressed: isValid && !_isInitiatingTrade ? () => _initiateTrade(offer) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: _isInitiatingTrade
                ? SizedBox(
                    width: 24.w,
                    height: 24.h,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Buy ${_formatSats(amount)} sats',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String method) {
    final lower = method.toLowerCase();
    if (lower.contains('bank') || lower.contains('gtbank') || lower.contains('transfer')) {
      return Icons.account_balance;
    }
    if (lower.contains('opay') || lower.contains('palmpay') || lower.contains('moniepoint')) {
      return Icons.phone_android;
    }
    if (lower.contains('mobile') || lower.contains('money')) {
      return Icons.smartphone;
    }
    if (lower.contains('cash')) {
      return Icons.money;
    }
    return Icons.payment;
  }

  String _formatSats(int? sats) {
    if (sats == null) return '-';
    if (sats >= 1000000) return '${(sats / 1000000).toStringAsFixed(1)}M';
    if (sats >= 1000) return '${(sats / 1000).toStringAsFixed(0)}k';
    return sats.toString();
  }

  String _calculateFiatAmount(NostrP2POffer offer) {
    final sats = int.tryParse(_amountController.text) ?? 0;
    final btc = sats / 100000000;
    final fiat = btc * offer.pricePerBtc;
    
    if (fiat >= 1000000) {
      return '${(fiat / 1000000).toStringAsFixed(2)}M';
    }
    if (fiat >= 1000) {
      return '${(fiat / 1000).toStringAsFixed(0)}k';
    }
    return fiat.toStringAsFixed(0);
  }

  Future<void> _initiateTrade(NostrP2POffer offer) async {
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a payment method'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    setState(() => _isInitiatingTrade = true);

    try {
      final notifier = ref.read(p2pV2Provider.notifier);
      final trade = await notifier.initiateTrade(
        offerId: offer.id,
        amountSats: int.parse(_amountController.text),
        paymentMethod: _selectedPaymentMethod!,
      );

      if (trade != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => P2PV2TradeScreen(tradeId: trade.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initiate trade: $e'),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInitiatingTrade = false);
      }
    }
  }
}
