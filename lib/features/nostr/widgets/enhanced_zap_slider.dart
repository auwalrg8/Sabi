import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:sabi_wallet/features/nostr/providers/nostr_providers.dart';

/// Enhanced Zap slider widget using ZapService
/// Features:
/// - 21 sats as default (first tap = instant 21 sats zap)
/// - Presets: 21, 210, 1k, 10k
/// - Custom amount with validation
/// - Balance checking with proper error handling
/// - Confetti animation on success
class EnhancedZapSlider extends ConsumerStatefulWidget {
  final String recipientPubkey;
  final String? eventId;
  final String? recipientName;
  final VoidCallback? onSuccess;
  final Function(String)? onError;

  const EnhancedZapSlider({
    super.key,
    required this.recipientPubkey,
    this.eventId,
    this.recipientName,
    this.onSuccess,
    this.onError,
  });

  @override
  ConsumerState<EnhancedZapSlider> createState() => _EnhancedZapSliderState();
}

class _EnhancedZapSliderState extends ConsumerState<EnhancedZapSlider>
    with SingleTickerProviderStateMixin {
  // Zap presets from ZapService
  final List<Map<String, dynamic>> _zapAmounts = [
    {'label': '⚡21', 'sats': 21, 'isDefault': true},
    {'label': '210', 'sats': 210, 'isDefault': false},
    {'label': '1k', 'sats': 1000, 'isDefault': false},
    {'label': '10k', 'sats': 10000, 'isDefault': false},
    {'label': '···', 'sats': -1, 'isDefault': false}, // Custom
  ];

  int _selectedIndex = -1;
  bool _isZapping = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleZap(int satoshis) async {
    if (satoshis == -1) {
      _showCustomZapDialog();
      return;
    }

    setState(() => _isZapping = true);

    try {
      final zapNotifier = ref.read(zapNotifierProvider.notifier);

      final result = await zapNotifier.sendZap(
        recipientPubkey: widget.recipientPubkey,
        amountSats: satoshis,
        comment: 'Zapped from Sabi Wallet ⚡',
        eventId: widget.eventId,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        // Fire confetti!
        Confetti.launch(
          context,
          options: ConfettiOptions(
            particleCount: satoshis > 1000 ? 100 : 50,
            spread: 360,
            y: 0.5,
            colors: const [
              Color(0xFFF7931A), // Orange
              Color(0xFF00FFB2), // Mint
              Colors.yellow,
            ],
          ),
        );

        widget.onSuccess?.call();

        _showSuccessSnackBar(satoshis);
      } else if (result.isInsufficientBalance) {
        _showErrorSnackBar('Insufficient balance for $satoshis sats');
        widget.onError?.call('Insufficient balance');
      } else if (result.isNoLightningAddress) {
        _showWarningSnackBar(
          '${widget.recipientName ?? 'User'} has no Lightning address',
        );
        widget.onError?.call('No Lightning address');
      } else {
        _showErrorSnackBar(result.message ?? 'Zap failed');
        widget.onError?.call(result.message ?? 'Zap failed');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
        widget.onError?.call(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isZapping = false;
          _selectedIndex = -1;
        });
      }
    }
  }

  void _showSuccessSnackBar(int sats) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('⚡', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              'Zapped $sats sats to ${widget.recipientName ?? 'user'}!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF7931A),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFFF4D4F),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEAB308),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showCustomZapDialog() {
    final controller = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF111128),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 24)),
                SizedBox(width: 8.w),
                const Text(
                  'Custom Zap',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 24.sp,
                    ),
                    suffix: Text(
                      'sats',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 14.sp,
                      ),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: const Color(0xFFA1A1B2),
                        width: 2.w,
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: const Color(0xFFF7931A),
                        width: 2.w,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                // Quick amount buttons
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children:
                      [100, 500, 2100, 5000, 21000].map((sats) {
                        return InkWell(
                          onTap: () => controller.text = sats.toString(),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFA1A1B2),
                              ),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              sats >= 1000
                                  ? '${sats ~/ 1000}k'
                                  : sats.toString(),
                              style: TextStyle(
                                color: const Color(0xFFF7931A),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 14.sp,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = int.tryParse(controller.text);
                  if (amount != null && amount > 0) {
                    Navigator.pop(context);
                    _handleZap(amount);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7931A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'Zap ⚡',
                  style: TextStyle(
                    color: const Color(0xFF0C0C1A),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zapState = ref.watch(zapNotifierProvider);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFF7931A).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          if (widget.recipientName != null)
            Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6.w),
                  Text(
                    'Zap ${widget.recipientName}',
                    style: TextStyle(
                      color: const Color(0xFFF7931A),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Zap buttons
          Row(
            children: List.generate(_zapAmounts.length, (index) {
              final amount = _zapAmounts[index];
              final isSelected = _selectedIndex == index;
              final isDefault = amount['isDefault'] == true;
              final isLoading = _isZapping && isSelected;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3.w),
                  child: GestureDetector(
                    onTap:
                        (_isZapping || zapState.isLoading)
                            ? null
                            : () {
                              setState(() => _selectedIndex = index);
                              _handleZap(amount['sats']);
                            },
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale =
                            isDefault && !_isZapping
                                ? 1.0 + (_pulseController.value * 0.05)
                                : 1.0;

                        return Transform.scale(
                          scale: scale,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? const Color(0xFFF7931A)
                                      : isDefault
                                      ? const Color(
                                        0xFFF7931A,
                                      ).withOpacity(0.15)
                                      : const Color(0xFF0C0C1A),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color:
                                    isSelected || isDefault
                                        ? const Color(0xFFF7931A)
                                        : const Color(0xFF2A2A3E),
                                width: isDefault ? 2 : 1,
                              ),
                              boxShadow:
                                  isDefault && !_isZapping
                                      ? [
                                        BoxShadow(
                                          color: const Color(
                                            0xFFF7931A,
                                          ).withOpacity(
                                            0.3 * _pulseController.value,
                                          ),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                      : null,
                            ),
                            child:
                                isLoading
                                    ? SizedBox(
                                      height: 16.h,
                                      width: 16.h,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          isSelected
                                              ? const Color(0xFF0C0C1A)
                                              : const Color(0xFFF7931A),
                                        ),
                                      ),
                                    )
                                    : Text(
                                      amount['label'],
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:
                                            isSelected
                                                ? const Color(0xFF0C0C1A)
                                                : const Color(0xFFF7931A),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Compact inline zap button for use in post cards
class InlineZapButton extends ConsumerWidget {
  final String recipientPubkey;
  final String? eventId;
  final String? recipientName;
  final int currentZapAmount;

  const InlineZapButton({
    super.key,
    required this.recipientPubkey,
    this.eventId,
    this.recipientName,
    this.currentZapAmount = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showZapSheet(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF7931A).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: const Color(0xFFF7931A).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 14)),
            if (currentZapAmount > 0) ...[
              SizedBox(width: 4.w),
              Text(
                _formatSats(currentZapAmount),
                style: TextStyle(
                  color: const Color(0xFFF7931A),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showZapSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0C1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFA1A1B2),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 20.h),
                EnhancedZapSlider(
                  recipientPubkey: recipientPubkey,
                  eventId: eventId,
                  recipientName: recipientName,
                  onSuccess: () => Navigator.pop(context),
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
    );
  }

  String _formatSats(int sats) {
    if (sats >= 1000000) {
      return '${(sats / 1000000).toStringAsFixed(1)}M';
    } else if (sats >= 1000) {
      return '${(sats / 1000).toStringAsFixed(sats % 1000 == 0 ? 0 : 1)}k';
    }
    return sats.toString();
  }
}
