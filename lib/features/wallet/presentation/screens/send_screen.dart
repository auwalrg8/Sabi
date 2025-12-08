import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/constants/api_config.dart';
import 'package:sabi_wallet/core/services/api_client.dart';
import 'package:sabi_wallet/features/wallet/domain/models/recipient.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/contact_service.dart';

enum _SendStep { recipient, amount, confirm }

enum _CurrencyMode { sats, ngn }

class SendScreen extends StatefulWidget {
  final String? initialAddress;

  const SendScreen({super.key, this.initialAddress});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

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
      final api = ApiClient();
      final rates = await api.get(ApiEndpoints.rates);
      final nairaToBtc = rates['naira_to_btc'];
      if (nairaToBtc != null) {
        final nairaPerBtc =
            nairaToBtc is num ? (1 / nairaToBtc) : (1 / double.parse('$nairaToBtc'));
        _ngnPerSat = nairaPerBtc / 100000000;
      }
    } catch (_) {
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
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.surface,
      ),
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
      _recipient = Recipient(
        name: input,
        identifier: input,
        type: type,
      );
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
        type: contact.type == 'phone'
            ? RecipientType.phone
            : RecipientType.lightning,
      );
      _recipientController.text = contact.identifier;
      _step = _SendStep.amount;
    });
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
      final amounts = _mode == _CurrencyMode.sats
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter 4-digit street PIN',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'PIN',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
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
                      borderRadius: BorderRadius.circular(12),
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
      await BreezSparkService.sendPayment(
        _recipient!.identifier,
        sats: sats,
        comment: _memoController.text,
      );
      if (!mounted) return;
      _showSnack('Payment sent');
      Navigator.pop(context);
    } catch (e) {
      _showSnack('Send failed: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _step == _SendStep.recipient
                        ? 'Send – Choose Recipient'
                        : _step == _SendStep.amount
                            ? 'Send – Enter Amount'
                            : 'Send – Confirm',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_isSending)
                    const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
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
    return SingleChildScrollView(
      key: const ValueKey('recipient'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _recipientController,
            decoration: InputDecoration(
              hintText: 'Paste phone, @handle, npub, LNURL, lightning address',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste, color: AppColors.textSecondary),
                onPressed: _onPaste,
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onSubmitted: _selectRecipientFromInput,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: [
              _pillButton('Paste', Icons.content_paste, _onPaste),
              _pillButton('Contacts', Icons.contacts, _importContacts),
              _pillButton('Recent', Icons.history, () {
                if (_recent.isEmpty) {
                  _showSnack('No recent recipients');
                  return;
                }
                _showRecentBottomSheet();
              }),
            ],
          ),
          const SizedBox(height: 20),
          if (_loadingContacts)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          if (_contacts.isNotEmpty) ...[
            const Text('Phone contacts', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            ..._contacts.take(5).map((c) => _contactTile(c)),
          ],
          if (_recent.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Recent', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            ..._recent.take(5).map((c) => _contactTile(c)),
          ],
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _selectRecipientFromInput(_recipientController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
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
            padding: const EdgeInsets.all(12),
            children: _recent.map(_contactTile).toList(),
          ),
        );
      },
    );
  }

  Widget _buildAmountStep() {
    final quickLabels = _mode == _CurrencyMode.sats
        ? ['1k', '5k', '10k', '50k']
        : ['₦1k', '₦5k', '₦10k', '₦50k'];

    final ngn = _amountNgn();
    final sats = _amountSats();

    return SingleChildScrollView(
      key: const ValueKey('amount'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _recipient?.name ?? 'Recipient',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              TextButton(
                onPressed: _toggleMode,
                child: Text(
                  _mode == _CurrencyMode.sats ? 'Switch to ₦' : 'Switch to sats',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                Text(
                  _mode == _CurrencyMode.sats ? 'sats' : '₦',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  _amountText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 46,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                    _mode == _CurrencyMode.sats
                      ? '≈ ₦${ngn.toStringAsFixed(0)}'
                      : '≈ $sats sats',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: quickLabels
                .asMap()
                .entries
                .map(
                  (e) => GestureDetector(
                    onTap: () => _setQuickAmount(e.key),
                    child: Chip(
                      label: Text(e.value),
                      backgroundColor: _quickIndex == e.key
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.surface,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _mode == _CurrencyMode.sats ? 'Amount (sats)' : 'Amount (₦)',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            onChanged: (v) => setState(() => _amountText = v.isEmpty ? '0' : v),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _memoController,
            decoration: InputDecoration(
              labelText: 'Memo (optional)',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _nextFromAmount,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow('To', _recipient?.name ?? ''),
          const SizedBox(height: 10),
          _summaryRow('Identifier', _recipient?.identifier ?? ''),
          const SizedBox(height: 10),
          _summaryRow('Amount', '$sats sats (₦${ngn.toStringAsFixed(0)})'),
          const SizedBox(height: 10),
          _summaryRow('Memo', _memoController.text.isEmpty ? '—' : _memoController.text),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _contactTile(ContactInfo c) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
        child: Text(
          c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(c.displayName, style: const TextStyle(color: Colors.white)),
      subtitle: Text(c.identifier, style: const TextStyle(color: AppColors.textSecondary)),
      onTap: () => _selectRecipient(c),
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
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ],
    );
  }
}
