import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/nostr/services/nostr_service.dart';

/// Bottom sheet modal for editing Nostr keys (npub/nsec)
class NostrEditModal extends StatefulWidget {
  final String? initialNpub;
  final VoidCallback onSaved;

  const NostrEditModal({super.key, this.initialNpub, required this.onSaved});

  @override
  State<NostrEditModal> createState() => _NostrEditModalState();
}

class _NostrEditModalState extends State<NostrEditModal> {
  final _npubController = TextEditingController();
  final _nsecController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialNpub != null) {
      _npubController.text = widget.initialNpub!;
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final npub = _npubController.text.trim();
      final nsec = _nsecController.text.trim();

      if (npub.isEmpty && nsec.isEmpty) {
        throw Exception('Please enter npub or nsec');
      }

      // If only npub is provided, validate it
      if (nsec.isEmpty && npub.isNotEmpty) {
        if (!_isValidNpub(npub)) {
          throw Exception('Invalid npub format');
        }
        // Just save the npub (read-only mode)
        await NostrService.importKeys(nsec: '', npub: npub);
      } else if (nsec.isNotEmpty) {
        // Validate nsec and derive npub
        if (!_isValidNsec(nsec)) {
          throw Exception('Invalid nsec format');
        }

        final derivedNpub = NostrService.getPublicKeyFromNsec(nsec);
        if (derivedNpub == null) {
          throw Exception('Could not derive public key from private key');
        }

        // If user provided both, verify they match
        if (npub.isNotEmpty && npub != derivedNpub) {
          throw Exception('nsec and npub do not match');
        }

        await NostrService.importKeys(nsec: nsec, npub: derivedNpub);
      }

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nostr keys saved successfully! ⚡',
              style: TextStyle(color: AppColors.surface),
            ),
            backgroundColor: Color(0xFF00FFB2),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
      print('❌ Error saving Nostr keys: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleQRScan() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QRScannerScreen()),
    );

    if (result != null && result.isNotEmpty) {
      // Parse QR result - could be npub, nsec, or nprofile
      if (result.startsWith('npub1')) {
        setState(() => _npubController.text = result);
      } else if (result.startsWith('nsec1')) {
        setState(() => _nsecController.text = result);
      } else if (result.startsWith('nostr:')) {
        // Handle nostr: protocol
        final content = result.replaceFirst('nostr:', '');
        if (content.startsWith('npub1')) {
          setState(() => _npubController.text = content);
        } else if (content.startsWith('nsec1')) {
          setState(() => _nsecController.text = content);
        }
      }
    }
  }

  bool _isValidNpub(String npub) {
    return npub.startsWith('npub1') && npub.length > 50;
  }

  bool _isValidNsec(String nsec) {
    return nsec.startsWith('nsec1') && nsec.length > 50;
  }

  @override
  Widget build(BuildContext context) {
    // Get keyboard height to add proper padding
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 20.h + bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nostr Keys',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // npub field
            Text(
              'Nostr Public Key (npub)',
              style: TextStyle(
                color: const Color(0xFFA1A1B2),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _npubController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              keyboardType: TextInputType.text,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: 'npub1...',
                hintStyle: const TextStyle(color: Color(0xFFA1A1B2)),
                filled: true,
                fillColor: const Color(0xFF111128),
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFA1A1B2)),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFA1A1B2)),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: Color(0xFFF7931A),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // nsec field
            Text(
              'Nostr Private Key (nsec)',
              style: TextStyle(
                color: const Color(0xFFA1A1B2),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _nsecController,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              keyboardType: TextInputType.text,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: 'nsec1... (keep this secret!)',
                hintStyle: const TextStyle(color: Color(0xFFA1A1B2)),
                filled: true,
                fillColor: const Color(0xFF111128),
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFA1A1B2)),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFA1A1B2)),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: Color(0xFFF7931A),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // QR Scanner button
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleQRScan,
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Scan QR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF7931A),
                      side: const BorderSide(color: Color(0xFFF7931A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Error message
            if (_error != null)
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red[300], fontSize: 12.sp),
                ),
              ),
            if (_error != null) SizedBox(height: 16.h),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7931A),
                  disabledBackgroundColor: const Color(0xFFA1A1B2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(
                              Color(0xFF0C0C1A),
                            ),
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          'Save Keys',
                          style: TextStyle(
                            color: const Color(0xFF0C0C1A),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _npubController.dispose();
    _nsecController.dispose();
    super.dispose();
  }
}

/// Simple QR scanner screen
class _QRScannerScreen extends StatefulWidget {
  const _QRScannerScreen();

  @override
  State<_QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<_QRScannerScreen> {
  late MobileScannerController controller;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C1A),
        title: const Text('Scan Nostr QR Code'),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0C0C1A),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final barcode = barcodes.first;
            if (barcode.rawValue != null) {
              Navigator.pop(context, barcode.rawValue);
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
