import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/data/merchant_model.dart';
import 'package:sabi_wallet/services/nostr/nip99_marketplace_service.dart';
import 'package:sabi_wallet/services/nostr/models/nostr_offer.dart';

/// A rich preview card widget for P2P offers referenced via NIP-18 (nostr:naddr)
/// Used in DMs, feed posts, and trade chats to display offer details inline
class P2POfferPreviewWidget extends StatefulWidget {
  /// The nostr:naddr URI reference string (e.g., "nostr:naddr1qqqq...")
  final String? naddrReference;

  /// Alternatively, provide a pre-loaded offer model
  final P2POfferModel? offer;

  /// Callback when user taps on the preview card
  final VoidCallback? onTap;

  /// Whether to show a compact version
  final bool compact;

  const P2POfferPreviewWidget({
    super.key,
    this.naddrReference,
    this.offer,
    this.onTap,
    this.compact = false,
  }) : assert(naddrReference != null || offer != null);

  @override
  State<P2POfferPreviewWidget> createState() => _P2POfferPreviewWidgetState();
}

class _P2POfferPreviewWidgetState extends State<P2POfferPreviewWidget> {
  P2POfferModel? _offer;
  bool _isLoading = true;
  bool _hasError = false;

  final _formatter = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    if (widget.offer != null) {
      _offer = widget.offer;
      _isLoading = false;
    } else if (widget.naddrReference != null) {
      _loadOfferFromNaddr();
    }
  }

  Future<void> _loadOfferFromNaddr() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final offerId = _extractOfferIdFromNaddr(widget.naddrReference!);
      if (offerId == null) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        return;
      }

      // Try to get from cache first
      final marketplace = NIP99MarketplaceService();
      final cachedOffer = marketplace.getCachedOffer(offerId);

      if (cachedOffer != null) {
        setState(() {
          _offer = _convertCachedOfferToModel(cachedOffer);
          _isLoading = false;
        });
      } else {
        // Offer not in cache - fetch all offers and find matching one
        final offers = await marketplace.fetchOffers(limit: 100);
        final matchingOffer = offers.where((o) => o.id == offerId).firstOrNull;

        if (matchingOffer != null) {
          await marketplace.enrichOffersWithProfiles([matchingOffer]);
          setState(() {
            _offer = _convertCachedOfferToModel(matchingOffer);
            _isLoading = false;
          });
        } else {
          // Still not found - show error state
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading offer from naddr: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  /// Extract offer ID from nostr:naddr reference
  String? _extractOfferIdFromNaddr(String naddr) {
    // Basic extraction - the naddr contains the full reference
    if (naddr.startsWith('nostr:naddr1')) {
      // The naddr contains kind, pubkey, identifier, and relay hints
      // For now return the full naddr as ID for cache lookup
      return naddr.replaceFirst('nostr:', '');
    }
    return null;
  }

  P2POfferModel? _convertCachedOfferToModel(NostrP2POffer offer) {
    return P2POfferModel(
      id: offer.id,
      name: offer.sellerName ?? 'Anonymous',
      pricePerBtc: offer.pricePerBtc,
      paymentMethod:
          offer.paymentMethods.isNotEmpty
              ? offer.paymentMethods.first
              : 'Unknown',
      eta: '< 15 min',
      ratingPercent: 100,
      trades: 0,
      minLimit: offer.minAmountSats ?? 0,
      maxLimit: offer.maxAmountSats ?? 0,
      type: offer.type == P2POfferType.buy ? OfferType.buy : OfferType.sell,
      merchant: MerchantModel(
        id: offer.pubkey,
        name: offer.sellerName ?? 'Anonymous',
        trades30d: 0,
        completionRate: 100.0,
        avgReleaseMinutes: 15,
        totalVolume: 0.0,
        joinedDate: offer.createdAt,
        avatarUrl: offer.sellerAvatar,
        isVerified: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_hasError || _offer == null) {
      return _buildErrorState();
    }

    return widget.compact ? _buildCompactPreview() : _buildFullPreview();
  }

  Widget _buildLoadingState() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20.w,
            height: 20.h,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: const Color(0xFFF7931A),
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            'Loading P2P offer...',
            style: TextStyle(color: Colors.grey[400], fontSize: 13.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Offer not available',
              style: TextStyle(color: Colors.grey[400], fontSize: 13.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPreview() {
    final offer = _offer!;
    final isBuy = offer.type == OfferType.buy;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.h),
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color:
                isBuy
                    ? Colors.green.withOpacity(0.3)
                    : Colors.orange.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // Offer type icon
            Container(
              padding: EdgeInsets.all(6.r),
              decoration: BoxDecoration(
                color: (isBuy ? Colors.green : Colors.orange).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Icon(
                Icons.currency_bitcoin,
                color: isBuy ? Colors.green : Colors.orange,
                size: 14.sp,
              ),
            ),
            SizedBox(width: 10.w),
            // Offer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isBuy ? "Buy" : "Sell"} Bitcoin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₦${_formatter.format(_safeToInt(offer.pricePerBtc))}/BTC',
                    style: TextStyle(
                      color: const Color(0xFF00FFB2),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 12.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildFullPreview() {
    final offer = _offer!;
    final isBuy = offer.type == OfferType.buy;
    final typeColor = isBuy ? Colors.green : Colors.orange;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1A2E),
              const Color(0xFF1A1A2E).withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: typeColor.withOpacity(0.4), width: 1),
          boxShadow: [
            BoxShadow(
              color: typeColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14.r),
                  topRight: Radius.circular(14.r),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.currency_bitcoin,
                      color: typeColor,
                      size: 16.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    '${isBuy ? "Buy" : "Sell"} Bitcoin Offer',
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'P2P',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(14.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Merchant info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18.r,
                        backgroundColor: const Color(0xFF2A2A3E),
                        backgroundImage:
                            offer.merchant?.avatarUrl != null
                                ? CachedNetworkImageProvider(
                                  offer.merchant!.avatarUrl!,
                                )
                                : null,
                        child:
                            offer.merchant?.avatarUrl == null
                                ? Text(
                                  (offer.merchant?.name ?? 'A')[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                                : null,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offer.merchant?.name ?? offer.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 12.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '${offer.ratingPercent}%',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 11.sp,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Icon(
                                  Icons.swap_horiz,
                                  color: Colors.grey[500],
                                  size: 12.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '${offer.trades} trades',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  // Price and details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11.sp,
                            ),
                          ),
                          Text(
                            '₦${_formatter.format(_safeToInt(offer.pricePerBtc))}',
                            style: TextStyle(
                              color: const Color(0xFF00FFB2),
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'per BTC',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 10.sp,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Limits',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11.sp,
                            ),
                          ),
                          Text(
                            '₦${_formatShort(offer.minLimit)} - ₦${_formatShort(offer.maxLimit)}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  // Payment method
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A3E),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance,
                          color: Colors.grey[400],
                          size: 14.sp,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          offer.paymentMethod,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // View offer button
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [typeColor, typeColor.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Center(
                        child: Text(
                          'View Offer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatShort(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return _formatter.format(value);
  }
}

/// Utility function to check if a message contains a P2P offer reference
bool containsP2POfferReference(String message) {
  return message.contains('nostr:naddr1');
}

/// Utility function to extract naddr references from a message
List<String> extractNaddrReferences(String message) {
  final regex = RegExp(r'nostr:naddr1[a-z0-9]+');
  return regex.allMatches(message).map((m) => m.group(0)!).toList();
}

/// Safely converts double to int, handling Infinity and NaN
int _safeToInt(double value, [int defaultValue = 0]) {
  if (value.isNaN || value.isInfinite) return defaultValue;
  return value.toInt();
}
