import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/rate_service.dart';
// P2P shared widgets
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_escrow_info_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/widgets/p2p_shared_widgets.dart';
import 'package:sabi_wallet/features/cash/presentation/screens/cash_screen.dart';
import 'package:sabi_wallet/features/cash/presentation/providers/cash_provider.dart';
import 'package:sabi_wallet/features/wallet/presentation/providers/rate_provider.dart';
// Hodl Hodl P2P Beta integration
import 'package:sabi_wallet/features/trade/presentation/screens/hodl_hodl_marketplace_screen.dart';

/// Trade mode enum for 3-way toggle
enum TradeMode { ramp, p2pBeta, decentralized }

class TradeScreen extends ConsumerStatefulWidget {
  const TradeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends ConsumerState<TradeScreen> {
  TradeMode _tradeMode = TradeMode.ramp;

  void _setMode(TradeMode mode) {
    if (mode == TradeMode.decentralized) {
      // Show coming soon feedback
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('NIP-99 Decentralized Marketplace coming soon!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _tradeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trade',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Buy, spend, trade bitcoin',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const P2PEscrowInfoScreen(),
                      ),
                    ),
                    child: Container(
                      width: 40.w,
                      height: 40.h,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(Icons.help_outline, color: Colors.white, size: 20.sp),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              // Live rates card
              const _TradeLiveRatesCard(),
              SizedBox(height: 16.h),

              // Full-width 3-way toggle: Ramp / P2P Beta / Decentralized
              SizedBox(
                width: double.infinity,
                child: _TradeToggle(mode: _tradeMode, onChanged: _setMode),
              ),
              SizedBox(height: 16.h),

              // Content based on selected mode
              if (_tradeMode == TradeMode.ramp) ...[
                SizedBox(height: 8.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF7931A),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: () {
                      // Navigate to Cash screen with Buy tab active
                      // Set provider state before navigating
                      ref.read(cashProvider.notifier).toggleBuySell(true);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CashScreen()),
                      );
                    },
                    child: Text(
                      'Buy Bitcoin',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white12),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: () {
                      // Navigate to Cash screen with Spend tab active
                      ref.read(cashProvider.notifier).toggleBuySell(false);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CashScreen()),
                      );
                    },
                    child: Text(
                      'Spend Bitcoin',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Instant buy/sell with fixed rates',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                ),
              ] else if (_tradeMode == TradeMode.p2pBeta) ...[
                // P2P Beta (Hodl Hodl) content
                _buildP2PBetaContent(),
              ] else ...[
                // Decentralized (NIP-99) - Coming Soon content
                _buildDecentralizedContent(),
              ],

              // Fill remaining space
              SizedBox(height: 12.h),
              Expanded(child: Container()),
            ],
          ),
        ),
      ),
    );
  }

  /// P2P Beta (Hodl Hodl) content
  Widget _buildP2PBetaContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Beta badge banner
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.science, color: AppColors.primary, size: 16.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'P2P Beta powered by Hodl Hodl escrow',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // Browse Marketplace button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HodlHodlMarketplaceScreen()),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.store, color: Colors.white, size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  'Browse P2P Marketplace',
                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12.h),

        // Feature cards
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.security,
                title: 'Escrow Protected',
                color: const Color(0xFF00C853),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.people,
                title: 'Peer-to-Peer',
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),

        // Info text
        Text(
          'Trade directly with other users using non-custodial escrow. No KYC required.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
        ),
      ],
    );
  }

  /// Decentralized (NIP-99) coming soon content  
  Widget _buildDecentralizedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Coming soon banner
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Icon(Icons.construction, color: Colors.white38, size: 48.sp),
              SizedBox(height: 12.h),
              Text(
                'NIP-99 Decentralized Marketplace',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Fully decentralized P2P trading on Nostr coming soon!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        
        // NIP-99 Banner
        const Nip99StatusBanner(),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: color, size: 16.sp),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 3-way trade mode toggle: Ramp / P2P Beta / Decentralized
class _TradeToggle extends StatelessWidget {
  final TradeMode mode;
  final ValueChanged<TradeMode> onChanged;

