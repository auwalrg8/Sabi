/// Trade Code Widget - Split verification UI for buyer/seller
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../data/models/trade_code_model.dart';

/// Display the trade code for a user (buyer or seller view)
class TradeCodeDisplay extends StatelessWidget {
  final TradeCode tradeCode;
  final bool isBuyer;
  final VoidCallback? onCopy;

  const TradeCodeDisplay({
    super.key,
    required this.tradeCode,
    required this.isBuyer,
    this.onCopy,
  });

  String get _myPart => isBuyer ? tradeCode.buyerPart : tradeCode.sellerPart;
  String get _otherRole => isBuyer ? 'seller' : 'buyer';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF7931A).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: const Color(0xFFF7931A),
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'Trade Verification Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Code display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // My part (visible)
              _CodeDigits(
                digits: _myPart,
                isVisible: true,
                label: 'Your code',
              ),
              SizedBox(width: 12.w),
              Text(
                '+',
                style: TextStyle(
                  color: const Color(0xFFA1A1B2),
                  fontSize: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              // Other part (hidden)
              _CodeDigits(
                digits: '???',
                isVisible: false,
                label: '${_otherRole.substring(0, 1).toUpperCase()}${_otherRole.substring(1)}\'s code',
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Copy button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _myPart));
                onCopy?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Your code "$_myPart" copied!'),
                    backgroundColor: const Color(0xFF00FFB2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: Icon(Icons.copy, size: 16.sp),
              label: Text('Copy your code: $_myPart'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF7931A),
                side: const BorderSide(color: Color(0xFFF7931A)),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),

          // Instructions
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How it works:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                _InstructionStep(
                  number: '1',
                  text: 'Share your code ($_myPart) with the $_otherRole',
                ),
                _InstructionStep(
                  number: '2',
                  text: 'Ask the $_otherRole for their 3-digit code',
                ),
                _InstructionStep(
                  number: '3',
                  text: 'Combine both codes to verify the trade',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeDigits extends StatelessWidget {
  final String digits;
  final bool isVisible;
  final String label;

  const _CodeDigits({
    required this.digits,
    required this.isVisible,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: digits.split('').map((d) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 2.w),
              width: 36.w,
              height: 48.h,
              decoration: BoxDecoration(
                color: isVisible 
                    ? const Color(0xFFF7931A).withOpacity(0.15)
                    : const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: isVisible 
                      ? const Color(0xFFF7931A).withOpacity(0.5)
                      : const Color(0xFF3A3A4E),
                ),
              ),
              child: Center(
                child: Text(
                  d,
                  style: TextStyle(
                    color: isVisible ? const Color(0xFFF7931A) : const Color(0xFF6B6B80),
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 6.h),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFFA1A1B2),
            fontSize: 10.sp,
          ),
        ),
      ],
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionStep({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18.w,
            height: 18.w,
            decoration: BoxDecoration(
              color: const Color(0xFFF7931A).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: const Color(0xFFF7931A),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: const Color(0xFFA1A1B2),
                fontSize: 11.sp,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Input widget for entering the counterparty's code
class TradeCodeInput extends StatefulWidget {
  final String myCode;
  final bool isBuyer;
  final Function(String fullCode)? onVerify;
  final TradeCode? expectedCode;

  const TradeCodeInput({
    super.key,
    required this.myCode,
    required this.isBuyer,
    this.onVerify,
    this.expectedCode,
  });

  @override
  State<TradeCodeInput> createState() => _TradeCodeInputState();
}

class _TradeCodeInputState extends State<TradeCodeInput> {
  final List<TextEditingController> _controllers = List.generate(
    3,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(3, (_) => FocusNode());
  bool _isVerifying = false;
  bool? _isValid;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();
  String get _fullCode {
    final entered = _enteredCode;
    if (widget.isBuyer) {
      // Buyer has first 3, entered last 3
      return widget.myCode + entered;
    } else {
      // Seller has last 3, entered first 3
      return entered + widget.myCode;
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 2) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_enteredCode.length == 3) {
      _verifyCode();
    }
  }

  void _verifyCode() async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    await Future.delayed(const Duration(milliseconds: 500));

    final fullCode = _fullCode;
    final isValid = widget.expectedCode?.verifyFull(fullCode) ?? true;

    setState(() {
      _isVerifying = false;
      _isValid = isValid;
    });

    if (isValid) {
      widget.onVerify?.call(fullCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: _isValid == null
              ? const Color(0xFF2A2A3E)
              : _isValid!
                  ? const Color(0xFF00FFB2).withOpacity(0.5)
                  : const Color(0xFFFF6B6B).withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Enter ${widget.isBuyer ? "seller" : "buyer"}\'s code',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.h),

          // Code input
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // My code (display only)
              if (!widget.isBuyer) ...[
                _buildInputDigits(),
                SizedBox(width: 8.w),
                Text('+', style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 20.sp)),
                SizedBox(width: 8.w),
              ],
              
              // My code display
              ...widget.myCode.split('').map((d) => _buildCodeDigit(d, true)),

              if (widget.isBuyer) ...[
                SizedBox(width: 8.w),
                Text('+', style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 20.sp)),
                SizedBox(width: 8.w),
                _buildInputDigits(),
              ],
            ],
          ),
          SizedBox(height: 16.h),

          // Status
          if (_isVerifying)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFFF7931A)),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  'Verifying...',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            )
          else if (_isValid != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isValid! ? Icons.check_circle : Icons.error,
                  color: _isValid! ? const Color(0xFF00FFB2) : const Color(0xFFFF6B6B),
                  size: 18.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  _isValid! ? 'Code verified!' : 'Code mismatch - try again',
                  style: TextStyle(
                    color: _isValid! ? const Color(0xFF00FFB2) : const Color(0xFFFF6B6B),
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

  Widget _buildInputDigits() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 2.w),
          width: 40.w,
          height: 52.h,
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: const BorderSide(color: Color(0xFF3A3A4E)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: const BorderSide(color: Color(0xFF3A3A4E)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: const BorderSide(color: Color(0xFFF7931A)),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 12.h),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) => _onDigitChanged(index, v),
          ),
        );
      }),
    );
  }

  Widget _buildCodeDigit(String digit, bool isMine) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 2.w),
      width: 36.w,
      height: 48.h,
      decoration: BoxDecoration(
        color: const Color(0xFFF7931A).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFFF7931A).withOpacity(0.5)),
      ),
      child: Center(
        child: Text(
          digit,
          style: TextStyle(
            color: const Color(0xFFF7931A),
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Simple trade code badge for compact display
class TradeCodeBadge extends StatelessWidget {
  final bool hasTradeCode;
  final VoidCallback? onTap;

  const TradeCodeBadge({
    super.key,
    required this.hasTradeCode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasTradeCode) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF7931A).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user_outlined,
              color: const Color(0xFFF7931A),
              size: 12.sp,
            ),
            SizedBox(width: 4.w),
            Text(
              'Trade Code',
              style: TextStyle(
                color: const Color(0xFFF7931A),
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
