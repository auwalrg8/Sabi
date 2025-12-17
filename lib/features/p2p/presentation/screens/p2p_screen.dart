import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/providers/p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/utils/format_utils.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/trade_flow_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/seller_profile_screen.dart';

class P2PScreen extends ConsumerStatefulWidget {
  const P2PScreen({super.key});

  @override
  ConsumerState<P2PScreen> createState() => _P2PScreenState();
}

// Uses P2POfferModel from data layer

class _P2PScreenState extends ConsumerState<P2PScreen> {
  // offers provided by Riverpod provider

  String _selectedMode = 'Sell BTC';
  String _selectedFilter = 'All Payments';
  String _sortBy = 'Best Price';

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Placeholder: load more offers
      // In real implementation: fetch next page
    }
  }

  void _showSellerModal(P2POfferModel offer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.all(20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SellerProfileScreen(offer: offer))),
                  child: CircleAvatar(radius: 24, backgroundColor: AppColors.primary, child: Text(offer.name[0])),
                ),
                SizedBox(width: 12.w),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SellerProfileScreen(offer: offer))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(offer.name, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.white)),
                    SizedBox(height: 4.h),
                    Text('${offer.ratingPercent}% (${offer.trades} trades)', style: TextStyle(color: AppColors.textSecondary)),
                  ]),
                )
              ],
            ),
            SizedBox(height: 12.h),
            Text('Rate: ${formatCurrency(offer.pricePerBtc)} per 1 BTC', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            SizedBox(height: 8.h),
            Text('Payment: ${offer.paymentMethod} • ${offer.eta}', style: TextStyle(color: AppColors.textSecondary)),
            SizedBox(height: 16.h),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: EdgeInsets.symmetric(vertical: 14.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TradeFlowScreen(offer: offer)));
                  },
                  child: const Text('Trade'),
                ),
              ),
            ])
          ],
        ),
      ),
    );
  }

  // _filteredOffers will be built in build() from provider

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          onRefresh: () async {},
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('P2P', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: Colors.white)),
                    Row(children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.history, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.settings, color: Colors.white),
                      ),
                    ])
                  ],
                ),
                SizedBox(height: 12.h),

                // Mode toggle
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMode = 'Buy BTC'),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        decoration: BoxDecoration(
                          color: _selectedMode == 'Buy BTC' ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(child: Text('Buy BTC', style: TextStyle(color: _selectedMode == 'Buy BTC' ? Colors.white : AppColors.textSecondary))),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMode = 'Sell BTC'),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        decoration: BoxDecoration(
                          color: _selectedMode == 'Sell BTC' ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(child: Text('Sell BTC', style: TextStyle(color: _selectedMode == 'Sell BTC' ? Colors.white : AppColors.textSecondary))),
                      ),
                    ),
                  ),
                ]),

                SizedBox(height: 12.h),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _buildFilterChip('All Payments'),
                    SizedBox(width: 8.w),
                    _buildFilterChip('Bank Transfer'),
                    SizedBox(width: 8.w),
                    _buildFilterChip('Mobile Money'),
                  ]),
                ),

                SizedBox(height: 16.h),

                // Sort and quick info
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Offers', style: TextStyle(color: AppColors.textSecondary)),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: AppColors.surface,
                      value: _sortBy,
                      items: ['Best Price', 'Fastest', 'Highest Rated'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _sortBy = v ?? 'Best Price'),
                    ),
                  )
                ]),

                SizedBox(height: 12.h),

                // Offer list (from provider)
                Consumer(builder: (context, ref, _) {
                  final offers = ref.watch(p2pOffersProvider);
                  // apply minimal sorting
                  final list = List.of(offers);
                  if (_sortBy == 'Best Price') list.sort((a, b) => a.pricePerBtc.compareTo(b.pricePerBtc));
                  if (_sortBy == 'Highest Rated') list.sort((a, b) => b.ratingPercent.compareTo(a.ratingPercent));

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (_, idx) {
                      final offer = list[idx];
                      return P2PCard(
                        offer: offer,
                        onTap: () => _showSellerModal(offer),
                      );
                    },
                    separatorBuilder: (_, __) => SizedBox(height: 12.h),
                    itemCount: list.length,
                  );
                }),
                SizedBox(height: 90.h),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          onPressed: () {
            // create new offer / post ad flow
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create P2P offer')));
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final selected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class P2PCard extends StatelessWidget {
  final P2POfferModel offer;
  final VoidCallback? onTap;

  const P2PCard({super.key, required this.offer, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Row(children: [
                CircleAvatar(radius: 20, backgroundColor: AppColors.primary, child: Text(offer.name[0])),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(offer.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                    SizedBox(height: 4.h),
                    Text('${offer.ratingPercent}% (${offer.trades} trades)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp), overflow: TextOverflow.ellipsis),
                  ]),
                )
              ]),
            ),
            // Rate
            Flexible(child: Text(formatCurrency(offer.pricePerBtc), textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w800))),
          ]),
          SizedBox(height: 12.h),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(formatCurrency(10000), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                SizedBox(height: 4.h),
                Text('Pay', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp)),
              ]),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(formatBtc(fiatToBtc(10000, offer.pricePerBtc)), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                SizedBox(height: 4.h),
                Text('Receive BTC', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp)),
              ]),
            )
          ]),
          SizedBox(height: 12.h),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text('Limits ₦${offer.minLimit.toString()} - ₦${offer.maxLimit.toString()}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp), overflow: TextOverflow.ellipsis)),
            SizedBox(width: 8.w),
            Expanded(child: Text('${offer.paymentMethod} • ${offer.eta}', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp), overflow: TextOverflow.ellipsis)),
          ]),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: EdgeInsets.symmetric(vertical: 12.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: onTap,
              child: const Text('Trade'),
            ),
          )
        ]),
      ),
    );
  }
}
