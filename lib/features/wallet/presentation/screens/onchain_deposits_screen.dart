import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/wallet/presentation/providers/onchain_deposits_provider.dart';

class OnchainDepositsScreen extends ConsumerWidget {
  const OnchainDepositsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deposits = ref.watch(onchainDepositsListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('On‑chain Deposits'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: deposits.isEmpty
            ? Center(
                child: Text(
                  'No incoming on‑chain deposits detected',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : ListView.separated(
                itemCount: deposits.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (context, i) {
                  final d = deposits[i];
                  return Card(
                    color: AppColors.surface,
                    child: Padding(
                      padding: EdgeInsets.all(12.w),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${d.amountSats} sats',
                                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  'tx: ${d.txid.substring(0, d.txid.length > 12 ? 12 : d.txid.length)}... vout:${d.vout}',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  'Confirmations: ${d.confirmations}',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: d.confirmations > 0
                                ? () {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final asyncNotifier = ref.read(onchainDepositsProvider);
                                    asyncNotifier.when(
                                      data: (notifier) {
                                        notifier.claim(d).then((_) {
                                          messenger.showSnackBar(const SnackBar(content: Text('Claim requested')));
                                        }).catchError((e) {
                                          messenger.showSnackBar(SnackBar(content: Text('Claim failed: $e')));
                                        });
                                      },
                                      loading: () {
                                        messenger.showSnackBar(const SnackBar(content: Text('Service not ready')));
                                      },
                                      error: (e, st) {
                                        messenger.showSnackBar(SnackBar(content: Text('Service error: $e')));
                                      },
                                    );
                                  }
                                : null,
                            child: const Text('Claim'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
