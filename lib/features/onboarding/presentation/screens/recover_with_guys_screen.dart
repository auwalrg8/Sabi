import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/recovery/services/social_recovery_service.dart';
import 'package:sabi_wallet/features/nostr/services/nostr_service.dart';
import 'wallet_success_screen.dart';

enum RecoveryState { input, searching, requestingShares, restored, failed }

/// Display model for recovery contacts (distinct from SocialRecoveryService.RecoveryContact)
class RecoveryGuardianDisplay {
  final String name;
  final String npub;
  final String initial;
  bool shareReceived;

  RecoveryGuardianDisplay({
    required this.name,
    required this.npub,
    required this.initial,
    this.shareReceived = false,
  });
}

class RecoverWithGuysScreen extends StatefulWidget {
  const RecoverWithGuysScreen({super.key});

  @override
  State<RecoverWithGuysScreen> createState() => _RecoverWithGuysScreenState();
}

class _RecoverWithGuysScreenState extends State<RecoverWithGuysScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  RecoveryState _state = RecoveryState.input;
  int _sharesReceived = 0;
  late AnimationController _spinController;
  late AnimationController _progressController;

  List<RecoveryGuardianDisplay> _contacts = [];
  final List<RecoveryShare> _collectedShares = [];
  StreamSubscription<RecoveryShare>? _shareSubscription;
  String? _errorMessage;
  String? _recoveredSeed;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _spinController.dispose();
    _progressController.dispose();
    _shareSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startRecovery() async {
    setState(() {
      _state = RecoveryState.searching;
      _errorMessage = null;
    });

    try {
      // Initialize services
      await SocialRecoveryService.init();
      await NostrService.init();

      // The identifier (npub or phone) could be used in future to look up
      // the user's recovery contacts from a decentralized registry
      // For now, we use locally stored contacts

      // Look up the user's stored recovery contacts
      final contacts = await SocialRecoveryService.getRecoveryContacts();

      if (contacts.isEmpty) {
        setState(() {
          _state = RecoveryState.failed;
          _errorMessage = 'No recovery contacts found for this account.';
        });
        return;
      }

      // Convert to display contacts
      _contacts =
          contacts
              .map(
                (c) => RecoveryGuardianDisplay(
                  name: c.name,
                  npub: c.npub,
                  initial: c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                  shareReceived: false,
                ),
              )
              .toList();

      setState(() {
        _state = RecoveryState.requestingShares;
      });

      // Start listening for shares
      _startListeningForShares();

      // Request shares from all contacts
      await SocialRecoveryService.requestRecoveryShares();
    } catch (e) {
      print('❌ Recovery error: $e');
      setState(() {
        _state = RecoveryState.failed;
        _errorMessage = 'Failed to start recovery: ${e.toString()}';
      });
    }
  }

  void _startListeningForShares() {
    _shareSubscription = SocialRecoveryService.listenForRecoveryShares().listen(
      (share) {
        if (!mounted) return;

        // Mark the contact as having responded
        final contactIndex = _contacts.indexWhere(
          (c) => c.npub == share.senderNpub,
        );

        if (contactIndex >= 0) {
          setState(() {
            _contacts[contactIndex].shareReceived = true;
            _collectedShares.add(share);
            _sharesReceived = _collectedShares.length;
            _progressController.animateTo(
              _sharesReceived / 3.0,
              duration: const Duration(milliseconds: 500),
            );
          });
        } else {
          // Share from unknown contact - still collect it
          _collectedShares.add(share);
          setState(() {
            _sharesReceived = _collectedShares.length;
            _progressController.animateTo(
              _sharesReceived / 3.0,
              duration: const Duration(milliseconds: 500),
            );
          });
        }

        // Check if we have enough shares
        if (_collectedShares.length >= 3) {
          _attemptRecovery();
        }
      },
      onError: (error) {
        print('❌ Share listening error: $error');
      },
    );

    // Set a timeout for receiving shares
    Future.delayed(const Duration(minutes: 5), () {
      if (mounted && _state == RecoveryState.requestingShares) {
        if (_collectedShares.length < 3) {
          setState(() {
            _state = RecoveryState.failed;
            _errorMessage =
                'Timed out waiting for shares. '
                'Only received ${_collectedShares.length}/3 shares.';
          });
        }
      }
    });
  }

  Future<void> _attemptRecovery() async {
    try {
      final recoveredSeed = await SocialRecoveryService.attemptRecovery(
        _collectedShares,
      );

      if (recoveredSeed != null) {
        setState(() {
          _recoveredSeed = recoveredSeed;
          _state = RecoveryState.restored;
        });
      } else {
        setState(() {
          _state = RecoveryState.failed;
          _errorMessage = 'Failed to reconstruct wallet from shares.';
        });
      }
    } catch (e) {
      setState(() {
        _state = RecoveryState.failed;
        _errorMessage = 'Recovery failed: ${e.toString()}';
      });
    }
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
              _buildHeader(),
              SizedBox(height: 24.h),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recover Your Wallet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Google Sans',
                ),
              ),
              Text(
                'Your guys go help you get am back',
                style: TextStyle(
                  color: const Color(0xFFA1A1B2),
                  fontSize: 12.sp,
                  fontFamily: 'Google Sans',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case RecoveryState.input:
        return _buildInputState();
      case RecoveryState.searching:
        return _buildSearchingState();
      case RecoveryState.requestingShares:
        return _buildRequestingSharesState();
      case RecoveryState.restored:
        return _buildRestoredState();
      case RecoveryState.failed:
        return _buildFailedState();
    }
  }

  Widget _buildInputState() {
    final bool hasInput = _controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Social Recovery Card
                Container(
                  padding: EdgeInsets.all(20.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFF333355)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FFB2).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.group,
                              color: const Color(0xFF00FFB2),
                              size: 24.r,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Social Recovery',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Google Sans',
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'Enter your Nostr npub or phone number',
                                  style: TextStyle(
                                    color: const Color(0xFFA1A1B2),
                                    fontSize: 12.sp,
                                    fontFamily: 'Google Sans',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C0C1A),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: const Color(0xFF333355)),
                        ),
                        child: TextField(
                          controller: _controller,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontFamily: 'Google Sans',
                          ),
                          decoration: InputDecoration(
                            hintText: 'npub1... or +234 803 456 7890',
                            hintStyle: TextStyle(
                              color: const Color(0xFF666680),
                              fontSize: 13.sp,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 14.h,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),

                // Info Card
                Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FFB2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: const Color(0xFF00FFB2).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: const Color(0xFF00FFB2),
                        size: 20.r,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'We\'ll look up your Nostr profile, find your recovery guardians, and send them automatic requests to help you recover.',
                          style: TextStyle(
                            color: const Color(0xFFCCCCCC),
                            fontSize: 12.sp,
                            fontFamily: 'Google Sans',
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Start Button
        GestureDetector(
          onTap: hasInput ? _startRecovery : null,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            decoration: BoxDecoration(
              color:
                  hasInput ? const Color(0xFFF7931A) : const Color(0xFF333355),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: Text(
                'Start Recovery',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color:
                      hasInput
                          ? const Color(0xFF0C0C1A)
                          : const Color(0xFF666680),
                  fontFamily: 'Google Sans',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchingState() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(32.r),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _spinController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _spinController.value * 2 * math.pi,
                  child: Icon(
                    Icons.refresh,
                    color: const Color(0xFFF7931A),
                    size: 64.r,
                  ),
                );
              },
            ),
            SizedBox(height: 20.h),
            Text(
              'Looking Up Your Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                fontFamily: 'Google Sans',
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Searching Nostr network for your\nrecovery contacts...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFA1A1B2),
                fontSize: 14.sp,
                fontFamily: 'Google Sans',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestingSharesState() {
    return Column(
      children: [
        // Progress Card
        Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            children: [
              Text(
                'Requesting Shares',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Google Sans',
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Waiting for your guardians to respond...',
                style: TextStyle(
                  color: const Color(0xFFA1A1B2),
                  fontSize: 14.sp,
                  fontFamily: 'Google Sans',
                ),
              ),
              SizedBox(height: 20.h),

              // Progress bar
              AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: LinearProgressIndicator(
                          value: _progressController.value,
                          backgroundColor: const Color(0xFF333355),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF00FFB2),
                          ),
                          minHeight: 8.h,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        '$_sharesReceived/3 shares received',
                        style: TextStyle(
                          color: const Color(0xFF00FFB2),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Google Sans',
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),

        // Contacts List
        Expanded(
          child: ListView.builder(
            itemCount: _contacts.length,
            itemBuilder: (context, index) {
              final contact = _contacts[index];
              return Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color:
                        contact.shareReceived
                            ? const Color(0xFF00FFB2)
                            : const Color(0xFF333355),
                  ),
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 48.r,
                      height: 48.r,
                      decoration: BoxDecoration(
                        color:
                            contact.shareReceived
                                ? const Color(0xFF00FFB2)
                                : const Color(0xFF8B5CF6),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child:
                            contact.shareReceived
                                ? Icon(
                                  Icons.check,
                                  color: const Color(0xFF0C0C1A),
                                  size: 24.r,
                                )
                                : Text(
                                  contact.initial,
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                      ),
                    ),
                    SizedBox(width: 12.w),

                    // Name and status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Google Sans',
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            contact.shareReceived
                                ? 'Share received ✓'
                                : 'Waiting for response...',
                            style: TextStyle(
                              color:
                                  contact.shareReceived
                                      ? const Color(0xFF00FFB2)
                                      : const Color(0xFFA1A1B2),
                              fontSize: 12.sp,
                              fontFamily: 'Google Sans',
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status icon
                    if (!contact.shareReceived)
                      AnimatedBuilder(
                        animation: _spinController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _spinController.value * 2 * math.pi,
                            child: Icon(
                              Icons.refresh,
                              color: const Color(0xFFA1A1B2),
                              size: 20.r,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRestoredState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: const Color(0xFF00FFB2).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              color: const Color(0xFF00FFB2),
              size: 64.r,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Wallet Recovered! 🎉',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
              fontFamily: 'Google Sans',
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Your wallet has been successfully restored\nusing social recovery.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFA1A1B2),
              fontSize: 14.sp,
              fontFamily: 'Google Sans',
            ),
          ),
          SizedBox(height: 40.h),
          GestureDetector(
            onTap: () {
              // Store the recovered seed before navigating
              if (_recoveredSeed != null) {
                // The recovered seed will be used by the success screen flow
                // to initialize the wallet
                SocialRecoveryService.storeRecoveredSeed(_recoveredSeed!);
              }

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WalletSuccessScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 24.w),
              padding: EdgeInsets.symmetric(vertical: 16.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF7931A),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
                child: Text(
                  'Continue to Wallet',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0C0C1A),
                    fontFamily: 'Google Sans',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, color: Colors.red, size: 64.r),
          ),
          SizedBox(height: 24.h),
          Text(
            'Recovery Failed',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
              fontFamily: 'Google Sans',
            ),
          ),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              _errorMessage ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFA1A1B2),
                fontSize: 14.sp,
                fontFamily: 'Google Sans',
              ),
            ),
          ),
          SizedBox(height: 40.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _state = RecoveryState.input;
                    _errorMessage = null;
                    _contacts.clear();
                    _collectedShares.clear();
                    _sharesReceived = 0;
                    _progressController.value = 0;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 14.h,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFF7931A)),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF7931A),
                      fontFamily: 'Google Sans',
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 14.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF333355),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'Go Back',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: 'Google Sans',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