  const _TradeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Row(
        children: [
          _buildTab(TradeMode.ramp, 'Ramp'),
          SizedBox(width: 4.w),
          _buildTab(TradeMode.p2pBeta, 'P2P Beta'),
          SizedBox(width: 4.w),
          _buildTab(TradeMode.decentralized, 'Nostr', comingSoon: true),
        ],
      ),
    );
  }

  Widget _buildTab(TradeMode tabMode, String label, {bool comingSoon = false}) {
    final isActive = mode == tabMode;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(tabMode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFF7931A) : Colors.transparent,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: comingSoon 
                      ? Colors.white38
                      : isActive ? Colors.white : Colors.white70,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13.sp,
                ),
              ),
              if (comingSoon)
                Text(
                  'Soon',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 9.sp,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TradeLiveRatesCard extends ConsumerStatefulWidget {
  const _TradeLiveRatesCard();

  @override
  ConsumerState<_TradeLiveRatesCard> createState() => _TradeLiveRatesCardState();
}





class _TradeLiveRatesCardState extends ConsumerState<_TradeLiveRatesCard> {
  double? _btcNgnRate;
  double? _btcUsdRate;
  double? _usdNgnRate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    setState(() => _isLoading = true);
    try {
      final btcNgn = await RateService.getBtcToNgnRate();
      final btcUsd = await RateService.getBtcToUsdRate();
      final usdNgn = await RateService.getUsdToNgnRate();
      if (mounted) {
        setState(() {
          _btcNgnRate = btcNgn;
          _btcUsdRate = btcUsd;
          _usdNgnRate = usdNgn;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCurrency = ref.watch(selectedFiatCurrencyProvider);
    final showBtcUsd = selectedCurrency == FiatCurrency.usd;

    final btcRate = showBtcUsd ? (_btcUsdRate ?? 0) : (_btcNgnRate ?? 0);
    final usdRate = _usdNgnRate ?? 0;

    return GestureDetector(
      onTap: _loadRates,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF1A1A3E), const Color(0xFF111128)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white12),
        ),
        child: _isLoading
            ? Center(
                child: SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFF7931A),
                  ),
                ),
              )
            : Row(
                 children: [
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Row(
                           children: [
                             Container(
                               padding: EdgeInsets.all(6.w),
                               decoration: BoxDecoration(
                                 color: const Color(
                                   0xFFF7931A,
                                 ).withOpacity(0.2),
                                 borderRadius: BorderRadius.circular(6.r),
                               ),
                               child: Icon(
                                 Icons.currency_bitcoin,
                                 color: const Color(0xFFF7931A),
                                 size: 14.sp,
                               ),
                             ),
                             SizedBox(width: 8.w),
                             Text(
                               showBtcUsd ? 'BTC/USD' : 'BTC/NGN',
                               style: TextStyle(
                                 fontSize: 12.sp,
                                 color: Colors.white54,
                               ),
                             ),
                             SizedBox(width: 4.w),
                             Icon(
                               Icons.refresh,
                               color: Colors.white24,
                               size: 12.sp,
                             ),
                           ],
                         ),
                         SizedBox(height: 8.h),
                         Text(
                           showBtcUsd
                               ? '\$${_formatNumber(btcRate)}'
                               : '₦${_formatNumber(btcRate)}',
                           style: TextStyle(
                             fontSize: 16.sp,
                             fontWeight: FontWeight.bold,
                             color: Colors.white,
                           ),
                         ),
                       ],
                     ),
                   ),
                   Container(width: 1, height: 50.h, color: Colors.white12),
                   Expanded(
                     child: Padding(
                       padding: EdgeInsets.only(left: 16.w),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Row(
                             children: [
                               Container(
                                 padding: EdgeInsets.all(6.w),
                                 decoration: BoxDecoration(
                                   color: const Color(0xFF00C853).withOpacity(0.2),
                                   borderRadius: BorderRadius.circular(6.r),
                                 ),
                                 child: Icon(
                                   Icons.attach_money,
                                   color: const Color(0xFF00C853),
                                   size: 14.sp,
                                 ),
                               ),
                               SizedBox(width: 8.w),
                               Text(
                                 'USD/NGN',
                                 style: TextStyle(
                                   fontSize: 12.sp,
                                   color: Colors.white54,
                                 ),
                               ),
                             ],
                           ),
                           SizedBox(height: 8.h),
                           Text(
                             '₦${_formatNumber(usdRate)}',
                             style: TextStyle(
                               fontSize: 16.sp,
                               fontWeight: FontWeight.bold,
                               color: Colors.white,
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

   String _formatNumber(double number) {
     return number
         .toStringAsFixed(0)
         .replaceAllMapped(
           RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
           (Match m) => '${m[1]},',
         );
   }
 }
