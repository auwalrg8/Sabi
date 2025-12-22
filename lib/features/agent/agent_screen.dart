import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Agent / POS Mode screen for accepting payments
class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final TextEditingController _amountController = TextEditingController();
  String? _generatedQRData;
  bool _isQRGenerated = false;
  String _formattedAmount = '0';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    // Remove any non-digit characters
    String digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      setState(() {
        _formattedAmount = '0';
      });
      return;
    }

    // Format with thousand separators
    int amount = int.parse(digits);
    String formatted = _formatNumber(amount);

    setState(() {
      _formattedAmount = formatted;
    });
  }

  String _formatNumber(int number) {
    String numStr = number.toString();
    String result = '';
    int count = 0;

    for (int i = numStr.length - 1; i >= 0; i--) {
      count++;
      result = numStr[i] + result;
      if (count == 3 && i != 0) {
        result = ',$result';
        count = 0;
      }
    }

    return result;
  }

  void _generateQRCode() {
    String digits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty || digits == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid amount'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      );
      return;
    }

    int amount = int.parse(digits);

    // Generate Lightning invoice / payment request data
    // In production, this would be a real Lightning invoice
    String paymentData = 'lightning:lnbc${amount}n1p0example';

    setState(() {
      _generatedQRData = paymentData;
      _isQRGenerated = true;
    });
  }

  void _printReceipt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.print, color: Colors.white, size: 20.sp),
            SizedBox(width: 8.w),
            const Text('Receipt printing...'),
          ],
        ),
        backgroundColor: const Color(0xFFF7931A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  void _resetQR() {
    setState(() {
      _isQRGenerated = false;
      _generatedQRData = null;
      _amountController.clear();
      _formattedAmount = '0';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Agent / POS Mode',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accept Payments Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF111128),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accept Payments',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'Amount',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 14.sp,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    // Amount input field
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C0C1A),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: const Color(0xFF2A2A3E),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '₦',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(
                                  color: const Color(0xFFA1A1B2),
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              onChanged: _onAmountChanged,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    // Generate QR Code button
                    GestureDetector(
                      onTap: _isQRGenerated ? _resetQR : _generateQRCode,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7931A),
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF7931A).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _isQRGenerated ? 'New Payment' : 'Generate QR Code',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              // QR Code Display Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF111128),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(
                  children: [
                    // QR Code container with orange border
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: const Color(0xFFF7931A),
                          width: 3,
                        ),
                      ),
                      child:
                          _isQRGenerated && _generatedQRData != null
                              ? QrImageView(
                                data: _generatedQRData!,
                                version: QrVersions.auto,
                                size: 180.w,
                                backgroundColor: Colors.white,
                                errorCorrectionLevel: QrErrorCorrectLevel.H,
                              )
                              : SizedBox(
                                width: 180.w,
                                height: 180.h,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.qr_code_2,
                                      color: const Color(0xFFE0E0E0),
                                      size: 48.sp,
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      'Customer scans here\nto pay',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: const Color(0xFFA1A1B2),
                                        fontSize: 14.sp,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                    ),
                    SizedBox(height: 16.h),
                    // Amount display (when QR is generated)
                    if (_isQRGenerated) ...[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7931A).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '₦$_formattedAmount',
                          style: TextStyle(
                            color: const Color(0xFFF7931A),
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                    ],
                    Text(
                      _isQRGenerated
                          ? 'Show this QR code to your customer'
                          : 'Enter amount and generate QR code',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              // Print Receipt button
              GestureDetector(
                onTap: _isQRGenerated ? _printReceipt : null,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  decoration: BoxDecoration(
                    color:
                        _isQRGenerated
                            ? Colors.transparent
                            : const Color(0xFF111128),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color:
                          _isQRGenerated
                              ? const Color(0xFFF7931A)
                              : const Color(0xFF2A2A3E),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.print_outlined,
                        color:
                            _isQRGenerated
                                ? const Color(0xFFF7931A)
                                : const Color(0xFFA1A1B2),
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Print Receipt',
                        style: TextStyle(
                          color:
                              _isQRGenerated
                                  ? const Color(0xFFF7931A)
                                  : const Color(0xFFA1A1B2),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              // Quick amount presets
              if (!_isQRGenerated) ...[
                Text(
                  'Quick Amounts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12.h),
                Wrap(
                  spacing: 12.w,
                  runSpacing: 12.h,
                  children: [
                    _QuickAmountChip(
                      amount: 500,
                      onTap: () {
                        _amountController.text = '500';
                        _onAmountChanged('500');
                      },
                    ),
                    _QuickAmountChip(
                      amount: 1000,
                      onTap: () {
                        _amountController.text = '1000';
                        _onAmountChanged('1000');
                      },
                    ),
                    _QuickAmountChip(
                      amount: 2000,
                      onTap: () {
                        _amountController.text = '2000';
                        _onAmountChanged('2000');
                      },
                    ),
                    _QuickAmountChip(
                      amount: 5000,
                      onTap: () {
                        _amountController.text = '5000';
                        _onAmountChanged('5000');
                      },
                    ),
                    _QuickAmountChip(
                      amount: 10000,
                      onTap: () {
                        _amountController.text = '10000';
                        _onAmountChanged('10000');
                      },
                    ),
                    _QuickAmountChip(
                      amount: 20000,
                      onTap: () {
                        _amountController.text = '20000';
                        _onAmountChanged('20000');
                      },
                    ),
                  ],
                ),
              ],
              // Transaction status (when QR is generated)
              if (_isQRGenerated) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111128),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12.w,
                            height: 12.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7931A),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFF7931A,
                                  ).withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'Waiting for payment...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'The QR code will automatically update when payment is received',
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick amount preset chip
class _QuickAmountChip extends StatelessWidget {
  final int amount;
  final VoidCallback onTap;

  const _QuickAmountChip({required this.amount, required this.onTap});

  String _formatAmount(int amount) {
    if (amount >= 1000) {
      return '₦${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '₦$amount';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFF2A2A3E), width: 1),
        ),
        child: Text(
          _formatAmount(amount),
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
