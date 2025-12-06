import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/services/api_client.dart';
import 'package:sabi_wallet/core/constants/api_config.dart';
import 'package:sabi_wallet/features/wallet/domain/models/recipient.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/send_amount_screen.dart';
import 'package:sabi_wallet/features/wallet/presentation/widgets/recipient_avatar.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/features/wallet/domain/models/send_transaction.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/send_confirmation_screen.dart';
import 'package:sabi_wallet/services/contact_service.dart';
import 'qr_scanner_screen.dart';

class SendScreen extends StatefulWidget {
  final String? initialAddress;

  const SendScreen({super.key, this.initialAddress});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final TextEditingController _searchController = TextEditingController();
  Recipient? _selectedRecipient;
  List<ContactInfo> _phoneContacts = [];
  List<ContactInfo> _recentContactsList = [];
  bool _showContactsModal = false;
  bool _isLoadingContacts = false;

  @override
  void initState() {
    super.initState();
    // If initial address is provided, set it in the search field
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _searchController.text = widget.initialAddress!;
      // Auto-process the scanned code
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processAddress(widget.initialAddress!);
      });
    }
    _loadRecentContacts();
  }

  Future<void> _loadRecentContacts() async {
    try {
      final recent = await ContactService.getRecentContacts();
      setState(() {
        _recentContactsList = recent;
      });
    } catch (e) {
      debugPrint('❌ Error loading recent contacts: $e');
    }
  }

  Future<void> _importPhoneContacts() async {
    setState(() => _isLoadingContacts = true);
    try {
      final contacts = await ContactService.importPhoneContacts();
      setState(() {
        _phoneContacts = contacts;
        _isLoadingContacts = false;
      });
      _showContactsModal = true;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import contacts: $e'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
      setState(() => _isLoadingContacts = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectContact(ContactInfo contact) {
    // Convert phone contacts to Recipient
    final recipient = Recipient(
      name: contact.displayName,
      identifier: contact.identifier,
      type:
          contact.type == 'phone'
              ? RecipientType.phone
              : RecipientType.lightning,
    );

    setState(() {
      _selectedRecipient = recipient;
      _searchController.text = contact.identifier;
      _showContactsModal = false;
    });

    // Add to recent contacts
    ContactService.addRecentContact(contact);
  }

  void _continue() {
    if (_selectedRecipient != null) {
      // Add to recent contacts
      ContactService.addRecentContact(
        ContactInfo(
          displayName: _selectedRecipient!.name,
          identifier: _selectedRecipient!.identifier,
          type: _selectedRecipient!.type.toString().split('.').last,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => SendAmountScreen(recipient: _selectedRecipient!),
        ),
      );
    }
  }

  Future<void> _handlePaste() async {
    final clipData = await Clipboard.getData('text/plain');
    final text = clipData?.text?.trim();

    if (text == null || text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clipboard is empty'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
      return;
    }

    // Check if it's a lightning address (user@domain.com format)
    final isLightningAddress = text.contains('@') && text.contains('.');

    if (isLightningAddress) {
      // Lightning addresses REQUIRE amount - navigate to amount screen
      setState(() {
        _selectedRecipient = Recipient(
          name: text.split('@')[0], // username part
          identifier: text,
          type: RecipientType.lightning,
        );
        _searchController.text = text;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SendAmountScreen(recipient: _selectedRecipient!),
          ),
        );
      }
      return;
    }

    // Try to parse as bolt11 invoice (has amount encoded)
    setState(() => _searchController.text = 'Parsing...');

    try {
      final result = await BreezSparkService.sendPayment(text);
      final amountSats = BreezSparkService.extractSendAmountSats(result);
      final feeSats = BreezSparkService.extractSendFeeSats(result);
      final rate = await _fetchNgnPerSat();
      final amountNgn =
          rate != null ? amountSats * rate : amountSats.toDouble();
      final feeNgn = rate != null ? feeSats * rate : feeSats.toDouble();
      final memo = _extractMemo(result) ?? 'Lightning payment';

      if (!mounted) return;

      // Create transaction and navigate to confirmation
      final transaction = SendTransaction(
        recipient: Recipient(
          name: 'Lightning Payment',
          identifier: text.length > 30 ? '${text.substring(0, 30)}...' : text,
          type: RecipientType.lightning,
        ),
        amount: amountNgn,
        memo: memo,
        fee: feeNgn,
        transactionId: _extractTxId(result),
        amountSats: amountSats,
        feeSats: feeSats,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => SendConfirmationScreen(transaction: transaction),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchController.text = text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to parse: $e'),
          backgroundColor: AppColors.surface,
        ),
      );
    }
  }

  Future<void> _openQRScanner() async {
    try {
      final String? scannedCode = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const QRScannerScreen()),
      );

      if (scannedCode != null && scannedCode.isNotEmpty) {
        setState(() => _searchController.text = scannedCode);
        // Auto-process the scanned code
        _processAddress(scannedCode);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR Scanner error: $e'),
          backgroundColor: AppColors.surface,
        ),
      );
    }
  }

  Future<void> _processAddress(String text) async {
    // Check if it's a lightning address (user@domain.com format)
    final isLightningAddress = text.contains('@') && text.contains('.');

    if (isLightningAddress) {
      // Lightning addresses REQUIRE amount - navigate to amount screen
      setState(() {
        _selectedRecipient = Recipient(
          name: text.split('@')[0], // username part
          identifier: text,
          type: RecipientType.lightning,
        );
        _searchController.text = text;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SendAmountScreen(recipient: _selectedRecipient!),
          ),
        );
      }
      return;
    }

    // Try to parse as bolt11 invoice (has amount encoded)
    setState(() => _searchController.text = 'Parsing...');

    try {
      final result = await BreezSparkService.sendPayment(text);
      final amountSats = BreezSparkService.extractSendAmountSats(result);
      final feeSats = BreezSparkService.extractSendFeeSats(result);
      final rate = await _fetchNgnPerSat();
      final amountNgn =
          rate != null ? amountSats * rate : amountSats.toDouble();
      final feeNgn = rate != null ? feeSats * rate : feeSats.toDouble();
      final memo = _extractMemo(result) ?? 'Lightning payment';

      if (!mounted) return;

      // Create transaction and navigate to confirmation
      final transaction = SendTransaction(
        recipient: Recipient(
          name: 'Lightning Payment',
          identifier: text.length > 30 ? '${text.substring(0, 30)}...' : text,
          type: RecipientType.lightning,
        ),
        amount: amountNgn,
        memo: memo,
        fee: feeNgn,
        transactionId: _extractTxId(result),
        amountSats: amountSats,
        feeSats: feeSats,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => SendConfirmationScreen(transaction: transaction),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchController.text = text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to parse: $e'),
          backgroundColor: AppColors.surface,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedRecipient != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Who you want to send to?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        if (hasSelection) _buildSelectedRecipient(),
                        if (!hasSelection) _buildSearchField(),
                        const SizedBox(height: 17),
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                'Contacts',
                                Icons.people_outline,
                                onTap:
                                    _isLoadingContacts
                                        ? null
                                        : _importPhoneContacts,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                'Paste',
                                Icons.paste,
                                onTap: _handlePaste,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'Recent',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 17),
                        _buildRecentContacts(),
                      ],
                    ),
                  ),
                ),
                _buildContinueButton(hasSelection),
              ],
            ),
          ),
          if (_showContactsModal) _buildContactsModal(),
        ],
      ),
    );
  }

  Widget _buildSelectedRecipient() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          RecipientAvatar(initial: _selectedRecipient!.initial, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedRecipient!.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _selectedRecipient!.identifier,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '12 mutuals',
            style: TextStyle(color: AppColors.accentGreen, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Phone no./@sabi name./npub./LN address',
                hintStyle: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          GestureDetector(
            onTap: _openQRScanner,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.qr_code_scanner,
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentContacts() {
    final displayList =
        _recentContactsList.isNotEmpty
            ? _recentContactsList
            : _buildFallbackRecents();

    if (displayList.isEmpty) {
      return const Center(
        child: Text(
          'No recent contacts yet',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      );
    }

    return SizedBox(
      height: 124,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: displayList.length,
        itemBuilder: (context, index) {
          final contact = displayList[index];

          // Extract initial from name
          String getInitial(String name) {
            return name.isNotEmpty ? name[0].toUpperCase() : '?';
          }

          return GestureDetector(
            onTap: () => _selectContact(contact),
            child: Container(
              width: 96,
              margin: const EdgeInsets.only(right: 0),
              child: Column(
                children: [
                  RecipientAvatar(
                    initial: getInitial(contact.displayName),
                    size: 64,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    contact.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact.type,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<ContactInfo> _buildFallbackRecents() {
    return [
      ContactInfo(
        displayName: 'Auwal',
        identifier: '@sabi/chidi',
        type: 'sabi',
      ),
      ContactInfo(
        displayName: 'Blessing',
        identifier: '@sabi/blessing',
        type: 'sabi',
      ),
      ContactInfo(
        displayName: 'Tunde',
        identifier: '+234 803 456 7890',
        type: 'phone',
      ),
    ];
  }

  Widget _buildContactsModal() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showContactsModal = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping modal content
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Select Contact',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed:
                                  () => setState(
                                    () => _showContactsModal = false,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (_isLoadingContacts)
                        const Expanded(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      else if (_phoneContacts.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text(
                              'No contacts found',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: _phoneContacts.length,
                            itemBuilder: (context, index) {
                              final contact = _phoneContacts[index];
                              return GestureDetector(
                                onTap: () => _selectContact(contact),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: AppColors.primary,
                                        child: Text(
                                          contact.displayName[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.surface,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              contact.displayName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              contact.identifier,
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        contact.type,
                                        style: const TextStyle(
                                          color: AppColors.accentGreen,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
            backgroundColor:
                enabled
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

  Future<double?> _fetchNgnPerSat() async {
    try {
      final api = ApiClient();
      final rates = await api.get(ApiEndpoints.rates);
      final nairaToBtc = rates['naira_to_btc'];
      if (nairaToBtc != null) {
        final nairaPerBtc =
            nairaToBtc is num
                ? (1 / nairaToBtc)
                : (1 / double.parse(nairaToBtc.toString()));
        return nairaPerBtc / 100000000;
      }
    } catch (_) {}
    return null;
  }

  String? _extractMemo(dynamic response) {
    try {
      final payment = (response as dynamic).payment;
      return payment?.description as String?;
    } catch (_) {
      return null;
    }
  }

  String? _extractTxId(dynamic response) {
    try {
      final payment = (response as dynamic).payment;
      return payment?.paymentHash?.toString();
    } catch (_) {
      return null;
    }
  }
}
