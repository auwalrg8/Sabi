import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import '../providers/cash_provider.dart';
import 'review_sale_screen.dart';

class AddBankAccountScreen extends ConsumerStatefulWidget {
  const AddBankAccountScreen({super.key});

  @override
  ConsumerState<AddBankAccountScreen> createState() =>
      _AddBankAccountScreenState();
}

class _AddBankAccountScreenState extends ConsumerState<AddBankAccountScreen> {
  final _accountNumberController = TextEditingController();
  String? _selectedBank;
  bool _isVerifying = false;
  bool _isVerified = false;
  String? _accountName;

  final List<String> _banks = [
    'Access Bank',
    'GTBank',
    'First Bank',
    'UBA',
    'Zenith Bank',
    'Kuda Bank',
  ];

  @override
  void dispose() {
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _verifyAccount() async {
    if (_selectedBank == null || _accountNumberController.text.length != 10) {
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isVerifying = false;
      _isVerified = true;
      _accountName = 'Auwal Abubakar';
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _isVerified && _selectedBank != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 30.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 24.w,
                      height: 24.h,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Bank Account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          'Where you want to collect your Naira?',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 30.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Bank name',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      height: 52.h,
                      padding: EdgeInsets.symmetric(horizontal: 17.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2942),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFF374151)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedBank,
                          hint: Text(
                            'Select your bank',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                            ),
                          ),
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1A2942),
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 16.sp,
                          ),
                          items:
                              _banks.map((bank) {
                                return DropdownMenuItem<String>(
                                  value: bank,
                                  child: Text(
                                    bank,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.sp,
                                    ),
                                  ),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBank = value;
                              _isVerified = false;
                              _accountName = null;
                            });
                            if (_accountNumberController.text.length == 10) {
                              _verifyAccount();
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 17.h),
                    Text(
                      'Account number',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      height: 52.h,
                      padding: EdgeInsets.symmetric(horizontal: 17.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2942),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFF374151)),
                      ),
                      child: TextField(
                        controller: _accountNumberController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: Color(0xFFCCCCCC),
                          fontSize: 18.sp,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '',
                        ),
                        onChanged: (value) {
                          if (value.length == 10 && _selectedBank != null) {
                            _verifyAccount();
                          } else {
                            setState(() {
                              _isVerified = false;
                              _accountName = null;
                            });
                          }
                        },
                      ),
                    ),
                    SizedBox(height: 17.h),
                    if (_isVerifying)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 16.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'Verifying account...',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12.sp,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_isVerified && _accountName != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 17.w,
                          vertical: 17.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x1A111128),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: AppColors.accentGreen),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Name',
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 10.sp,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                _accountName!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(31.w, 0, 31.w, 30.h),
              child: SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed:
                      canSave
                          ? () {
                            ref
                                .read(cashProvider.notifier)
                                .setBankAccount(
                                  bankName: _selectedBank!,
                                  accountNumber: _accountNumberController.text,
                                  accountName: _accountName!,
                                );
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ReviewSaleScreen(),
                              ),
                            );
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canSave
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Save This Bank',
                    style: TextStyle(
                      color: AppColors.surface,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
