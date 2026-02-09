import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
// Cash screen is accessible from Trade -> Buy/Spend; removed from Home tabs
import 'package:sabi_wallet/features/more/presentation/screens/more_screen.dart';
import 'package:sabi_wallet/features/profile/presentation/screens/profile_screen.dart';
import 'package:sabi_wallet/core/widgets/cards/balance_card.dart';

import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'package:sabi_wallet/services/nostr/nostr_profile_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sabi_wallet/services/event_stream_service.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import '../providers/rate_provider.dart';
import 'package:sabi_wallet/features/trade/presentation/screens/trade_screen.dart';
import 'package:sabi_wallet/services/notification_service.dart';
import 'package:sabi_wallet/services/firebase/webhook_bridge_services.dart';
import 'package:sabi_wallet/services/firebase/fcm_token_registration_service.dart';
import 'package:sabi_wallet/core/utils/date_utils.dart' as date_utils;
import 'package:sabi_wallet/l10n/app_localizations.dart';

import 'package:sabi_wallet/features/home/providers/suggestions_provider.dart';
import 'package:sabi_wallet/features/home/widgets/suggestions_slider.dart';
import 'package:sabi_wallet/features/home/widgets/setup_tooltip_overlay.dart';
import 'package:sabi_wallet/features/onboarding/presentation/screens/backup_choice_screen.dart';
import 'package:sabi_wallet/features/profile/presentation/screens/change_pin_screen.dart';
import 'package:sabi_wallet/features/nostr/presentation/widgets/nostr_edit_modal.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../providers/wallet_info_provider.dart';
import '../providers/balance_provider.dart';
import '../providers/recent_transactions_provider.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
import 'qr_scanner_screen.dart';
import 'transactions_screen.dart';
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
      const TradeScreen(),
      const MoreScreen(),
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
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 App resumed - refreshing services...');
      // Refresh suggestions to reflect completed tasks
      ref.read(suggestionsProvider.notifier).refresh();

      // Refresh wallet/balance data on resume
      _refreshOnResume();
    }
  }

  /// Refresh critical services when app resumes from background
  Future<void> _refreshOnResume() async {
    try {
      // Re-check SDK state and refresh balance
      if (BreezSparkService.isInitialized) {
        await BreezSparkService.getBalance();
        ref.read(balanceNotifierProvider.notifier).refresh();
        ref.read(walletInfoProvider.notifier).refresh();
        ref.read(recentTransactionsProvider.notifier).refresh();
        debugPrint('✅ App resume refresh complete');
      } else {
        debugPrint('⚠️ SDK not initialized on resume, attempting re-init...');
        await _initializeBreezSDK();
      }
    } catch (e) {
      debugPrint('⚠️ Error refreshing on resume: $e');
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
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // Move app to background instead of killing it
          // This uses Android's moveTaskToBack via method channel
          const platform = MethodChannel('com.sabi.app/background');
          try {
            await platform.invokeMethod('moveToBackground');
          } catch (e) {
            // Fallback to system navigator if method channel fails
            SystemNavigator.pop();
          }
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
                icon: Icon(Icons.show_chart_outlined),
                label: 'Trade',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded),
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends ConsumerStatefulWidget {
  final bool isBalanceVisible;
  final VoidCallback onToggleBalance;

  const _HomeContent({
    required this.isBalanceVisible,
    required this.onToggleBalance,
  });

  @override
  ConsumerState<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<_HomeContent> {
  bool _showSetupTooltip = false;
  bool _tooltipChecked = false;

  @override
  void initState() {
    super.initState();
    _checkSetupTooltip();
  }

  Future<void> _checkSetupTooltip() async {
    if (_tooltipChecked) return;
    _tooltipChecked = true;

    final storage = ref.read(secureStorageServiceProvider);
    final shown = await storage.read(key: SecureStorageService.keySetupTooltipShown);
    
    if (shown == 'true') {
      return; // Already shown and dismissed
    }

    // Check if there are pending suggestions to show
    final suggestions = ref.read(suggestionsProvider);
    if (suggestions.isNotEmpty && mounted) {
      // Small delay to let the home screen render first
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() => _showSetupTooltip = true);
      }
    }
  }

  Future<void> _dismissSetupTooltip() async {
    setState(() => _showSetupTooltip = false);
    final storage = ref.read(secureStorageServiceProvider);
    await storage.write(key: SecureStorageService.keySetupTooltipShown, value: 'true');
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletInfoProvider);
    final suggestions = ref.watch(suggestionsProvider);

    return Stack(
      children: [
        SafeArea(
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
                    Builder(
                      builder: (context) {
                        final nostrProfile =
                            NostrProfileService().currentProfile;
                        // Use quick cache for instant display, fall back to profile
                        final username =
                            nostrProfile?.displayNameOrFallback ??
                            NostrProfileService.cachedDisplayName ??
                            'user';
                        final picture =
                            nostrProfile?.picture ??
                            NostrProfileService.cachedPicture;
                        final initial =
                            username.isNotEmpty
                                ? username[0].toUpperCase()
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
                              child: CircleAvatar(
                                radius: 18.r,
                                backgroundColor: AppColors.primary,
                                backgroundImage:
                                    (picture != null && picture.isNotEmpty)
                                        ? CachedNetworkImageProvider(picture)
                                        : null,
                                child:
                                    (picture == null || picture.isEmpty)
                                        ? Text(
                                          initial,
                                          style: TextStyle(
                                            color: AppColors.surface,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                        : null,
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
                        SizedBox(width: 16.w),
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
                // Trade tab is added to main navigation; its UI is implemented in _TradeScreen below.
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
                // Action buttons: 4 columns - responsive layout
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: _FigmaActionButton(
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
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _FigmaActionButton(
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
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _FigmaActionButton(
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
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _FigmaActionButton(
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
                      ),
                    ],
                  ),
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
                      shouldPulse: _showSetupTooltip,
                      onDismiss:
                          (type) => ref
                              .read(suggestionsProvider.notifier)
                              .dismiss(type),
                      onTap: (type) {
                        // Dismiss tooltip when user taps a suggestion
                        if (_showSetupTooltip) {
                          _dismissSetupTooltip();
                        }
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
        ),
        // Setup tooltip overlay
        if (_showSetupTooltip && suggestions.isNotEmpty)
          SetupTooltipOverlay(
            onDismiss: _dismissSetupTooltip,
            pendingSetupItems: suggestions.map((s) => s.name).toList(),
          ),
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



/// Copied Live Rates Card adapted for Trade tab
class _TradeLiveRatesCard extends ConsumerStatefulWidget {
  const _TradeLiveRatesCard();

  @override
  ConsumerState<_TradeLiveRatesCard> createState() =>
      _TradeLiveRatesCardState();
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
        child:
            _isLoading
                ? Center(
                  child: SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: const CircularProgressIndicator(
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
                                    color: const Color(
                                      0xFF00C853,
                                    ).withOpacity(0.2),
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
    // Get screen width to determine sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactScreen = screenWidth < 300; // Fold cover screen
    final isMediumScreen = screenWidth < 400; // Small phones
    
    // Responsive icon size
    final iconSize = isCompactScreen ? 22.w : (isMediumScreen ? 24.w : 28.w);
    final fontSize = isCompactScreen ? 10.sp : (isMediumScreen ? 11.sp : 12.sp);
    final verticalPadding = isCompactScreen ? 8.w : 10.w;
    
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.0, // Keep square shape
        child: Container(
          padding: EdgeInsets.all(verticalPadding),
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
                  width: iconSize,
                  height: iconSize,
                  color: const Color(0xFFA1A1B2),
                )
              else if (icon != null)
                Icon(icon, size: iconSize, color: const Color(0xFFA1A1B2)),
              SizedBox(height: 4.h),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFA1A1B2),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
              SizedBox(height: 12.h),
              // Trade tab preview could live here in future
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
