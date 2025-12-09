import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/wallet/domain/models/recipient.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/contact_service.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'package:sabi_wallet/l10n/app_localizations.dart';
import 'package:sabi_wallet/services/ln_address_service.dart';
import 'qr_scanner_screen.dart';

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

    setState(() {
      _recipient = Recipient(name: input, identifier: input, type: type);
      _step = _SendStep.amount;
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

  Future<void> _onPaste() async {
    final clip = await Clipboard.getData('text/plain');
    final text = clip?.text?.trim();
    if (text == null || text.isEmpty) {
      _showSnack('Clipboard is empty');
      return;
    }
    _recipientController.text = text;
    _selectRecipientFromInput(text);
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
      _showSnack('Payment sent • Fee: $feeSats sats');
      Navigator.pop(context);
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
                  color: Colors.white,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _recipient?.name ?? 'Recipient',
                style: TextStyle(color: Colors.white, fontSize: 16.sp),
              ),
              TextButton(
                onPressed: _toggleMode,
                child: Text(
                  _mode == _CurrencyMode.sats
                      ? 'Switch to ₦'
                      : 'Switch to sats',
                ),
              ),
            ],
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
                    fontSize: 46.sp,
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
          SizedBox(height: 18.h),
          Slider(
            value: _quickIndex.toDouble(),
            min: 0,
            max: 3,
            divisions: 3,
            label: quickLabels[_quickIndex],
            onChanged: (v) => _setQuickAmount(v.toInt()),
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surface,
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:
                quickLabels
                    .asMap()
                    .entries
                    .map(
                      (e) => GestureDetector(
                        onTap: () => _setQuickAmount(e.key),
                        child: Chip(
                          label: Text(e.value),
                          backgroundColor:
                              _quickIndex == e.key
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : AppColors.surface,
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
          ),
          SizedBox(height: 16.h),
          TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  _mode == _CurrencyMode.sats ? 'Amount (sats)' : 'Amount (₦)',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide.none,
              ),
            ),
            style: TextStyle(color: Colors.white, fontSize: 18.sp),
            onChanged: (v) => setState(() => _amountText = v.isEmpty ? '0' : v),
          ),
          SizedBox(height: 14.h),
          TextField(
            controller: _memoController,
            decoration: InputDecoration(
              labelText: 'Memo (optional)',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            height: 52.h,
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
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.sp, color: Colors.white),
            SizedBox(width: 6.h),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
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
