import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/cash/presentation/screens/cash_screen.dart';
import 'package:sabi_wallet/features/profile/presentation/screens/profile_screen.dart';
import 'package:sabi_wallet/features/zaps/presentation/screens/zaps_screen.dart';
import 'package:sabi_wallet/core/widgets/cards/balance_card.dart';
import 'package:sabi_wallet/core/widgets/skeleton_loader.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'package:sabi_wallet/services/event_stream_service.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/notification_service.dart';
import 'package:sabi_wallet/services/profile_service.dart';
import 'package:sabi_wallet/services/app_state_service.dart';
import 'package:sabi_wallet/core/utils/date_utils.dart' as date_utils;
import 'package:sabi_wallet/l10n/app_localizations.dart';

import '../providers/wallet_info_provider.dart';
import '../providers/balance_provider.dart';
import '../providers/recent_transactions_provider.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
import 'qr_scanner_screen.dart';
import 'transactions_screen.dart';
import 'notifications_screen.dart';
import 'payment_detail_screen.dart';
import 'payment_received_screen.dart';
import 'package:sabi_wallet/features/onboarding/data/models/wallet_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isBalanceVisible = true;
  Timer? _refreshTimer;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      _HomeContent(
        isBalanceVisible: _isBalanceVisible,
        onToggleBalance:
            () => setState(() => _isBalanceVisible = !_isBalanceVisible),
      ),
      const CashScreen(),
      const ZapsScreen(),
      const ProfileScreen(),
    ];
    // Initialize Breez SDK first, then poll payments
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeBreezSDK();
      // Sync and get balance immediately after init
      await BreezSparkService.syncAndGetBalance();
      // Refresh balance provider to get the balance
      await ref.read(balanceNotifierProvider.notifier).refresh();
      // Refresh wallet provider to get the balance
      await ref.read(walletInfoProvider.notifier).refresh();
      // Refresh recent transactions
      await ref.read(recentTransactionsProvider.notifier).refresh();
      // Refresh all transactions
      await ref.read(allTransactionsNotifierProvider.notifier).refresh();
      _pollPaymentsForConfetti();
      _initEventStream();
      _startAutoRefresh();
    });
  }

  void _startAutoRefresh() {
    // Poll balance and transactions every 3 seconds using Breez SDK
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (mounted) {
        try {
          // Fetch fresh balance from Breez SDK
          await BreezSparkService.getBalance();
          // Refresh the balance provider directly
          ref.read(balanceNotifierProvider.notifier).refresh();
          // Also refresh wallet info provider
          ref.read(walletInfoProvider.notifier).refresh();
          // Refresh recent transactions
          ref.read(recentTransactionsProvider.notifier).refresh();
          // Refresh all transactions
          ref.read(allTransactionsNotifierProvider.notifier).refresh();
        } catch (e) {
          debugPrint('⚠️ Auto-refresh error: $e');
        }
      }
    });
  }

  Future<void> _initializeBreezSDK() async {
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final mnemonic = await storage.getWalletSeed();

      if (mnemonic != null && mnemonic.isNotEmpty) {
        await BreezSparkService.initializeSparkSDK(mnemonic: mnemonic);
        debugPrint('✅ Spark SDK initialized successfully');
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize Spark SDK: $e');
    }
  }

  void _initEventStream() {
    final eventService = ref.read(eventStreamServiceProvider);
    eventService.start();

    // Listen to balance updates
    eventService.balanceUpdates.listen((balance) {
      // Refresh both balance and wallet info when balance updates
      ref.read(balanceNotifierProvider.notifier).refresh();
      ref.read(walletInfoProvider.notifier).refresh();
    });

    // Listen to Breez SDK payment stream directly for more reliable detection
    BreezSparkService.paymentStream.listen((payment) async {
      debugPrint(
        '🔔 Payment stream event: ${payment.isIncoming ? "incoming" : "outgoing"} ${payment.amountSats} sats',
      );

      // Refresh transaction providers
      ref.read(recentTransactionsProvider.notifier).refresh();
      ref.read(allTransactionsNotifierProvider.notifier).refresh();

      if (payment.isIncoming) {
        // Trigger confetti for incoming payments
        final storage = ref.read(secureStorageServiceProvider);
        await storage.write(
          key: 'first_payment_confetti_pending',
          value: 'true',
        );

        // Refresh balance to show confetti
        ref.read(balanceNotifierProvider.notifier).refresh();

        // Add to notification service
        NotificationService.addPaymentNotification(
          isInbound: true,
          amountSats: payment.amountSats,
          description: payment.description,
        );

        // Show payment received screen with animation
        if (mounted) {
          debugPrint(
            '🎉 Showing payment received screen: ${payment.amountSats} sats',
          );
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder:
                  (context, animation, secondaryAnimation) =>
                      PaymentReceivedScreen(
                        amountSats: payment.amountSats,
                        description: payment.description,
                      ),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      }

      // Refresh wallet info and balance
      ref.read(balanceNotifierProvider.notifier).refresh();
      ref.read(walletInfoProvider.notifier).refresh();
    });

    // Also listen to payment notifications from event service as backup
    eventService.paymentNotifications.listen((payment) async {
      debugPrint(
        '🔔 Event service notification: ${payment.inbound ? "incoming" : "outgoing"} ${payment.amountSats} sats',
      );

      // Refresh recent transactions when new payment arrives
      ref.read(recentTransactionsProvider.notifier).refresh();
      // Also refresh all transactions
      ref.read(allTransactionsNotifierProvider.notifier).refresh();

      // Show notification or update UI
      if (payment.inbound) {
        // Trigger confetti for incoming payments
        final storage = ref.read(secureStorageServiceProvider);
        await storage.write(
          key: 'first_payment_confetti_pending',
          value: 'true',
        );

        // Refresh balance to show confetti
        ref.read(balanceNotifierProvider.notifier).refresh();

        // Add to notification service
        NotificationService.addPaymentNotification(
          isInbound: payment.inbound,
          amountSats: payment.amountSats,
          description: payment.description,
        );

        // Show payment received screen with animation
        if (mounted) {
          debugPrint(
            '🎉 Showing payment received screen (from event service): ${payment.amountSats} sats',
          );
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder:
                  (context, animation, secondaryAnimation) =>
                      PaymentReceivedScreen(
                        amountSats: payment.amountSats,
                        description: payment.description ?? '',
                      ),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      }
      // Refresh wallet info and balance
      ref.read(balanceNotifierProvider.notifier).refresh();
      ref.read(walletInfoProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Save app state when app goes to background
      AppStateService.saveLastScreen('/home');
    }

    if (state == AppLifecycleState.resumed) {
      // Refresh wallet data when app comes back to foreground
      ref.read(walletInfoProvider.notifier).refresh();
      // Refresh recent transactions
      ref.read(recentTransactionsProvider.notifier).refresh();
      // Refresh all transactions
      ref.read(allTransactionsNotifierProvider.notifier).refresh();
      // Also poll recent payments to mark first-payment confetti if applicable
      _pollPaymentsForConfetti();
    }
  }

  Future<bool> _showExitDialog() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('Exit Sabi Wallet'),
                content: const Text('Do you really want to quit Sabi Wallet?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await AppStateService.saveLastScreen('/home');
                      if (!mounted) return;
                      Navigator.of(dialogContext).pop(true);
                    },
                    child: const Text('Exit'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Only show exit dialog when on home tab
        if (_currentIndex == 0) {
          final shouldExit = await _showExitDialog();
          if (shouldExit && context.mounted) {
            // Exit the app completely (minimize to background)
            // Data is already saved in Hive/SecureStorage
            await Future.delayed(const Duration(milliseconds: 100));
            // Use SystemNavigator to exit without popping
            if (Platform.isAndroid) {
              SystemNavigator.pop();
            } else if (Platform.isIOS) {
              exit(0);
            }
          }
        } else {
          // If not on home tab, go back to home tab
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _currentIndex, children: _screens),
        floatingActionButton:
            _currentIndex == 0
                ? Container(
                  width: 56.w,
                  height: 56.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SendScreen()),
                        ),
                    icon: Icon(Icons.bolt, color: Colors.white, size: 24.sp),
                  ),
                )
                : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: Container(
          height: 65.h,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.surface, width: 1.w),
            ),
          ),
          child: Row(
            children: [
              _BottomNavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                isSelected: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              _BottomNavItem(
                customIcon: _CashNavIcon(isSelected: _currentIndex == 1),
                label: 'Cash',
                isSelected: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              _BottomNavItem(
                icon: Icons.bolt_outlined,
                label: 'Zaps',
                isSelected: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
              ),
              _BottomNavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                isSelected: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pollPaymentsForConfetti() async {
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final confettiShown = await storage.read(
        key: 'first_payment_confetti_shown',
      );

      if (confettiShown == 'true') return;

      // Check payments from Spark SDK
      final response = await BreezSparkService.listPayments(limit: 10);

      // If we have any payments, mark confetti as pending
      if (response.isNotEmpty) {
        await storage.write(
          key: 'first_payment_confetti_pending',
          value: 'true',
        );
      }
    } catch (_) {
      // Ignore errors in confetti detection
    }
  }
}

class _HomeContent extends ConsumerWidget {
  final bool isBalanceVisible;
  final VoidCallback onToggleBalance;

  const _HomeContent({
    required this.isBalanceVisible,
    required this.onToggleBalance,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletInfoProvider);

    Future<void> refreshWithSync() async {
      // First, sync with blockchain to detect Bitcoin receives
      await BreezSparkService.syncAndGetBalance();
      // Then refresh the UI
      await ref.read(walletInfoProvider.notifier).refresh();
    }

    Future<void> openQRScanner(BuildContext context, WidgetRef ref) async {
      try {
        final String? scannedCode = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (context) => const QRScannerScreen()),
        );

        if (scannedCode != null && scannedCode.isNotEmpty && context.mounted) {
          // Navigate to send screen with the scanned code
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SendScreen(initialAddress: scannedCode),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('QR Scanner error: $e'),
              backgroundColor: AppColors.surface,
            ),
          );
        }
      }
    }

    final isWalletLoading = walletAsync.isLoading;

    final mainContent = RefreshIndicator(
      onRefresh: refreshWithSync,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(30.h),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FutureBuilder<UserProfile>(
                    future: ProfileService.getProfile(),
                    builder: (context, snapshot) {
                      final username =
                          snapshot.hasData ? snapshot.data!.username : 'User';
                      return Row(
                        children: [
                          Text(
                            'HI, $username',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w500,
                              height: 28.h / 17.h,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          // Health indicator dot
                          Consumer(
                            builder: (context, ref, _) {
                              final eventService = ref.watch(
                                eventStreamServiceProvider,
                              );
                              final isOnline = eventService.isConnected;
                              return Container(
                                width: 8.w,
                                height: 8.h,
                                decoration: BoxDecoration(
                                  color:
                                      isOnline
                                          ? AppColors.accentGreen
                                          : const Color(0xFFFF8C00),
                                  shape: BoxShape.circle,
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  Row(
                    children: [
                      _HeaderIcon(
                        icon: Icons.qr_code_scanner_outlined,
                        onTap: () => openQRScanner(context, ref),
                      ),
                      SizedBox(width: 30.w),
                      _NotificationIcon(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 30.h),
              // Spark inbound status / first-channel loading banner
              _InboundStatusBanner(walletAsync: walletAsync),
              SizedBox(height: 12.h),
              // Balance card with direct Breez SDK balance
              Consumer(
                builder: (context, ref, _) {
                  final balanceAsync = ref.watch(balanceNotifierProvider);

                  return balanceAsync.when(
                    loading: () => const CircularProgressIndicator.adaptive(),
                    error:
                        (_, __) => BalanceCard(
                          balanceSats: 0,
                          showConfetti: false,
                          isOnline:
                              ref.watch(eventStreamServiceProvider).isConnected,
                          isBalanceHidden: !isBalanceVisible,
                          onToggleHide: onToggleBalance,
                        ),
                    data: (balance) {
                      return FutureBuilder<String?>(
                        future: ref
                            .read(secureStorageServiceProvider)
                            .read(key: 'first_payment_confetti_pending'),
                        builder: (context, confettiSnapshot) {
                          final showConfetti = confettiSnapshot.data == 'true';

                          // Mark confetti as shown if displaying
                          if (showConfetti) {
                            WidgetsBinding.instance.addPostFrameCallback((
                              _,
                            ) async {
                              final storage = ref.read(
                                secureStorageServiceProvider,
                              );
                              await storage.write(
                                key: 'first_payment_confetti_shown',
                                value: 'true',
                              );
                              await storage.write(
                                key: 'first_payment_confetti_pending',
                                value: 'false',
                              );
                            });
                          }

                          return BalanceCard(
                            balanceSats: balance,
                            showConfetti: showConfetti,
                            isOnline:
                                ref
                                    .watch(eventStreamServiceProvider)
                                    .isConnected,
                            isBalanceHidden: !isBalanceVisible,
                            onToggleHide: onToggleBalance,
                          );
                        },
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 17.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ActionButton(
                    icon: _SendIcon(),
                    label: AppLocalizations.of(context)!.send,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SendScreen()),
                        ),
                  ),
                  _ActionButton(
                    icon: _ReceiveIcon(),
                    label: AppLocalizations.of(context)!.receive,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReceiveScreen(),
                          ),
                        ),
                  ),
                  _ActionButton(
                    icon: _AirtimeIcon(),
                    label: AppLocalizations.of(context)!.airtime,
                    onTap: () {},
                  ),
                  _ActionButton(
                    icon: _PayBillsIcon(),
                    label: AppLocalizations.of(context)!.payBills,
                    onTap: () {},
                  ),
                ],
              ),
              SizedBox(height: 30.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.recentTransactions,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      height: 28.h / 15.h,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TransactionsScreen(),
                        ),
                      );
                    },
                    child: Text(
                      AppLocalizations.of(context)!.seeAll,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        height: 20 / 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              // Display real transactions from Breez SDK
              Consumer(
                builder: (context, ref, _) {
                  final paymentsAsync = ref.watch(recentTransactionsProvider);

                  return paymentsAsync.when(
                    loading:
                        () => Column(
                          children: List.generate(
                            3,
                            (index) =>
                                const CircularProgressIndicator.adaptive(),
                          ),
                        ),
                    error:
                        (_, __) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Text(
                              AppLocalizations.of(
                                context,
                              )!.failedToLoadTransactions,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ),
                    data: (payments) {
                      if (payments.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Text(
                              AppLocalizations.of(context)!.noTransactions,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children:
                            payments.take(5).map((payment) {
                              final isInbound = payment.isIncoming;
                              final icon =
                                  isInbound
                                      ? _ReceiveTransactionIcon()
                                      : _SendTransactionIcon();
                              final amountColor =
                                  isInbound
                                      ? AppColors.accentGreen
                                      : const Color(0xFFFF4D4F);
                              final amountPrefix = isInbound ? '+' : '-';

                              final timeStr = date_utils.formatTransactionTime(
                                payment.paymentTime,
                              );

                              final String amountDisplay =
                                  '$amountPrefix${_formatSats(payment.amountSats)} sats';
                              final title =
                                  payment.description.isNotEmpty
                                      ? payment.description
                                      : (isInbound
                                          ? AppLocalizations.of(
                                            context,
                                          )!.receivedPayment
                                          : AppLocalizations.of(
                                            context,
                                          )!.sentPayment);

                              return Padding(
                                padding: EdgeInsets.only(bottom: 12.h),
                                child: _TransactionItem(
                                  icon: icon,
                                  title: title,
                                  time: timeStr,
                                  amount: amountDisplay,
                                  amountColor: amountColor,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => PaymentDetailScreen(
                                              payment: payment,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 100.h),
            ],
          ),
        ),
      ),
    );

    return Stack(
      children: [
        mainContent,
        if (isWalletLoading) const CircularProgressIndicator.adaptive(),
      ],
    );
  }

  String _formatSats(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }
}

// class _HomeSkeletonOverlay extends StatelessWidget {
//   const _HomeSkeletonOverlay();

//   @override
//   Widget build(BuildContext context) {
//     return Positioned.fill(
//       child: IgnorePointer(
//         child: Container(
//           color: AppColors.background.withValues(alpha: 0.85),
//           child: SafeArea(
//             child: SingleChildScrollView(
//               physics: const NeverScrollableScrollPhysics(),
//               padding: EdgeInsets.all(30.h),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Expanded(
//                         child: SkeletonLoader(
//                           height: 20.h,
//                           width: 150.w,
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                       SizedBox(width: 10.w),
//                       SkeletonLoader(
//                         width: 24.w,
//                         height: 24.h,
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       SizedBox(width: 10.w),
//                       SkeletonLoader(
//                         width: 24.w,
//                         height: 24.h,
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 30.h),
//                   SkeletonLoader(
//                     height: 60.h,
//                     width: double.infinity,
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   SizedBox(height: 12.h),
//                   const BalanceCardSkeleton(),
//                   SizedBox(height: 20.h),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: List.generate(
//                       4,
//                       (_) => Column(
//                         children: [
//                           SkeletonLoader(
//                             width: 48.w,
//                             height: 48.h,
//                             borderRadius: BorderRadius.circular(999),
//                           ),
//                           SizedBox(height: 6.h),
//                           SkeletonLoader(
//                             width: 32.w,
//                             height: 12.h,
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                   SizedBox(height: 30.h),
//                   SkeletonLoader(
//                     width: 100.w,
//                     height: 15.h,
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   SizedBox(height: 12.h),
//                   Column(
//                     children: List.generate(
//                       3,
//                       (_) => Padding(
//                         padding: EdgeInsets.only(bottom: 12.h),
//                         child: SkeletonLoader(
//                           height: 80.h,
//                           width: double.infinity,
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                       ),
//                     ),
//                   ),
//                   SizedBox(height: 100.h),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

class _InboundStatusBanner extends StatelessWidget {
  final AsyncValue<WalletModel?> walletAsync;

  const _InboundStatusBanner({required this.walletAsync});

  @override
  Widget build(BuildContext context) {
    return walletAsync.when(
      data: (model) {
        final conn = model?.connectionDetails;
        // Show banner only if we have a wallet and it's not yet fully synced
        if (model == null || conn == null || conn.synced == true) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.accentGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppColors.accentGreen.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.bolt, color: AppColors.accentGreen),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Spark: Instant inbound is setting up...\nYou can receive immediately. Syncing in background.',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: AppColors.textSecondary, size: 24.sp),
    );
  }
}

class _NotificationIcon extends StatefulWidget {
  final VoidCallback onTap;

  const _NotificationIcon({required this.onTap});

  @override
  State<_NotificationIcon> createState() => _NotificationIconState();
}

class _NotificationIconState extends State<_NotificationIcon> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final count = await NotificationService.getUnreadCount();
    if (mounted) {
      setState(() => _unreadCount = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTap();
        // Refresh count after returning from notifications screen
        Future.delayed(const Duration(milliseconds: 500), _loadUnreadCount);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.notifications_outlined,
            color: AppColors.textSecondary,
            size: 24.sp,
          ),
          if (_unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: EdgeInsets.all(4.h),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                constraints: BoxConstraints(minWidth: 16.w, minHeight: 16.h),
                child: Text(
                  _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 58.w,
        child: Column(
          children: [
            Container(
              width: 48.w,
              height: 48.h,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Center(child: icon),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                height: 20.h / 12.h,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final Widget icon;
  final String title;
  final String time;
  final String amount;
  final Color amountColor;
  final VoidCallback? onTap;

  const _TransactionItem({
    required this.icon,
    required this.title,
    required this.time,
    required this.amount,
    required this.amountColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF374151), width: 1),
                color: AppColors.surface,
              ),
              child: Center(child: icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      height: 24.h / 14.h,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    time,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      height: 20.h / 12.h,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                color: amountColor,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                height: 24.h / 14.h,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    this.icon,
    this.customIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (customIcon != null)
                customIcon!
              else if (icon != null)
                Icon(
                  icon,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                  size: 24.sp,
                ),
              SizedBox(height: 4.h),
              Text(
                label,
                style: TextStyle(
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w400,
                  height: 16 / 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CashNavIcon extends StatelessWidget {
  final bool isSelected;

  const _CashNavIcon({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        '₦',
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textSecondary,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          height: 20 / 12,
        ),
      ),
    );
  }
}

class _SendIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(20.w, 20.h), painter: _SendIconPainter());
  }
}

class _SendIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path =
        Path()
          ..moveTo(size.width * 0.605, size.width * 0.903)
          ..lineTo(size.width * 0.605, size.width * 0.527)
          ..cubicTo(
            size.width * 0.612,
            size.width * 0.543,
            size.width * 0.622,
            size.width * 0.557,
            size.width * 0.633,
            size.width * 0.569,
          )
          ..cubicTo(
            size.width * 0.644,
            size.width * 0.581,
            size.width * 0.658,
            size.width * 0.591,
            size.width * 0.673,
            size.width * 0.598,
          )
          ..lineTo(size.width * 0.912, size.width * 0.094)
          ..moveTo(size.width * 0.455, size.width * 0.527)
          ..lineTo(size.width * 0.605, size.width * 0.527)
          ..moveTo(size.width * 0.912, size.width * 0.094)
          ..lineTo(size.width * 0.455, size.width * 0.527);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReceiveIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _ReceiveIconPainter(),
    );
  }
}

class _ReceiveIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path =
        Path()
          ..moveTo(size.width * 0.50, size.width * 0.625)
          ..lineTo(size.width * 0.50, size.width * 0.125)
          ..moveTo(size.width * 0.875, size.width * 0.625)
          ..lineTo(size.width * 0.875, size.width * 0.791)
          ..cubicTo(
            size.width * 0.875,
            size.width * 0.813,
            size.width * 0.866,
            size.width * 0.834,
            size.width * 0.851,
            size.width * 0.849,
          )
          ..cubicTo(
            size.width * 0.836,
            size.width * 0.864,
            size.width * 0.815,
            size.width * 0.873,
            size.width * 0.793,
            size.width * 0.873,
          )
          ..lineTo(size.width * 0.208, size.width * 0.873)
          ..cubicTo(
            size.width * 0.186,
            size.width * 0.873,
            size.width * 0.165,
            size.width * 0.864,
            size.width * 0.150,
            size.width * 0.849,
          )
          ..cubicTo(
            size.width * 0.135,
            size.width * 0.834,
            size.width * 0.125,
            size.width * 0.813,
            size.width * 0.125,
            size.width * 0.791,
          )
          ..lineTo(size.width * 0.125, size.width * 0.625)
          ..moveTo(size.width * 0.292, size.width * 0.417)
          ..lineTo(size.width * 0.50, size.width * 0.625)
          ..lineTo(size.width * 0.708, size.width * 0.417);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AirtimeIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _AirtimeIconPainter(),
    );
  }
}

class _AirtimeIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path =
        Path()
          ..addOval(
            Rect.fromCircle(
              center: Offset(size.width * 0.5, size.height * 0.13),
              radius: size.width * 0.06,
            ),
          )
          ..moveTo(size.width * 0.5, size.height * 0.2)
          ..lineTo(size.width * 0.5, size.height * 0.63)
          ..moveTo(size.width * 0.2, size.height * 0.2)
          ..lineTo(size.width * 0.8, size.height * 0.2)
          ..moveTo(size.width * 0.2, size.height * 0.95)
          ..lineTo(size.width * 0.8, size.height * 0.95)
          ..moveTo(size.width * 0.15, size.height * 0.35)
          ..lineTo(size.width * 0.15, size.height * 1.0)
          ..moveTo(size.width * 0.85, size.height * 0.35)
          ..lineTo(size.width * 0.85, size.height * 1.0)
          ..moveTo(size.width * 0.30, size.height * 0.42)
          ..lineTo(size.width * 0.70, size.height * 0.42);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PayBillsIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _PayBillsIconPainter(),
    );
  }
}

class _PayBillsIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path =
        Path()
          ..moveTo(size.width * 0.624, size.width * 0.583)
          ..cubicTo(
            size.width * 0.539,
            size.width * 0.583,
            size.width * 0.454,
            size.width * 0.551,
            size.width * 0.387,
            size.width * 0.490,
          )
          ..cubicTo(
            size.width * 0.319,
            size.width * 0.430,
            size.width * 0.270,
            size.width * 0.345,
            size.width * 0.250,
            size.width * 0.250,
          )
          ..cubicTo(
            size.width * 0.250,
            size.width * 0.183,
            size.width * 0.277,
            size.width * 0.118,
            size.width * 0.324,
            size.width * 0.071,
          )
          ..cubicTo(
            size.width * 0.371,
            size.width * 0.024,
            size.width * 0.436,
            size.width * 0.0,
            size.width * 0.500,
            size.width * 0.0,
          )
          ..cubicTo(
            size.width * 0.566,
            size.width * 0.0,
            size.width * 0.630,
            size.width * 0.024,
            size.width * 0.677,
            size.width * 0.071,
          )
          ..cubicTo(
            size.width * 0.724,
            size.width * 0.118,
            size.width * 0.750,
            size.width * 0.183,
            size.width * 0.750,
            size.width * 0.250,
          )
          ..cubicTo(
            size.width * 0.750,
            size.width * 0.387,
            size.width * 0.708,
            size.width * 0.513,
            size.width * 0.687,
            size.width * 0.479,
          )
          ..moveTo(size.width * 0.375, size.width * 0.747)
          ..lineTo(size.width * 0.624, size.width * 0.747)
          ..moveTo(size.width * 0.416, size.width * 0.916)
          ..lineTo(size.width * 0.581, size.width * 0.916);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReceiveTransactionIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _ReceiveTransactionIconPainter(),
    );
  }
}

class _ReceiveTransactionIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.accentGreen
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path =
        Path()
          ..moveTo(size.width * 0.708, size.width * 0.292)
          ..lineTo(size.width * 0.292, size.width * 0.708)
          ..moveTo(size.width * 0.708, size.width * 0.708)
          ..lineTo(size.width * 0.292, size.width * 0.708)
          ..lineTo(size.width * 0.292, size.width * 0.292);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SendTransactionIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(20.w, 20.h),
      painter: _SendTransactionIconPainter(),
    );
  }
}

class _SendTransactionIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = const Color(0xFFFF4D4F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path =
        Path()
          ..moveTo(size.width * 0.292, size.width * 0.292)
          ..lineTo(size.width * 0.708, size.width * 0.292)
          ..lineTo(size.width * 0.708, size.width * 0.708)
          ..moveTo(size.width * 0.292, size.width * 0.708)
          ..lineTo(size.width * 0.708, size.width * 0.292);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ZapIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(20, 20), painter: _ZapIconPainter());
  }
}

class _ZapIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path =
        Path()
          ..moveTo(size.width * 0.167, size.width * 0.583)
          ..lineTo(size.width * 0.547, size.width * 0.109)
          ..lineTo(size.width * 0.547, size.width * 0.417)
          ..lineTo(size.width * 0.829, size.width * 0.417)
          ..lineTo(size.width * 0.453, size.width * 0.891)
          ..lineTo(size.width * 0.453, size.width * 0.583)
          ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
