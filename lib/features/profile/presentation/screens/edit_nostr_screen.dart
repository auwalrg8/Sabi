import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';

class EditNostrScreen extends StatefulWidget {
  final String? initialNpub;
  final String? initialNsec;
  const EditNostrScreen({Key? key, this.initialNpub, this.initialNsec})
    : super(key: key);

  @override
  State<EditNostrScreen> createState() => _EditNostrScreenState();
}

class _EditNostrScreenState extends State<EditNostrScreen> {
  final TextEditingController _npubController = TextEditingController();
  final TextEditingController _nsecController = TextEditingController();
  bool _showQR = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialNpub != null) _npubController.text = widget.initialNpub!;
    if (widget.initialNsec != null) _nsecController.text = widget.initialNsec!;
  }

  @override
  void dispose() {
    _npubController.dispose();
    _nsecController.dispose();
    super.dispose();
  }

  void _pasteNpub() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _npubController.text = data!.text!;
    }
  }

  void _pasteNsec() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _nsecController.text = data!.text!;
    }
  }

  void _toggleQR() {
    setState(() => _showQR = !_showQR);
  }

  void _save() {
    Navigator.of(context).pop({
      'npub': _npubController.text.trim(),
      'nsec': _nsecController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Nostr Keys'),
        actions: [
          IconButton(
            icon: Icon(_showQR ? Icons.qr_code_2 : Icons.qr_code),
            onPressed: _toggleQR,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _npubController,
              decoration: InputDecoration(
                labelText: 'Nostr Public Key (npub)',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: _pasteNpub,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _nsecController,
              decoration: InputDecoration(
                labelText: 'Nostr Private Key (nsec)',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: _pasteNsec,
                ),
              ),
              obscureText: true,
            ),
            SizedBox(height: 24.h),
            if (_showQR && _npubController.text.isNotEmpty)
              Center(
                child: QrImageView(
                  data: _npubController.text,
                  version: QrVersions.auto,
                  size: 180.sp,
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
