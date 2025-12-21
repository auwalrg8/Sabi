import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Zap slider widget for sending zaps
/// Predefined amounts: 21, 210, 1k, 10k, custom
class NostrZapSlider extends StatefulWidget {
  final Function(int satoshis) onZap;
  final VoidCallback onConfetti;
  final String? userName;

  const NostrZapSlider({
    Key? key,
    required this.onZap,
    required this.onConfetti,
    this.userName,
  }) : super(key: key);

  @override
  State<NostrZapSlider> createState() => _NostrZapSliderState();
}

class _NostrZapSliderState extends State<NostrZapSlider> {
  final List<Map<String, dynamic>> _zapAmounts = [
    {'label': '21', 'sats': 21},
    {'label': '210', 'sats': 210},
    {'label': '1k', 'sats': 1000},
    {'label': '10k', 'sats': 10000},
    {'label': 'Custom', 'sats': -1},
  ];

  int _selectedIndex = -1;
  bool _isLoading = false;

  void _handleZap(int satoshis) async {
    if (satoshis == -1) {
      // Show custom amount dialog
      _showCustomZapDialog();
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      widget.onZap(satoshis);
      widget.onConfetti();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zapped! ⚡ $satoshis sats'),
            backgroundColor: const Color(0x00FFB2),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send zap'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        setState(() => _selectedIndex = -1);
      }
    }
  }

  void _showCustomZapDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0x111128),
        title: const Text(
          'Custom Zap Amount',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter satoshis',
            hintStyle: const TextStyle(color: Color(0xFFA1A1B2)),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFFA1A1B2)),
              borderRadius: BorderRadius.circular(8.r),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFFF7931A)),
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFA1A1B2))),
          ),
          TextButton(
            onPressed: () {
              final amount = int.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context);
                _handleZap(amount);
              }
            },
            child: const Text('Zap', style: TextStyle(color: Color(0xFFF7931A))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.userName != null)
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Text(
                'Zap ${widget.userName}',
                style: TextStyle(
                  color: const Color(0xFFF7931A),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              _zapAmounts.length,
              (index) {
                final amount = _zapAmounts[index];
                final isSelected = _selectedIndex == index;
                
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: GestureDetector(
                      onTap: _isLoading ? null : () {
                        setState(() => _selectedIndex = index);
                        _handleZap(amount['sats']);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF7931A)
                              : const Color(0xFF0C0C1A),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFF7931A)
                                : const Color(0xFFA1A1B2),
                            width: 1.w,
                          ),
                        ),
                        child: _isLoading && isSelected
                            ? SizedBox(
                                height: 16.h,
                                width: 16.h,
                                child: const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(
                                    Color(0xFF0C0C1A),
                                  ),
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                amount['label'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF0C0C1A)
                                      : const Color(0xFFF7931A),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
