import 'package:flutter/material.dart';
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

  final List<String> _quickAmounts = ['1,000', '5,000', '10,000', '50,000', '100,000'];

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
          builder: (context) => SendConfirmationScreen(transaction: transaction),
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
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Send to ${widget.recipient.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              widget.recipient.identifier,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _buildAmountDisplay(),
                    const SizedBox(height: 17),
                    _buildQuickAmounts(),
                    const SizedBox(height: 17),
                    _buildMemoField(),
                    const SizedBox(height: 24),
                    _buildConversionInfo(),
                    const SizedBox(height: 30),
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
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _amount,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 51,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '≈ 0 sats',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmounts() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _quickAmounts.map((amount) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _onQuickAmountPressed(amount),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '₦$amount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
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
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _memoController,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: const InputDecoration(
          hintText: 'Memo (optional)',
          hintStyle: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildConversionInfo() {
    return const Center(
      child: Column(
        children: [
          Text(
            '1 BTC = ₦162,400,000',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '~85 sats (~₦120) · Instant',
            style: TextStyle(
              color: AppColors.accentGreen,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        _buildNumpadRow(['1', '2', '3']),
        const SizedBox(height: 14),
        _buildNumpadRow(['4', '5', '6']),
        const SizedBox(height: 14),
        _buildNumpadRow(['7', '8', '9']),
        const SizedBox(height: 14),
        _buildNumpadRow(['.', '0', 'delete']),
      ],
    );
  }

  Widget _buildNumpadRow(List<String> numbers) {
    return Row(
      children: numbers.map((number) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildNumpadButton(number),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumpadButton(String value) {
    Widget child;
    
    if (value == 'delete') {
      child = const Icon(Icons.backspace_outlined, color: Colors.white, size: 24);
    } else {
      child = Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
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
          height: 66,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  Widget _buildContinueButton(bool enabled) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: enabled ? _continue : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled 
              ? AppColors.primary 
              : AppColors.primary.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Continue',
            style: TextStyle(
              color: AppColors.surface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
