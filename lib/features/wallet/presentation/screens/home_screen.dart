import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'dart:io';
import 'package:sabi_wallet/features/cash/presentation/screens/cash_screen.dart'
    as cash_screen;
import 'package:sabi_wallet/features/profile/presentation/screens/profile_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_home_screen.dart';
import 'package:sabi_wallet/core/widgets/cards/balance_card.dart';

import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'package:sabi_wallet/services/profile_service.dart';
import 'package:sabi_wallet/services/event_stream_service.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/notification_service.dart';
import 'package:sabi_wallet/services/firebase/webhook_bridge_services.dart';
import 'package:sabi_wallet/services/firebase/fcm_token_registration_service.dart';
import 'package:sabi_wallet/core/utils/date_utils.dart' as date_utils;
import 'package:sabi_wallet/l10n/app_localizations.dart';

import 'package:sabi_wallet/features/home/providers/suggestions_provider.dart';
import 'package:sabi_wallet/features/home/widgets/suggestions_slider.dart';
import 'package:sabi_wallet/features/onboarding/presentation/screens/backup_choice_screen.dart';
import 'package:sabi_wallet/features/profile/presentation/screens/change_pin_screen.dart';
import 'package:sabi_wallet/features/nostr/nostr_feed_screen.dart';
import 'package:sabi_wallet/features/nostr/nostr_edit_modal.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../providers/wallet_info_provider.dart';
import '../providers/balance_provider.dart';
import '../providers/recent_transactions_provider.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
import 'qr_scanner_screen.dart';
import 'transactions_screen.dart';
import 'package:sabi_wallet/features/agent/agent_screen.dart';
import 'package:sabi_wallet/features/common/coming_soon_screen.dart';
import 'package:sabi_wallet/features/vtu/vtu.dart';
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
      const cash_screen.CashScreen(),
      const P2PHomeScreen(),
      const ProfileScreen(),
    ];
    // Initialize Breez SDK first, then poll payments
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Refresh suggestions to reflect any completed tasks
        ref.read(suggestionsProvider.notifier).refresh();

        await _initializeBreezSDK();

        // Check if SDK initialized successfully
        if (!BreezSparkService.isInitialized) {
          debugPrint(
            '⚠️ SDK not initialized after _initializeBreezSDK() - will retry later',
          );
          // Don't throw - just continue with empty data, auto-refresh will pick it up
        } else {
          debugPrint(
            '✅ SDK confirmed initialized - proceeding with data refresh',
          );

          // Sync and get balance immediately after init
          try {
            await BreezSparkService.syncAndGetBalance();
          } catch (e) {
            debugPrint('⚠️ syncAndGetBalance failed: $e');
          }
        }

        // Refresh providers (they will return safe defaults if SDK not ready)
        await ref.read(balanceNotifierProvider.notifier).refresh();
        await ref.read(walletInfoProvider.notifier).refresh();
        await ref.read(recentTransactionsProvider.notifier).refresh();
        await ref.read(allTransactionsNotifierProvider.notifier).refresh();
        _pollPaymentsForConfetti();
        _initEventStream();
        _startAutoRefresh();
      } catch (e) {
        debugPrint('❌ Failed to initialize wallet services: $e');
        // Continue without crashing - start auto-refresh anyway
        _startAutoRefresh();
      }
    });
  }

  void _startAutoRefresh() {
    // Poll balance and transactions every 3 seconds using Breez SDK
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (mounted && BreezSparkService.isInitialized) {
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
      } else if (mounted && !BreezSparkService.isInitialized) {
        debugPrint('⚠️ SDK not initialized during auto-refresh, skipping');
      }
    });
  }

  Future<void> _initializeBreezSDK() async {
    try {
      // Check if already initialized
      if (BreezSparkService.isInitialized) {
        debugPrint('✅ SDK already initialized');
        return;
      }

      final storage = ref.read(secureStorageServiceProvider);
      String? mnemonic = await storage.getWalletSeed();
      debugPrint('🔍 Looking for wallet seed in secure storage...');

      // If not in secure storage, try to get from Hive (migration case)
      if (mnemonic == null || mnemonic.isEmpty) {
        debugPrint('⚠️ No seed in secure storage, checking Hive...');
        mnemonic = await BreezSparkService.getMnemonic();
        // If found in Hive, save to secure storage for future use
        if (mnemonic != null && mnemonic.isNotEmpty) {
          await storage.saveWalletSeed(mnemonic);
          debugPrint('✅ Migrated mnemonic from Hive to secure storage');
        }
      }

      if (mnemonic != null && mnemonic.isNotEmpty) {
        debugPrint('🔐 Found mnemonic, initializing SDK with seed...');
        await BreezSparkService.initializeSparkSDK(mnemonic: mnemonic);

        if (BreezSparkService.isInitialized) {
          debugPrint('✅ Spark SDK initialized successfully');

          // Start webhook bridge for push notifications
          BreezWebhookBridgeService().startListening();
          debugPrint('✅ BreezWebhookBridgeService started from home screen');

          // Register FCM token for push notifications
          FCMTokenRegistrationService().registerToken();
        } else {
          throw Exception('SDK initialization returned but _sdk is still null');
        }
      } else {
        throw Exception('No wallet seed found - cannot initialize SDK');
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize Spark SDK: $e');
      rethrow; // Re-throw so caller knows initialization failed
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

  void _pollPaymentsForConfetti() {
    // Implementation for polling payments for confetti
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh suggestions when app resumes to reflect completed tasks
    if (state == AppLifecycleState.resumed) {
      ref.read(suggestionsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceState = ref.watch(balanceNotifierProvider);
    // Show skeleton while SDK is initializing OR balance is loading
    final bool showSkeleton =
        !BreezSparkService.isInitialized || balanceState.isLoading;

    // Minimize app instead of killing it when back button is pressed
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Move app to background instead of killing it
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Skeletonizer(
              enabled: showSkeleton, // Skeleton stays on until SDK is ready
              enableSwitchAnimation: true,
              containersColor: AppColors.surface,
              justifyMultiLineText: true,
              effect: PulseEffect(
                duration: Duration(seconds: 1),
                from: AppColors.background,
                to: AppColors.borderColor.withValues(alpha: 0.3),
                lowerBound: 0,
                upperBound: 1.0,
              ),
              switchAnimationConfig: SwitchAnimationConfig(
                switchOutCurve: Curves.bounceInOut,
              ),
              child: Stack(
                children: [
                  // The main content (tabs)
                  _screens[_currentIndex],
                ],
              ),
            ),
            // SDK initialization in progress - skeleton loader handles the loading state
            // No error overlay shown - the skeleton continues until SDK is ready
          ],
        ),
        // Ensure the bottom navigation matches the app dark theme and avoids
        // system insets causing white gaps by wrapping it in a SafeArea.
        bottomNavigationBar: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.surface,
            // Use the brand primary color for the selected tab
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondary,
            showUnselectedLabels: true,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet),
                label: 'Cash',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.swap_horiz),
                label: 'P2P',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatefulWidget {
  final bool isBalanceVisible;
  final VoidCallback onToggleBalance;

  const _HomeContent({
    required this.isBalanceVisible,
    required this.onToggleBalance,
  });

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final walletAsync = ref.watch(walletInfoProvider);

        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left: 30.h,
              right: 30.h,
              top: 30.h,
              bottom:
                  30.h +
                  MediaQuery.of(context).padding.bottom +
                  kBottomNavigationBarHeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with greeting, QR scanner and notifications
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Greeting: Hi, <username> with avatar
                    FutureBuilder(
                      future: ProfileService.getProfile(),
                      builder: (context, snapshot) {
                        final profile = snapshot.data;
                        final username =
                            (profile != null && profile.username.isNotEmpty)
                                ? profile.username
                                : 'user';
                        final initial =
                            (profile != null && profile.fullName.isNotEmpty)
                                ? profile.initial
                                : 'U';

                        return Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProfileScreen(),
                                  ),
                                );
                              },
                              child: Builder(
                                builder: (_) {
                                  final pic = profile?.profilePicturePath;
                                  return CircleAvatar(
                                    radius: 18.r,
                                    backgroundColor: AppColors.primary,
                                    backgroundImage:
                                        (pic != null && pic.isNotEmpty)
                                            ? FileImage(File(pic))
                                                as ImageProvider
                                            : null,
                                    child:
                                        (pic == null || pic.isEmpty)
                                            ? Text(
                                              initial,
                                              style: TextStyle(
                                                color: AppColors.surface,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            )
                                            : null,
                                  );
                                },
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Text(
                              'Hi, $username',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    Row(
                      children: [
                        _HeaderIcon(
                          icon: Icons.qr_code_scanner_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const QRScannerScreen(),
                              ),
                            );
                          },
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
                SizedBox(height: 10.h),
                // Moved: tap to switch currency hint (placed above balance card)
                Text(
                  AppLocalizations.of(context)!.tapToSwitch,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 4.h),
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
                                ref
                                    .watch(eventStreamServiceProvider)
                                    .isConnected,
                            isBalanceHidden: !widget.isBalanceVisible,
                            onToggleHide: widget.onToggleBalance,
                          ),
                      data: (balance) {
                        return FutureBuilder<String?>(
                          future: ref
                              .read(secureStorageServiceProvider)
                              .read(key: 'first_payment_confetti_pending'),
                          builder: (context, confettiSnapshot) {
                            final showConfetti =
                                confettiSnapshot.data == 'true';

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
                              isBalanceHidden: !widget.isBalanceVisible,
                              onToggleHide: widget.onToggleBalance,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                SizedBox(height: 17.h),
                // Action buttons: 4 columns x 2 rows layout
                Column(
                  children: [
                    // First row: Send, Receive, Airtime, Data
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _FigmaActionButton(
                          asset: 'assets/icons/Send.png',
                          label: AppLocalizations.of(context)!.send,
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SendScreen(),
                                ),
                              ),
                        ),
                        SizedBox(width: 10.w),
                        _FigmaActionButton(
                          asset: 'assets/icons/receive.png',
                          label: AppLocalizations.of(context)!.receive,
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReceiveScreen(),
                                ),
                              ),
                        ),
                        SizedBox(width: 10.w),
                        _FigmaActionButton(
                          asset: 'assets/icons/airtime.png',
                          label: AppLocalizations.of(context)!.airtime,
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AirtimeScreen(),
                                ),
                              ),
                        ),
                        SizedBox(width: 10.w),
                        _FigmaActionButton(
                          asset: 'assets/icons/data.png',
                          label: 'Data',
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DataScreen(),
                                ),
                              ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    // Second row: Nostr, Agent, Card, Rewards
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _FigmaActionButton(
                          icon: Icons.electric_bolt_outlined,
                          label: 'Nostr',
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NostrFeedScreen(),
                                ),
                              ),
                        ),
                        SizedBox(width: 10.w),
                        _FigmaActionButton(
                          icon: Icons.groups_outlined,
                          label: 'Agent',
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AgentScreen(),
                                ),
                              ),
                        ),
                        SizedBox(width: 10.w),
                        _FigmaActionButton(
                          icon: Icons.credit_card_outlined,
                          label: 'card',
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => const ComingSoonScreen(
                                        featureName: 'Virtual Card',
                                        icon: Icons.credit_card,
                                        description:
                                            'Get a virtual Naira card.\nSpend your Bitcoin anywhere!',
                                        accentColor: Color(0xFF9C27B0),
                                      ),
                                ),
                              ),
                        ),
                        SizedBox(width: 10.w),
                        _FigmaActionButton(
                          icon: Icons.receipt_long_outlined,
                          label: 'utilities',
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const UtilitiesHubScreen(),
                                ),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Consumer(
                  builder: (context, ref, _) {
                    final suggestionsState = ref.watch(suggestionsProvider);
                    if (suggestionsState.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return SuggestionsSlider(
                      suggestions: suggestionsState,
                      onDismiss:
                          (type) => ref
                              .read(suggestionsProvider.notifier)
                              .dismiss(type),
                      onTap: (type) {
                        switch (type) {
                          case SuggestionType.backup:
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BackupChoiceScreen(),
                              ),
                            );
                            break;
                          case SuggestionType.socialRecovery:
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BackupChoiceScreen(),
                              ),
                            );
                            break;
                          case SuggestionType.nostr:
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder:
                                  (_) => NostrEditModal(
                                    onSaved: () {
                                      // Mark nostr suggestion as completed
                                      ref
                                          .read(suggestionsProvider.notifier)
                                          .markCompleted(SuggestionType.nostr);
                                    },
                                  ),
                            );
                            break;
                          case SuggestionType.pin:
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        const ChangePinScreen(isCreate: true),
                              ),
                            );
                            break;
                        }
                      },
                    );
                  },
                ),
                SizedBox(height: 30.h),
                // Figma-style Quick Action Button
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
                              padding: EdgeInsets.symmetric(
                                horizontal: 40.w,
                                vertical: 40.h,
                              ),
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
                              padding: EdgeInsets.symmetric(
                                horizontal: 40.w,
                                vertical: 40.h,
                              ),
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

                                final timeStr = date_utils
                                    .formatTransactionTime(payment.paymentTime);

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
        );
      },
    );
  }

  String _formatSats(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }
}

class _FigmaActionButton extends StatelessWidget {
  final String? asset;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;

  const _FigmaActionButton({
    this.asset,
    this.icon,
    required this.label,
    required this.onTap,
  }) : assert(
         asset != null || icon != null,
         'Either asset or icon must be provided',
       );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80.w,
        height: 80.h,
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          borderRadius: BorderRadius.circular(15.r),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (asset != null)
              Image.asset(
                asset!,
                width: 28.w,
                height: 28.h,
                color: const Color(0xFFA1A1B2),
              )
            else if (icon != null)
              Icon(icon, size: 28.w, color: const Color(0xFFA1A1B2)),
            SizedBox(height: 6.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFA1A1B2),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

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
