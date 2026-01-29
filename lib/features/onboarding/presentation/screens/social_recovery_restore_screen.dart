import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/nostr/services/nostr_service.dart';
import 'package:sabi_wallet/features/recovery/services/social_recovery_service.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/firebase/webhook_bridge_services.dart';
import 'package:sabi_wallet/services/firebase/fcm_token_registration_service.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/home_screen.dart';

/// Social recovery restore screen
///
/// User enters their guardian npubs (at least 3) and requests shares
/// from them via Nostr DM. Once enough shares are collected, the wallet
/// is reconstructed.
class SocialRecoveryRestoreScreen extends StatefulWidget {
  const SocialRecoveryRestoreScreen({super.key});

  @override
  State<SocialRecoveryRestoreScreen> createState() =>
      _SocialRecoveryRestoreScreenState();
}

class _SocialRecoveryRestoreScreenState
    extends State<SocialRecoveryRestoreScreen>
    with TickerProviderStateMixin {
  // Guardian npub controllers (up to 5)
  final List<TextEditingController> _guardianControllers = List.generate(
    5,
    (_) => TextEditingController(),
  );

  // State
  RecoveryPhase _phase = RecoveryPhase.enterGuardians;
  final List<_GuardianStatus> _guardianStatuses = [];
  final List<RecoveryShare> _collectedShares = [];
  StreamSubscription<RecoveryShare>? _shareSubscription;
  String? _errorMessage;
  bool _isLoading = false;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    for (final c in _guardianControllers) {
      c.dispose();
    }
    _shareSubscription?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  List<String> get _validGuardianNpubs {
    return _guardianControllers
        .map((c) => c.text.trim())
        .where((npub) => npub.isNotEmpty && npub.startsWith('npub1'))
        .toList();
  }

  bool get _hasEnoughGuardians => _validGuardianNpubs.length >= 3;

  Future<void> _startRecovery() async {
    if (!_hasEnoughGuardians) {
      setState(() {
        _errorMessage = 'Please enter at least 3 valid guardian npubs';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _phase = RecoveryPhase.connecting;
    });

    try {
      // Initialize Nostr service
      await NostrService.init();

      // Generate new temporary keys for this recovery session
      // This creates a fresh identity to receive the recovery shares
      final tempKeypair = await NostrService.generateKeys();
      final myNpub = tempKeypair['npub'];

      if (myNpub == null) {
        throw Exception('Failed to generate temporary keypair');
      }

      await NostrService.reinitialize();

      // Build guardian statuses
      _guardianStatuses.clear();
      for (final npub in _validGuardianNpubs) {
        _guardianStatuses.add(
          _GuardianStatus(
            npub: npub,
            name: 'Guardian ${_guardianStatuses.length + 1}',
          ),
        );
      }

      setState(() {
        _phase = RecoveryPhase.requestingShares;
      });

      // Start listening for incoming shares
      _startListeningForShares();

      // Send recovery requests to all guardians
      await _sendRecoveryRequests(myNpub);
    } catch (e) {
      debugPrint('❌ Recovery init error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to start recovery: $e';
        _phase = RecoveryPhase.enterGuardians;
      });
    }
  }

  Future<void> _sendRecoveryRequests(String myNpub) async {
    final requestContent = jsonEncode({
      'type': 'sabi_recovery_request',
      'version': 1,
      'requester_npub': myNpub,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'message':
          'I need to recover my Sabi Wallet. Please send me the recovery share I gave you.',
    });

    for (final status in _guardianStatuses) {
      try {
        await NostrService.sendEncryptedDM(
          targetNpub: status.npub,
          message: requestContent,
        );

        setState(() {
          status.requestSent = true;
        });
        debugPrint('✅ Sent recovery request to ${status.npub}');
      } catch (e) {
        debugPrint('❌ Failed to send request to ${status.npub}: $e');
        setState(() {
          status.error = 'Failed to send request';
        });
      }
    }

    setState(() {
      _isLoading = false;
    });

    // Set timeout for receiving shares
    Future.delayed(const Duration(minutes: 10), () {
      if (mounted && _phase == RecoveryPhase.requestingShares) {
        if (_collectedShares.length < 3) {
          setState(() {
            _phase = RecoveryPhase.failed;
            _errorMessage =
                'Timed out waiting for shares. '
                'Received ${_collectedShares.length}/3 needed shares. '
                'Make sure your guardians are online.';
          });
        }
      }
    });
  }

  void _startListeningForShares() {
    _shareSubscription = SocialRecoveryService.listenForRecoveryShares().listen(
      (share) {
        if (!mounted) return;

        debugPrint('📥 Received share from ${share.senderNpub}');

        // Find matching guardian
        final guardianIndex = _guardianStatuses.indexWhere(
          (g) => g.npub == share.senderNpub,
        );

        if (guardianIndex >= 0) {
          setState(() {
            _guardianStatuses[guardianIndex].shareReceived = true;
          });
        }

        // Add to collected shares (avoid duplicates)
        final exists = _collectedShares.any(
          (s) => s.senderNpub == share.senderNpub,
        );
        if (!exists) {
          _collectedShares.add(share);
          _progressController.animateTo(
            _collectedShares.length / 3.0,
            duration: const Duration(milliseconds: 500),
          );
        }

        setState(() {});

        // Check if we have enough shares
        if (_collectedShares.length >= 3) {
          _attemptRecovery();
        }
      },
      onError: (error) {
        debugPrint('❌ Share listening error: $error');
      },
    );
  }

  /// Show dialog for manually entering a share (from Primal or other Nostr client)
  void _showManualShareEntryDialog() {
    final shareController = TextEditingController();
    final npubController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24.w,
            right: 24.w,
            top: 24.h,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste Recovery Share',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'If your guardian sent the share via Primal or another Nostr client, paste the JSON content here.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 16.h),

              // Guardian npub input
              Text(
                'Guardian npub',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 6.h),
              TextField(
                controller: npubController,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: 'npub1...',
                  hintStyle:
                      TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                ),
              ),
              SizedBox(height: 16.h),

              // Share JSON input
              Text(
                'Share JSON',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 6.h),
              TextField(
                controller: shareController,
                maxLines: 4,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.sp,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: '{"type":"sabi_recovery_share",...}',
                  hintStyle:
                      TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                ),
              ),
              SizedBox(height: 20.h),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: () {
                    final shareJson = shareController.text.trim();
                    final senderNpub = npubController.text.trim();

                    if (shareJson.isEmpty || senderNpub.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please fill in both fields'),
                          backgroundColor: AppColors.accentRed,
                        ),
                      );
                      return;
                    }

                    final share = SocialRecoveryService.parseManualShare(
                      shareJson,
                      senderNpub,
                    );

                    if (share == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Invalid share format'),
                          backgroundColor: AppColors.accentRed,
                        ),
                      );
                      return;
                    }

                    // Add to collected shares
                    final exists = _collectedShares.any(
                      (s) =>
                          s.senderNpub == share.senderNpub ||
                          s.index == share.index,
                    );
                    if (!exists) {
                      _collectedShares.add(share);
                      _progressController.animateTo(
                        _collectedShares.length / 3.0,
                        duration: const Duration(milliseconds: 500),
                      );

                      // Update guardian status if matches
                      final guardianIndex = _guardianStatuses.indexWhere(
                        (g) => g.npub == senderNpub,
                      );
                      if (guardianIndex >= 0) {
                        _guardianStatuses[guardianIndex].shareReceived = true;
                      }

                      setState(() {});

                      Navigator.pop(ctx);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Share added! (${_collectedShares.length}/3)',
                          ),
                          backgroundColor: AppColors.accentGreen,
                        ),
                      );

                      // Check if we have enough shares
                      if (_collectedShares.length >= 3) {
                        _attemptRecovery();
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('This share was already added'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Add Share',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _attemptRecovery() async {
    setState(() {
      _phase = RecoveryPhase.reconstructing;
    });

    try {
      final recoveredSeed = await SocialRecoveryService.attemptRecovery(
        _collectedShares,
      );

      if (recoveredSeed != null) {
        // Initialize wallet with recovered seed
        await BreezSparkService.initializeSparkSDK(mnemonic: recoveredSeed);
        await BreezSparkService.setOnboardingComplete();

        // Start services
        BreezWebhookBridgeService().startListening();
        FCMTokenRegistrationService().registerToken();

        setState(() {
          _phase = RecoveryPhase.success;
        });

        // Navigate to home after delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      } else {
        throw Exception('Failed to reconstruct wallet from shares');
      }
    } catch (e) {
      debugPrint('❌ Recovery attempt error: $e');
      setState(() {
        _phase = RecoveryPhase.failed;
        _errorMessage = 'Failed to recover wallet: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: switch (_phase) {
          RecoveryPhase.enterGuardians => _buildEnterGuardiansPhase(),
          RecoveryPhase.connecting => _buildConnectingPhase(),
          RecoveryPhase.requestingShares => _buildRequestingPhase(),
          RecoveryPhase.reconstructing => _buildReconstructingPhase(),
          RecoveryPhase.success => _buildSuccessPhase(),
          RecoveryPhase.failed => _buildFailedPhase(),
        },
      ),
    );
  }

  Widget _buildEnterGuardiansPhase() {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Social Recovery',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          Text(
            'Enter Guardian Npubs',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Enter the npubs of at least 3 guardians who hold your recovery shares.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
          ),

          SizedBox(height: 24.h),

          // Guardian inputs
          Expanded(
            child: ListView.separated(
              itemCount: 5,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                return _buildGuardianInput(index);
              },
            ),
          ),

          // Error message
          if (_errorMessage != null) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.accentRed,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: AppColors.accentRed,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 16.h),

          // Progress indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _hasEnoughGuardians ? Icons.check_circle : Icons.info_outline,
                color:
                    _hasEnoughGuardians
                        ? AppColors.accentGreen
                        : AppColors.textSecondary,
                size: 16.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                '${_validGuardianNpubs.length}/3 guardians entered',
                style: TextStyle(
                  color:
                      _hasEnoughGuardians
                          ? AppColors.accentGreen
                          : AppColors.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Start button
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed:
                  _hasEnoughGuardians && !_isLoading ? _startRecovery : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child:
                  _isLoading
                      ? SizedBox(
                        width: 24.w,
                        height: 24.h,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        'Request Recovery Shares',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianInput(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Guardian ${index + 1}${index < 3 ? ' *' : ' (optional)'}',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: _guardianControllers[index],
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: 'npub1...',
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                Icons.paste,
                color: AppColors.textSecondary,
                size: 20.sp,
              ),
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) {
                  _guardianControllers[index].text = data!.text!.trim();
                  setState(() {});
                }
              },
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildConnectingPhase() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 24.h),
          Text(
            'Connecting to Nostr...',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestingPhase() {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.close, color: AppColors.textPrimary),
                onPressed: () {
                  _shareSubscription?.cancel();
                  Navigator.pop(context);
                },
              ),
              SizedBox(width: 8.w),
              Text(
                'Waiting for Shares',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          SizedBox(height: 32.h),

          // Progress
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              children: [
                Text(
                  '${_collectedShares.length}/3',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 48.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'shares received',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: LinearProgressIndicator(
                        value: _progressController.value.clamp(0.0, 1.0),
                        minHeight: 8.h,
                        backgroundColor: AppColors.background,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Guardian statuses
          Expanded(
            child: ListView.separated(
              itemCount: _guardianStatuses.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final status = _guardianStatuses[index];
                return _buildGuardianStatusCard(status);
              },
            ),
          ),

          // Help text
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.textSecondary,
                  size: 20.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Ask your guardians to open Sabi Wallet and check their Nostr DMs',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 12.h),

          // Manual share entry button
          TextButton.icon(
            onPressed: _showManualShareEntryDialog,
            icon: Icon(Icons.edit_note, color: AppColors.primary, size: 18.sp),
            label: Text(
              'Paste share manually (from Primal, etc.)',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianStatusCard(_GuardianStatus status) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    if (status.shareReceived) {
      statusColor = AppColors.accentGreen;
      statusIcon = Icons.check_circle;
      statusText = 'Share received';
    } else if (status.requestSent) {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
      statusText = 'Waiting for response...';
    } else if (status.error != null) {
      statusColor = AppColors.accentRed;
      statusIcon = Icons.error;
      statusText = status.error!;
    } else {
      statusColor = AppColors.textSecondary;
      statusIcon = Icons.pending;
      statusText = 'Pending';
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color:
              status.shareReceived
                  ? AppColors.accentGreen.withOpacity(0.5)
                  : Colors.transparent,
          width: 1.5.w,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                status.name[0],
                style: TextStyle(
                  color: statusColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.name,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${status.npub.substring(0, 12)}...${status.npub.substring(status.npub.length - 8)}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 16.sp),
              SizedBox(width: 4.w),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReconstructingPhase() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 24.h),
          Text(
            'Reconstructing Wallet...',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Combining shares to recover your seed',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessPhase() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              color: AppColors.accentGreen,
              size: 48.sp,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Wallet Recovered!',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Welcome back to Sabi Wallet',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedPhase() {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: AppColors.accentRed.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              color: AppColors.accentRed,
              size: 48.sp,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Recovery Failed',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            _errorMessage ?? 'An unknown error occurred',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _phase = RecoveryPhase.enterGuardians;
                  _errorMessage = null;
                  _collectedShares.clear();
                  _guardianStatuses.clear();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Try Again',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }
}

enum RecoveryPhase {
  enterGuardians,
  connecting,
  requestingShares,
  reconstructing,
  success,
  failed,
}

class _GuardianStatus {
  final String npub;
  final String name;
  bool requestSent = false;
  bool shareReceived = false;
  String? error;

  _GuardianStatus({
    required this.npub,
    required this.name,
  });
}
