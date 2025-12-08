import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/profile_service.dart';

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  bool isStaticMode = false;
  int? selectedAmount;
  String selectedExpiry = '24 hours';
  bool isExpiryExpanded = false;
  final TextEditingController _descriptionController = TextEditingController();
  String? _bolt11;
  bool _creating = false;
  String? _bitcoinAddress;
  bool _loadingBitcoinAddress = false;
  String _selectedTab = 'lightning'; // 'lightning' or 'bitcoin'
  UserProfile? _userProfile;

  final List<int> presetAmounts = [1000, 5000, 10000, 50000, 100000];
  final List<String> expiryOptions = [
    '1 hour',
    '24 hours',
    '7 days',
    'Never expires',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await ProfileService.getProfile();
    if (mounted) {
      setState(() => _userProfile = profile);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    _buildQRCodeSection(),
                    const SizedBox(height: 30),
                    if (_selectedTab == 'lightning') ...[
                      _buildUserInfo(),
                      const SizedBox(height: 4),
                      _buildAmountSelector(),
                      const SizedBox(height: 30),
                      _buildExpiryAndDescription(),
                      const SizedBox(height: 30),
                    ],
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const Text(
                'Receive',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    isStaticMode = !isStaticMode;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isStaticMode ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTabSelector(),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 'lightning'),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color:
                      _selectedTab == 'lightning'
                          ? AppColors.primary
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '⚡ Lightning',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight:
                          _selectedTab == 'lightning'
                              ? FontWeight.w600
                              : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTab = 'bitcoin');
                if (_bitcoinAddress == null && !_loadingBitcoinAddress) {
                  _loadBitcoinAddress();
                }
              },
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color:
                      _selectedTab == 'bitcoin'
                          ? AppColors.primary
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '₿ Bitcoin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight:
                          _selectedTab == 'bitcoin'
                              ? FontWeight.w600
                              : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeSection() {
    final displayData = _selectedTab == 'lightning' ? _bolt11 : _bitcoinAddress;

    return Container(
      height: 310.h,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.primary, width: 8.w),
      ),
      child: Center(
        child:
            displayData != null
                ? Image.network(
                  'https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${Uri.encodeComponent(displayData)}',
                  width: 245.w,
                  height: 265.h,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 240,
                      height: 240,
                      color: Colors.grey[330],
                      child: const Center(
                        child: Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                )
                : _loadingBitcoinAddress && _selectedTab == 'bitcoin'
                ? const SizedBox(
                  width: 240,
                  height: 240,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
                : Container(
                  width: 240,
                  height: 240,
                  color: Colors.grey[330],
                  child: Center(
                    child: Text(
                      _selectedTab == 'lightning'
                          ? 'Create invoice to show QR'
                          : 'Loading...',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildUserInfo() {
    final username = _userProfile?.sabiUsername ?? '@sabi/user';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _copyToClipboard(username, 'Username'),
                child: Container(
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.copy, color: AppColors.primary, size: 18),
                ),
              ),
            ],
          ),
        ),
        // const SizedBox(height: 4),
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 112),
        //   child: Row(
        //     mainAxisAlignment: MainAxisAlignment.center,
        //     children: [
        //       const Text(
        //         'auwalrg@sabi.ng',
        //         style: TextStyle(
        //           color: AppColors.textSecondary,
        //           fontSize: 12,
        //           fontWeight: FontWeight.w400,
        //         ),
        //       ),
        //       const SizedBox(width: 8),
        //       GestureDetector(
        //         onTap: () => _copyToClipboard('auwalrg@sabi.ng', 'Email'),
        //         child: Container(
        //           width: 22,
        //           height: 22,
        //           padding: const EdgeInsets.all(4),
        //           child: Icon(
        //             Icons.copy,
        //             color: AppColors.textSecondary,
        //             size: 14,
        //           ),
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
      ],
    );
  }

  Widget _buildAmountSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: [
        Container(
          width: 120,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: Colors.transparent),
          ),
          child: TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: const InputDecoration(
              hintText: 'Custom',
              hintStyle: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (value) {
              final amount = int.tryParse(value.replaceAll(',', ''));
              setState(() {
                selectedAmount = amount;
              });
            },
          ),
        ),
        ...presetAmounts.map((amount) => _buildAmountButton(amount)),
      ],
    );
  }

  Widget _buildAmountButton(int amount) {
    final isSelected = selectedAmount == amount;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedAmount = isSelected ? null : amount;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          '₦ ${_formatAmount(amount)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)},${(amount % 1000).toString().padLeft(3, '0')}';
    }
    return amount.toString();
  }

  Widget _buildExpiryAndDescription() {
    return Column(
      children: [
        // Container(
        //   padding: const EdgeInsets.all(12),
        //   decoration: BoxDecoration(
        //     color: AppColors.surface,
        //     borderRadius: BorderRadius.circular(16),
        //   ),
        //   child: Column(
        //     children: [
        //       GestureDetector(
        //         onTap: () {
        //           setState(() {
        //             isExpiryExpanded = !isExpiryExpanded;
        //           });
        //         },
        //         child: Row(
        //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //           children: [
        //             const Text(
        //               'Set expiry',
        //               style: TextStyle(
        //                 color: Colors.white,
        //                 fontSize: 12,
        //                 fontWeight: FontWeight.w400,
        //               ),
        //             ),
        //             Text(
        //               selectedExpiry,
        //               style: const TextStyle(
        //                 color: AppColors.primary,
        //                 fontSize: 12,
        //                 fontWeight: FontWeight.w500,
        //               ),
        //             ),
        //           ],
        //         ),
        //       ),
        //       if (isExpiryExpanded) ...[
        //         const SizedBox(height: 12),
        //         ...expiryOptions.map((option) => _buildExpiryOption(option)),
        //       ],
        //     ],
        //   ),
        // ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.transparent),
            ),
            child: TextField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Describe the payment you want to receive',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Widget _buildExpiryOption(String option) {
  //   final isSelected = selectedExpiry == option;
  //   return Padding(
  //     padding: const EdgeInsets.only(bottom: 8),
  //     child: GestureDetector(
  //       onTap: () {
  //         setState(() {
  //           selectedExpiry = option;
  //           isExpiryExpanded = false;
  //         });
  //       },
  //       child: Container(
  //         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
  //         decoration: BoxDecoration(
  //           color: isSelected ? AppColors.primary : AppColors.background,
  //           borderRadius: BorderRadius.circular(8),
  //         ),
  //         child: Text(
  //           option,
  //           style: const TextStyle(
  //             color: Colors.white,
  //             fontSize: 12,
  //             fontWeight: FontWeight.w400,
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildActionButtons() {
    if (_selectedTab == 'bitcoin') {
      return Column(
        children: [
          if (_bitcoinAddress != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bitcoin Address',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _bitcoinAddress!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap:
                            () => _copyToClipboard(
                              _bitcoinAddress!,
                              'Bitcoin address',
                            ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.copy,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
                  _bitcoinAddress == null
                      ? null
                      : () =>
                          _copyToClipboard(_bitcoinAddress!, 'Bitcoin address'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Share Bitcoin Address',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      );
    }

    // Lightning tab
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed:
                _bolt11 == null
                    ? null
                    : () => _copyToClipboard(_bolt11!, 'Invoice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Share Invoice',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        if (selectedAmount != null) ...[
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _creating ? null : _createInvoice,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                backgroundColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _creating ? 'Creating…' : 'Create Invoice',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _loadBitcoinAddress() async {
    setState(() => _loadingBitcoinAddress = true);
    try {
      final address = await BreezSparkService.generateBitcoinAddress();
      if (!mounted) return;

      setState(() {
        _bitcoinAddress = address;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate Bitcoin address: $e'),
          backgroundColor: AppColors.surface,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingBitcoinAddress = false);
    }
  }

  Future<void> _createInvoice() async {
    if (selectedAmount == null) return;
    setState(() => _creating = true);
    try {
      final username = _userProfile?.sabiUsername ?? '@sabi/user';
      final result = await BreezSparkService.createInvoice(
        sats: selectedAmount!,
        memo:
            _descriptionController.text.isEmpty
                ? 'Payment to $username'
                : _descriptionController.text,
      );

      if (!mounted) return;

      setState(() {
        // Result is already the bolt11 string
        _bolt11 = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice created successfully'),
          backgroundColor: AppColors.surface,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create invoice: $e'),
          backgroundColor: AppColors.surface,
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}
