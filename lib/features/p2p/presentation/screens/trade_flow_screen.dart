import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/data/trade_model.dart';
import 'package:sabi_wallet/features/p2p/utils/format_utils.dart';
import 'package:sabi_wallet/features/p2p/providers/trade_providers.dart';

class TradeFlowScreen extends ConsumerStatefulWidget {
  final P2POfferModel offer;
  final double payAmount; // fiat amount user pays

  const TradeFlowScreen({
    super.key,
    required this.offer,
    this.payAmount = 10000,
  });

  @override
  ConsumerState<TradeFlowScreen> createState() => _TradeFlowScreenState();
}

class _TradeFlowScreenState extends ConsumerState<TradeFlowScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUploadProof() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (file == null) return;
    final provider = ref.read(tradeProvider(widget.offer.id).notifier);
    provider.addProof(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final trade = ref.watch(tradeProvider(widget.offer.id));
    final notifier = ref.read(tradeProvider(widget.offer.id).notifier);
    final btcAmount = fiatToBtc(widget.payAmount, widget.offer.pricePerBtc);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        title: Text('Trade with ${widget.offer.name}'),
      ),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    widget.offer.name[0],
                    style: TextStyle(color: AppColors.surface),
                  ),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.offer.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${widget.offer.ratingPercent}% • ${widget.offer.trades} trades',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16.h),

            Text('You pay', style: TextStyle(color: AppColors.textSecondary)),
            SizedBox(height: 6.h),
            Text(
              formatCurrency(widget.payAmount),
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'You receive',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 6.h),
            Text(
              formatBtc(btcAmount),
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),

            SizedBox(height: 16.h),
            Card(
              color: AppColors.surface,
              child: Padding(
                padding: EdgeInsets.all(12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Instructions',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '1. Transfer ${formatCurrency(widget.payAmount)} to ${widget.offer.paymentMethod} account provided by the seller.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '2. After transfer, upload proof below and tap Confirm Payment.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16.h),
            Text(
              'Chat / Proofs',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.all(12.h),
                child:
                    trade.proofs.isEmpty
                        ? Center(
                          child: Text(
                            'No proofs uploaded yet. Use the upload button.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                        : SingleChildScrollView(
                          child: Column(
                            children:
                                trade.proofs.map((p) {
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 8.h),
                                    child: Image.file(
                                      File(p),
                                      fit: BoxFit.contain,
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
              ),
            ),

            SizedBox(height: 12.h),
            Row(
              children: [
                Column(
                  children: [
                    IconButton(
                      onPressed: _pickAndUploadProof,
                      icon: const Icon(Icons.upload_file),
                      color: Colors.white,
                    ),
                    Text(
                      'upload',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ],
                ),

                SizedBox(width: 6.w),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          trade.status == TradeStatus.paid
                              ? Colors.grey
                              : AppColors.primary,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    onPressed:
                        trade.status == TradeStatus.paid
                            ? null
                            : () {
                              if (trade.proofs.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please upload proof before confirming payment',
                                    ),
                                  ),
                                );
                                return;
                              }
                              // confirm payment sets status to paid (already happens on addProof)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Payment confirmed — waiting for seller to release.',
                                  ),
                                ),
                              );
                            },
                    child: Text(
                      style: TextStyle(color: AppColors.surface),
                      trade.status == TradeStatus.paid
                          ? 'Payment Confirmed'
                          : 'Confirm Payment',
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          trade.status == TradeStatus.released
                              ? Colors.grey
                              : AppColors.primary,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    onPressed:
                        trade.status != TradeStatus.paid
                            ? null
                            : () {
                              // simulate release (in real flow seller triggers release)
                              notifier.release();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Funds released — trade complete.',
                                  ),
                                ),
                              );
                            },
                    child: Text(
                      style: TextStyle(color: AppColors.surface),
                      trade.status == TradeStatus.released
                          ? 'Released'
                          : 'Release (simulate)',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
