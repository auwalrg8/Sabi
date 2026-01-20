import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_home_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_escrow_info_screen.dart';
import 'package:sabi_wallet/features/p2p/providers/nip99_p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/presentation/widgets/p2p_shared_widgets.dart';
import 'package:sabi_wallet/features/cash/presentation/screens/cash_screen.dart';
import 'package:sabi_wallet/features/cash/presentation/providers/cash_provider.dart';
import 'package:sabi_wallet/features/wallet/presentation/providers/rate_provider.dart';

class TradeScreen extends ConsumerStatefulWidget {
  const TradeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends ConsumerState<TradeScreen> {
  bool _isP2P = true;

  void _toggle(bool p2p) {
    setState(() => _isP2P = p2p);
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

              // Full-width P2P / Market toggle under Live Rates
              SizedBox(
                width: double.infinity,
                child: _RampMarketToggle(isRamp: _isP2P, onChanged: _toggle),
              ),
              SizedBox(height: 16.h),

              // P2P or Market content
              if (_isP2P) ...[
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
              ] else ...[
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
                        MaterialPageRoute(builder: (_) => const P2PHomeScreen()),
                      );
                    },
                    child: Text(
                      'Browse Offers',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),

                // Canonical NIP-99 Marketplace banner (shared)
                const Nip99StatusBanner(),
                SizedBox(height: 12.h),
                // Open Marketplace action removed per design
                SizedBox(height: 12.h),

                // Buy Bitcoin info (using shared ExplainerCard)
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
                  child: ExplainerCard(
                    icon: Icons.shopping_cart,
                    iconColor: const Color(0xFF00C853),
                    title: 'Buy Bitcoin',
                    description:
                        'Fast peer-to-peer purchases with transparent rates and escrow support.',
                  ),
                ),
                SizedBox(height: 12.h),

                
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
}

/// Simple P2P / Market toggle styled with orange active accent.
class _RampMarketToggle extends StatelessWidget {
  final bool isRamp;
  final ValueChanged<bool> onChanged;

  const _RampMarketToggle({required this.isRamp, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: isRamp ? const Color(0xFFF7931A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Center(
                  child: Text(
                    'Ramp',
                    style: TextStyle(
                      color: isRamp ? Colors.white : Colors.white70,
                      fontWeight: isRamp ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: !isRamp ? const Color(0xFFF7931A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Center(
                  child: Text(
                    'P2P',
                    style: TextStyle(
                      color: !isRamp ? Colors.white : Colors.white70,
                      fontWeight: !isRamp ? FontWeight.w700 : FontWeight.w500,
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
