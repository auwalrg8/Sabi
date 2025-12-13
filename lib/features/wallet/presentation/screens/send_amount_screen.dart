import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/wallet/domain/models/recipient.dart';
import 'package:sabi_wallet/features/wallet/domain/models/send_transaction.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/send_confirmation_screen.dart';

class SendAmountScreen extends StatefulWidget {
  final Recipient recipient;

  const SendAmountScreen({super.key, required this.recipient});

  @override
  State<SendAmountScreen> createState() => _SendAmountScreenState();
}

class _SendAmountScreenState extends State<SendAmountScreen> {
  String _amount = '0';
  final TextEditingController _memoController = TextEditingController();

  final List<String> _quickAmounts = [
    '1,000',
    '5,000',
    '10,000',
    '50,000',
    '100,000',
  ];

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (_amount == '0') {
        _amount = number;
      } else {
        _amount += number;
      }
    });
  }

  void _onDecimalPressed() {
    if (!_amount.contains('.')) {
      setState(() {
        _amount += '.';
      });
    }
  }

  void _onDeletePressed() {
    if (_amount.isNotEmpty) {
      setState(() {
        _amount = _amount.substring(0, _amount.length - 1);
        if (_amount.isEmpty) {
          _amount = '0';
        }
      });
    }
  }

  void _onQuickAmountPressed(String amount) {
    setState(() {
      _amount = amount.replaceAll(',', '');
    });
  }

  void _continue() {
    final numAmount = double.tryParse(_amount.replaceAll(',', '')) ?? 0;
    if (numAmount > 0) {
      final transaction = SendTransaction(
        recipient: widget.recipient,
        amount: numAmount,
        memo: _memoController.text.isEmpty ? null : _memoController.text,
        fee: 120,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => SendConfirmationScreen(transaction: transaction),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAmount = _amount != '0';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 30.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        SizedBox(width: 10.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Send to ${widget.recipient.name}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 5.h),
                            Text(
                              widget.recipient.identifier,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 30.h),
                    _buildAmountDisplay(),
                    SizedBox(height: 17.h),
                    _buildQuickAmounts(),
                    SizedBox(height: 17.h),
                    _buildMemoField(),
                    SizedBox(height: 24.h),
                    _buildConversionInfo(),
                    SizedBox(height: 30.h),
                    _buildNumpad(),
                  ],
                ),
              ),
            ),
            _buildContinueButton(hasAmount),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountDisplay() {
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '₦',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 20),
              ),
              SizedBox(width: 10.w),
              Text(
                _amount,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 51.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '≈ 0 sats',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmounts() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            _quickAmounts.map((amount) {
              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: GestureDetector(
                  onTap: () => _onQuickAmountPressed(amount),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      '₦$amount',
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildMemoField() {
    return Container(
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: TextField(
        controller: _memoController,
        style: TextStyle(color: Colors.white, fontSize: 16.sp),
        decoration: InputDecoration(
          hintText: 'Memo (optional)',
          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 16.sp),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildConversionInfo() {
    return Center(
      child: Column(
        children: [
          Text(
            '1 BTC = ₦162,400,000',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10.sp),
          ),
          SizedBox(height: 4.h),
          Text(
            '~85 sats (~₦120) · Instant',
            style: TextStyle(color: AppColors.accentGreen, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      spacing: 14.h,
      children: [
        _buildNumpadRow(['1', '2', '3']),

        _buildNumpadRow(['4', '5', '6']),

        _buildNumpadRow(['7', '8', '9']),

        _buildNumpadRow(['.', '0', 'delete']),
      ],
    );
  }

  Widget _buildNumpadRow(List<String> numbers) {
    return Row(
      children:
          numbers.map((number) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: _buildNumpadButton(number),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildNumpadButton(String value) {
    Widget child;

    if (value == 'delete') {
      child = Icon(Icons.backspace_outlined, color: Colors.white, size: 24.sp);
    } else {
      child = Text(
        value,
        style: TextStyle(
          color: Colors.white,
          fontSize: 20.sp,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (value == 'delete') {
            _onDeletePressed();
          } else if (value == '.') {
            _onDecimalPressed();
          } else {
            _onNumberPressed(value);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 66.h,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  Widget _buildContinueButton(bool enabled) {
    return Container(
      padding: EdgeInsets.fromLTRB(30.w, 0, 30.w, 30.h),
      child: SizedBox(
        width: double.infinity,
        height: 52.h,
        child: ElevatedButton(
          onPressed: enabled ? _continue : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                enabled
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          child: Text(
            'Continue',
            style: TextStyle(
              color: AppColors.surface,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
