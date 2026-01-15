import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/features/recovery/services/social_recovery_service.dart';
import 'package:sabi_wallet/features/recovery/presentation/widgets/recovery_contact_picker.dart';
import 'social_recovery_success_screen.dart';

/// Screen for setting up social recovery with trusted contacts
class SocialRecoverySetupScreen extends StatefulWidget {
  final String masterSeed;

  const SocialRecoverySetupScreen({super.key, required this.masterSeed});

  @override
  State<SocialRecoverySetupScreen> createState() =>
      _SocialRecoverySetupScreenState();
}

class _SocialRecoverySetupScreenState extends State<SocialRecoverySetupScreen> {
  List<RecoveryContact> _selectedContacts = [];
  List<RecoveryContact> _availableContacts = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableContacts();
  }

  Future<void> _loadAvailableContacts() async {
    try {
      // In a real app, fetch from device contacts + Nostr follows
      // For now, use mock data
      setState(() {
        _availableContacts = [
          RecoveryContact(
            name: 'Alice',
            phoneNumber: '+234 801 234 5678',
            npub: 'npub1alice1234567890abcdefghijklmnopqrstuvwxyz',
            publicKey: 'alice_public_key_hex',
          ),
          RecoveryContact(
            name: 'Bob',
            phoneNumber: '+234 802 345 6789',
            npub: 'npub1bob1234567890abcdefghijklmnopqrstuvwxyz',
            publicKey: 'bob_public_key_hex',
          ),
          RecoveryContact(
            name: 'Charlie',
            phoneNumber: '+234 803 456 7890',
            npub: 'npub1charlie1234567890abcdefghijklmnopqrstuvwxyz',
            publicKey: 'charlie_public_key_hex',
          ),
          RecoveryContact(
            name: 'Diana',
            phoneNumber: '+234 804 567 8901',
            npub: 'npub1diana1234567890abcdefghijklmnopqrstuvwxyz',
            publicKey: 'diana_public_key_hex',
          ),
          RecoveryContact(
            name: 'Eve',
            phoneNumber: '+234 805 678 9012',
            npub: 'npub1eve1234567890abcdefghijklmnopqrstuvwxyz',
            publicKey: 'eve_public_key_hex',
          ),
        ];
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading contacts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendRecoveryShares() async {
    if (_selectedContacts.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 3 contacts'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await SocialRecoveryService.sendRecoveryShares(
        masterSeed: widget.masterSeed,
        selectedContacts: _selectedContacts,
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder:
                (_) => SocialRecoverySuccessScreen(contacts: _selectedContacts),
          ),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Social Recovery',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFFF7931A)),
                ),
              )
              : Column(
                children: [
                  Expanded(
                    child: RecoveryContactPicker(
                      availableContacts: _availableContacts,
                      onContactsSelected: (contacts) {
                        setState(() => _selectedContacts = contacts);
                      },
                    ),
                  ),
                  // Send button
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: ElevatedButton(
                        onPressed:
                            _isSending || _selectedContacts.length < 3
                                ? null
                                : _sendRecoveryShares,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF7931A),
                          disabledBackgroundColor: const Color(0xFFA1A1B2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child:
                            _isSending
                                ? SizedBox(
                                  height: 24.h,
                                  width: 24.h,
                                  child: const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation(
                                      Color(0xFF0C0C1A),
                                    ),
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text(
                                  'Send Recovery Shares',
                                  style: TextStyle(
                                    color: const Color(0xFF0C0C1A),
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
