import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/widgets/widgets.dart';
import 'package:sabi_wallet/features/wallet/domain/models/recipient.dart';
import 'package:sabi_wallet/features/wallet/domain/models/send_transaction.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/contact_service.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'package:sabi_wallet/l10n/app_localizations.dart';
import 'package:sabi_wallet/services/ln_address_service.dart';
import 'qr_scanner_screen.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/payment_success_screen.dart';

class SendScreen extends StatefulWidget {
  final String? initialAddress;

  const SendScreen({super.key, this.initialAddress});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

enum _SendStep { recipient, amount, confirm }

enum _CurrencyMode { sats, ngn }

class _SendScreenState extends State<SendScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  _SendStep _step = _SendStep.recipient;
  _CurrencyMode _mode = _CurrencyMode.sats;

  Recipient? _recipient;
  bool _isSending = false;
  double? _ngnPerSat;

  String _amountText = '0';
  int _quickIndex = 0;

  List<ContactInfo> _recent = [];
  List<ContactInfo> _contacts = [];
  bool _loadingContacts = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _fetchRate();
    _loadRecent();
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _recipientController.text = widget.initialAddress!;
      _selectRecipientFromInput(widget.initialAddress!);
    }
  }

  Future<void> _fetchRate() async {
    try {
      final btcToNgn = await RateService.getBtcToNgnRate();
      _ngnPerSat = btcToNgn / 100000000;
    } catch (e) {
      debugPrint('Failed to fetch rate: $e');
      _ngnPerSat = null;
    }
  }

  Future<void> _loadRecent() async {
    try {
      final recent = await ContactService.getRecentContacts();
      if (mounted) setState(() => _recent = recent);
    } catch (_) {}
  }

  Future<void> _importContacts() async {
    setState(() => _loadingContacts = true);
    try {
      final list = await ContactService.importPhoneContacts();
      if (mounted) setState(() => _contacts = list);
    } catch (_) {
      _showSnack('Failed to import contacts');
    } finally {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _memoController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.surface),
    );
  }

  void _selectRecipientFromInput(String raw) {
    final input = raw.trim();
    if (input.isEmpty) {
      _showSnack('Enter a recipient');
      return;
    }

    RecipientType type;
    if (input.startsWith('npub')) {
      type = RecipientType.npub;
    } else if (input.contains('@') && input.contains('.')) {
      type = RecipientType.lnAddress;
    } else if (input.toLowerCase().startsWith('lnbc') ||
        input.toLowerCase().startsWith('bcrt') ||
        input.toLowerCase().startsWith('lntb')) {
      type = RecipientType.lightning;
    } else if (RegExp(r'^\+?\d{6,}$').hasMatch(input)) {
      type = RecipientType.phone;
    } else if (input.startsWith('@')) {
      type = RecipientType.sabiName;
    } else {
      type = RecipientType.lightning;
    }

    final parsedInvoiceSats = _parseBolt11AmountSats(input);
    setState(() {
      _recipient = Recipient(name: input, identifier: input, type: type);
      if (parsedInvoiceSats != null) {
        _mode = _CurrencyMode.sats;
        _amountText = parsedInvoiceSats.toString();
        _step = _SendStep.confirm;
      } else {
        _step = _SendStep.amount;
      }
    });
  }

  void _selectRecipient(ContactInfo contact) {
    setState(() {
      _recipient = Recipient(
        name: contact.displayName,
        identifier: contact.identifier,
        type: _recipientTypeFromString(contact.type),
      );
      _recipientController.text = contact.identifier;
      _step = _SendStep.amount;
    });
  }

  RecipientType _recipientTypeFromString(String type) {
    switch (type) {
      case 'phone':
        return RecipientType.phone;
      case 'npub':
        return RecipientType.npub;
      case 'lnAddress':
        return RecipientType.lnAddress;
      case 'sabi':
        return RecipientType.sabiName;
      default:
        return RecipientType.lightning;
    }
  }

  double _parsedAmount() {
    final cleaned = _amountText.replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  int? _parseBolt11AmountSats(String invoice) {
    final normalized = invoice.trim().toLowerCase();
    final match = RegExp(
      r'^ln(?:bc|tb|bcrt)(\d+)([munp]?)',
    ).firstMatch(normalized);
    if (match == null) return null;
    final digits = match.group(1);
    final unit = match.group(2);
    if (digits == null || digits.isEmpty) return null;
    final amountValue = double.tryParse(digits);
    if (amountValue == null || amountValue <= 0) return null;
    final sats =
        (amountValue * _bolt11UnitMultiplier(unit) * 100000000).round();
    return sats > 0 ? sats : null;
  }

  double _bolt11UnitMultiplier(String? unit) {
    switch (unit?.toLowerCase()) {
      case 'm':
        return 0.001;
      case 'u':
        return 0.000001;
      case 'n':
        return 0.000000001;
      case 'p':
        return 0.000000000001;
      default:
        return 1;
    }
  }

  int _amountSats() {
    final amt = _parsedAmount();
    if (_mode == _CurrencyMode.sats) return amt.round();
    if (_ngnPerSat == null) return 0;
    return (amt / _ngnPerSat!).round();
  }

  double _amountNgn() {
    final amt = _parsedAmount();
    if (_mode == _CurrencyMode.ngn) return amt;
    if (_ngnPerSat == null) return 0;
    return amt * _ngnPerSat!;
  }

  void _setQuickAmount(int value) {
    setState(() {
      _quickIndex = value;
      final amounts =
          _mode == _CurrencyMode.sats
              ? [1000, 5000, 10000, 50000]
              : [1000, 5000, 10000, 50000];
      _amountText = amounts[value].toString();
    });
  }

  void _appendDigit(String digit) {
    setState(() {
      if (digit == '.' && _amountText.contains('.')) return;
      if (_amountText == '0' && digit != '.') {
        _amountText = digit;
      } else {
        _amountText = '$_amountText$digit';
      }
      if (_amountText.startsWith('0') && !_amountText.startsWith('0.')) {
        _amountText = _amountText.replaceFirst(RegExp(r'^0+'), '');
        if (_amountText.isEmpty) _amountText = '0';
      }
    });
  }

  void _deleteDigit() {
    setState(() {
      if (_amountText.length <= 1) {
        _amountText = '0';
        return;
      }
      _amountText = _amountText.substring(0, _amountText.length - 1);
      if (_amountText.endsWith('.')) {
        _amountText = _amountText.substring(0, _amountText.length - 1);
      }
      if (_amountText.isEmpty) _amountText = '0';
    });
  }

  void _toggleMode() {
    setState(() {
      if (_mode == _CurrencyMode.sats) {
        final sats = _parsedAmount();
        if (_ngnPerSat != null) {
          _amountText = (sats * _ngnPerSat!).toStringAsFixed(0);
        }
        _mode = _CurrencyMode.ngn;
      } else {
        final ngn = _parsedAmount();
        if (_ngnPerSat != null) {
          _amountText = (ngn / _ngnPerSat!).toStringAsFixed(0);
        }
        _mode = _CurrencyMode.sats;
      }
    });
  }

  Future<void> _openQRScanner() async {
    try {
      final String? scannedCode = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const QRScannerScreen()),
      );

      if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
        _recipientController.text = scannedCode;
        _selectRecipientFromInput(scannedCode);
      }
    } catch (e) {
      _showSnack('QR Scanner error: $e');
    }
  }

  void _nextFromAmount() {
    if (_recipient == null) {
      _showSnack('Select a recipient first');
      return;
    }
    final sats = _amountSats();
    if (sats <= 0) {
      _showSnack('Enter an amount');
      return;
    }
    setState(() => _step = _SendStep.confirm);
  }

  Future<void> _confirmAndSend() async {
    final ngn = _amountNgn();
    if (ngn > 10000) {
      await _showPinSheet();
    } else {
      await _executeSend();
    }
  }

  Future<void> _showPinSheet() async {
    _pinController.clear();
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.all(20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter 4-digit street PIN',
                style: TextStyle(color: Colors.white, fontSize: 16.sp),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'PIN',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12.r)),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              SizedBox(height: 12.r),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_pinController.text.trim().length != 4) {
                      _showSnack('PIN must be 4 digits');
                      return;
                    }
                    Navigator.pop(context);
                    await _executeSend();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeSend() async {
    if (_recipient == null) {
      _showSnack('Select a recipient');
      return;
    }
    final sats = _amountSats();
    if (sats <= 0) {
      _showSnack('Enter an amount');
      return;
    }

    setState(() => _isSending = true);
    try {
      final paymentIdentifier = await _resolvePaymentIdentifier(
        _recipient!,
        sats,
      );
      final result = await BreezSparkService.sendPayment(
        paymentIdentifier,
        sats: sats,
        comment: _memoController.text,
        recipientName: _recipient?.name,
      );
      if (!mounted) return;
      final feeSats = BreezSparkService.extractSendFeeSats(result);
      final amountSats = BreezSparkService.extractSendAmountSats(result);
      final feeNgn = _ngnPerSat != null ? feeSats * _ngnPerSat! : 0.0;
      final amountNgn = _ngnPerSat != null ? _amountNgn() : 0.0;
      final transactionId = (result['payment'] as dynamic)?.id as String?;
      final transaction = SendTransaction(
        recipient: _recipient!,
        amount: amountNgn,
        memo: _memoController.text.isEmpty ? null : _memoController.text,
        fee: feeNgn,
        transactionId: transactionId,
        amountSats: amountSats,
        feeSats: feeSats,
        bolt11: _recipient?.identifier,
      );
      
      // Save to recent contacts after successful payment
      ContactService.addRecentContact(
        ContactInfo(
          displayName: _recipient!.name,
          identifier: _recipient!.identifier,
          type: _recipient!.type.name,
        ),
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(transaction: transaction),
        ),
      );
    } catch (e) {
      _showSnack('Send failed: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<String> _resolvePaymentIdentifier(
    Recipient recipient,
    int sats,
  ) async {
    if (recipient.type == RecipientType.lnAddress) {
      return await LnAddressService.fetchInvoice(
        lnAddress: recipient.identifier,
        sats: sats,
        memo: _memoController.text,
      );
    }
    return recipient.identifier;
  }

  int get _currentStepIndex {
    switch (_step) {
      case _SendStep.recipient:
        return 0;
      case _SendStep.amount:
        return 1;
      case _SendStep.confirm:
        return 2;
    }
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
      child: Column(
        children: [
          // Top row with back button and title
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (_step == _SendStep.recipient) {
                    Navigator.pop(context);
                  } else if (_step == _SendStep.amount) {
                    setState(() => _step = _SendStep.recipient);
                  } else {
                    setState(() => _step = _SendStep.amount);
                  }
                },
                child: Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.send,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_isSending)
                SizedBox(
                  height: 24.h,
                  width: 24.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.w,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          SizedBox(height: 20.h),
          // Step indicator
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: StepIndicator(
              currentStep: _currentStepIndex,
              totalSteps: 3,
              stepLabels: const ['To', 'Amount', 'Confirm'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _SendStep.recipient:
        return _buildRecipientStep();
      case _SendStep.amount:
        return _buildAmountStep();
      case _SendStep.confirm:
        return _buildConfirmStep();
    }
  }

  Widget _buildRecipientStep() {
    return Column(
      key: const ValueKey('recipient'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main input field with scan button
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _recipientController,
                    decoration: InputDecoration(
                      hintText: 'Phone, @handle, npub, or LN address',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14.sp,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 16.h,
                      ),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _openQRScanner();
                        },
                        child: Container(
                          margin: EdgeInsets.all(8.r),
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Icons.qr_code_scanner_rounded,
                            color: AppColors.primary,
                            size: 22.sp,
                          ),
                        ),
                      ),
                    ),
                    style: TextStyle(color: Colors.white, fontSize: 15.sp),
                    onSubmitted: _selectRecipientFromInput,
                  ),
                ),
                SizedBox(height: 16.h),
                // Action buttons row
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        'Contacts',
                        Icons.people_outline_rounded,
                        _importContacts,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _actionButton(
                        'Recent',
                        Icons.history_rounded,
                        () {
                          if (_recent.isEmpty) {
                            _showSnack('No recent recipients');
                            return;
                          }
                          _showRecentBottomSheet();
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                // Loading state
                if (_loadingContacts)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.h),
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.w,
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'Loading contacts...',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Contacts section
                if (_contacts.isNotEmpty) ...[
                  _sectionHeader('Contacts', Icons.people_rounded),
                  SizedBox(height: 12.h),
                  ..._contacts.take(5).map((c) => _contactTile(c)),
                ],
                // Recent section
                if (_recent.isNotEmpty) ...[
                  SizedBox(height: 20.h),
                  _sectionHeader('Recent', Icons.schedule_rounded),
                  SizedBox(height: 12.h),
                  ..._recent.take(5).map((c) => _contactTile(c)),
                ],
                // Empty state
                if (!_loadingContacts && _contacts.isEmpty && _recent.isEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 40.h),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.send_rounded,
                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                            size: 48.sp,
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'Enter a recipient or scan a QR code',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14.sp,
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
        // Continue button
        Container(
          padding: EdgeInsets.all(20.h),
          child: SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _selectRecipientFromInput(_recipientController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Text(
                'Continue',
                style: TextStyle(
                  color: AppColors.surface,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showRecentBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: ListView(
            padding: EdgeInsets.all(12.h),
            children: _recent.map(_contactTile).toList(),
          ),
        );
      },
    );
  }

  Widget _buildAmountStep() {
    final ngn = _amountNgn();
    final sats = _amountSats();

    return Column(
      key: const ValueKey('amount'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                // Recipient card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44.w,
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Center(
                          child: Text(
                            (_recipient?.name ?? 'R')[0].toUpperCase(),
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 18.sp,
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
                              'Sending to',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.sp,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              _recipient?.name ?? 'Recipient',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.check_circle,
                        color: AppColors.accentGreen,
                        size: 22.sp,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),
                // Amount display
                AmountDisplay(
                  amount: _amountText,
                  currency: _mode == _CurrencyMode.sats ? 'sats' : '₦',
                  secondaryAmount: _mode == _CurrencyMode.sats
                      ? ngn.toStringAsFixed(0)
                      : sats.toString(),
                  secondaryCurrency: _mode == _CurrencyMode.sats ? '₦' : '',
                  onToggleCurrency: _toggleMode,
                ),
                SizedBox(height: 24.h),
                // Quick amount chips
                AmountChips(
                  amounts: const [1000, 5000, 10000, 50000],
                  selectedAmount: _quickIndex >= 0 ? [1000, 5000, 10000, 50000][_quickIndex] : null,
                  currency: _mode == _CurrencyMode.sats ? '' : '₦',
                  onSelected: (amount) {
                    if (amount != null) {
                      final idx = [1000, 5000, 10000, 50000].indexOf(amount);
                      if (idx >= 0) _setQuickAmount(idx);
                    }
                  },
                ),
                SizedBox(height: 20.h),
                // Memo field
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: TextField(
                    controller: _memoController,
                    decoration: InputDecoration(
                      hintText: 'Add a note (optional)',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14.sp,
                      ),
                      prefixIcon: Icon(
                        Icons.note_alt_outlined,
                        color: AppColors.textSecondary,
                        size: 20.sp,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 16.h,
                      ),
                    ),
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  ),
                ),
                SizedBox(height: 20.h),
                // Keypad
                AmountKeypad(
                  onDigit: _appendDigit,
                  onDelete: _deleteDigit,
                ),
              ],
            ),
          ),
        ),
        // Continue button
        Container(
          padding: EdgeInsets.all(20.h),
          child: SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _nextFromAmount();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    final sats = _amountSats();
    final ngn = _amountNgn();

    return Column(
      key: const ValueKey('confirm'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                SizedBox(height: 12.h),
                // Amount highlight
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 28.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'You\'re sending',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14.sp,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        '$sats sats',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '≈ ₦${ngn.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                // Summary card
                SummaryCard(
                  title: 'TRANSACTION DETAILS',
                  items: [
                    SummaryItem(
                      label: 'Recipient',
                      value: _recipient?.name ?? '',
                      icon: Icons.person_outline_rounded,
                    ),
                    SummaryItem(
                      label: 'Address',
                      value: _recipient?.identifier ?? '',
                      icon: Icons.link_rounded,
                      isCopyable: true,
                    ),
                    if (_memoController.text.isNotEmpty)
                      SummaryItem(
                        label: 'Note',
                        value: _memoController.text,
                        icon: Icons.note_alt_outlined,
                      ),
                  ],
                ),
                SizedBox(height: 16.h),
                // Fee notice
                Container(
                  padding: EdgeInsets.all(14.r),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.textSecondary,
                        size: 18.sp,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'Network fees will be calculated at time of sending',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Send button
        Container(
          padding: EdgeInsets.all(20.h),
          child: SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: _isSending
                  ? null
                  : () {
                      HapticFeedback.heavyImpact();
                      _confirmAndSend();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: _isSending
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.w,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          'Sending...',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: 20.sp),
                        SizedBox(width: 8.w),
                        Text(
                          'Send Payment',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.sp, color: AppColors.primary),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: AppColors.textSecondary),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _contactTile(ContactInfo c) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _selectRecipient(c);
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
          margin: EdgeInsets.only(bottom: 4.h),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.3),
                      AppColors.primary.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Text(
                    c.displayName.isNotEmpty
                        ? c.displayName[0].toUpperCase()
                        : 'C',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 18.sp,
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
                      c.displayName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      c.identifier,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textSecondary,
                size: 16.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
