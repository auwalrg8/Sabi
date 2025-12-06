import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              padding: const EdgeInsets.all(30),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Bank Account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Where you want to collect your Naira?',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
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
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Bank name',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 17),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2942),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF374151)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedBank,
                          hint: const Text(
                            'Select your bank',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1A2942),
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 16,
                          ),
                          items: _banks.map((bank) {
                            return DropdownMenuItem<String>(
                              value: bank,
                              child: Text(
                                bank,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
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
                    const SizedBox(height: 17),
                    const Text(
                      'Account number',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 17),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2942),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF374151)),
                      ),
                      child: TextField(
                        controller: _accountNumberController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Color(0xFFCCCCCC),
                          fontSize: 18,
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
                    const SizedBox(height: 17),
                    if (_isVerifying)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Verifying account...',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_isVerified && _accountName != null)
                      Container(
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(
                          color: const Color(0x1A111128),
                          borderRadius: BorderRadius.circular(20),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Account Name',
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _accountName!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
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
              padding: const EdgeInsets.fromLTRB(31, 0, 31, 30),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: canSave
                      ? () {
                          ref.read(cashProvider.notifier).setBankAccount(
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
                    backgroundColor: canSave
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save This Bank',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
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
