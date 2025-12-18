import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
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

    ContactService.addRecentContact(
      ContactInfo(displayName: input, identifier: input, type: type.name),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 25.sp,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    _step == _SendStep.recipient
                        ? '${AppLocalizations.of(context)!.send} – ${AppLocalizations.of(context)!.chooseRecipient}'
                        : _step == _SendStep.amount
                        ? '${AppLocalizations.of(context)!.send} – ${AppLocalizations.of(context)!.enterAmount}'
                        : '${AppLocalizations.of(context)!.send} – ${AppLocalizations.of(context)!.confirm}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_isSending)
                    SizedBox(
                      height: 22.h,
                      width: 22.w,
                      child: CircularProgressIndicator(strokeWidth: 2.w),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildStep(),
              ),
            ),
          ],
        ),
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
            padding: EdgeInsets.all(20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _recipientController,
                  decoration: InputDecoration(
                    hintText: 'Paste phone, @handle, npub, LN address',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.sp,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: _openQRScanner,
                    ),
                  ),
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  onSubmitted: _selectRecipientFromInput,
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: _outlinedButton(
                        'Contacts',
                        Icons.contacts,
                        _importContacts,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _outlinedButton('Recent', Icons.history, () {
                        if (_recent.isEmpty) {
                          _showSnack('No recent recipients');
                          return;
                        }
                        _showRecentBottomSheet();
                      }),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                if (_loadingContacts)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(12.h),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                if (_contacts.isNotEmpty) ...[
                  Text(
                    'Contacts',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  ..._contacts.take(5).map((c) => _contactTile(c)),
                ],
                if (_recent.isNotEmpty) ...[
                  SizedBox(height: 20.h),
                  Text(
                    'Recent',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  ..._recent.take(5).map((c) => _contactTile(c)),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(20.h),
          child: SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed:
                  () => _selectRecipientFromInput(_recipientController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
    final quickLabels =
        _mode == _CurrencyMode.sats
            ? ['1k', '5k', '10k', '50k']
            : ['₦1k', '₦5k', '₦10k', '₦50k'];

    final ngn = _amountNgn();
    final sats = _amountSats();

    return SingleChildScrollView(
      key: const ValueKey('amount'),
      padding: EdgeInsets.all(22.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _recipient?.name ?? 'Recipient',
            style: TextStyle(color: Colors.white, fontSize: 16.sp),
          ),
          SizedBox(height: 12.h),
          Center(
            child: Column(
              children: [
                Text(
                  _mode == _CurrencyMode.sats ? 'sats' : '₦',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 18.sp,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  _amountText,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 56.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  _mode == _CurrencyMode.sats
                      ? '≈ ₦${ngn.toStringAsFixed(0)}'
                      : '≈ $sats sats',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:
                quickLabels
                    .asMap()
                    .entries
                    .map(
                      (e) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: GestureDetector(
                            onTap: () => _setQuickAmount(e.key),
                            child: Container(
                              height: 42.h,
                              decoration: BoxDecoration(
                                color:
                                    _quickIndex == e.key
                                        ? AppColors.primary
                                        : AppColors.surface,
                                borderRadius: BorderRadius.circular(32.r),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                e.value,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          SizedBox(height: 18.h),
          TextField(
            controller: _memoController,
            decoration: InputDecoration(
              hintText: 'Memo (optional)',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          SizedBox(height: 12.h),
          TextButton(
            onPressed: _toggleMode,
            child: Text(
              _mode == _CurrencyMode.sats
                  ? 'Switch to naira'
                  : 'Switch to sats',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          SizedBox(height: 12.h),
          _buildKeypad(),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: _nextFromAmount,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep() {
    final sats = _amountSats();
    final ngn = _amountNgn();

    return SingleChildScrollView(
      key: const ValueKey('confirm'),
      padding: EdgeInsets.all(20.h),
      child: Column(
        spacing: 10.h,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow('To', _recipient?.name ?? ''),

          _summaryRow('Identifier', _recipient?.identifier ?? ''),

          _summaryRow('Amount', '$sats sats (₦${ngn.toStringAsFixed(0)})'),

          _summaryRow(
            'Memo',
            _memoController.text.isEmpty ? '—' : _memoController.text,
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: _isSending ? null : _confirmAndSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _isSending ? 'Sending…' : 'Send',
                style: TextStyle(color: Colors.white, fontSize: 16.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlinedButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 1.5.w),
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.sp, color: AppColors.primary),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', '⌫'],
    ];

    return Column(
      children:
          rows
              .map(
                (row) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children:
                        row
                            .map(
                              (value) => Expanded(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6.w,
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (value == '⌫') {
                                        _deleteDigit();
                                        return;
                                      }
                                      _appendDigit(value);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 18.h,
                                      ),
                                      backgroundColor: AppColors.surface,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        side: const BorderSide(
                                          color: Colors.transparent,
                                        ),
                                      ),
                                    ),
                                    child:
                                        value == '⌫'
                                            ? Icon(
                                              Icons.backspace,
                                              color: Colors.white,
                                            )
                                            : Text(
                                              value,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 24.sp,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _contactTile(ContactInfo c) {
    return InkWell(
      onTap: () => _selectRecipient(c),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  c.displayName.isNotEmpty
                      ? c.displayName[0].toUpperCase()
                      : 'C',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    c.identifier,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.sp,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white, fontSize: 15.sp),
          ),
        ),
      ],
    );
  }
}
