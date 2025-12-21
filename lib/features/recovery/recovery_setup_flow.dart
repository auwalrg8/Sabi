import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/features/recovery/contact_picker_screen.dart';
import 'package:sabi_wallet/features/recovery/nostr_invite_service.dart';
import 'package:sabi_wallet/features/recovery/social_recovery_service.dart';
import 'package:sabi_wallet/features/recovery/social_recovery_success_screen.dart';

/// Recovery setup flow orchestrator
/// - Shows contact picker
/// - Splits seed into shares
/// - Encrypts and distributes shares
/// - Shows success screen
class RecoverySetupFlow extends ConsumerStatefulWidget {
  final String masterSeed;

  const RecoverySetupFlow({
    required this.masterSeed,
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<RecoverySetupFlow> createState() => _RecoverySetupFlowState();
}

class _RecoverySetupFlowState extends ConsumerState<RecoverySetupFlow> {
  List<ContactWithStatus>? _selectedContacts;
  bool _isSending = false;

  Future<void> _startSetup() async {
    // Open contact picker
    final selected = await Navigator.push<List<ContactWithStatus>>(
      context,
      MaterialPageRoute(
        builder: (context) => ContactPickerScreen(
          onContactsSelected: (contacts) {
            setState(() => _selectedContacts = contacts);
          },
        ),
      ),
    );

    if (selected != null && selected.length >= 3) {
      _setupRecovery(selected);
    }
  }

  Future<void> _setupRecovery(List<ContactWithStatus> contacts) async {
    try {
      setState(() => _isSending = true);

      // Convert ContactWithStatus to RecoveryContact
      final recoveryContacts = contacts.map((contact) {
        return RecoveryContact(
          name: contact.name,
          phoneNumber: contact.phoneNumber,
          npub: contact.npub ?? _generateDummyNpub(contact.name),
          publicKey: contact.tempPublicKey ?? _generateDummyPublicKey(contact.name),
        );
      }).toList();

      // 1. For each selected contact, share invite links if needed
      for (final contact in contacts) {
        if (!contact.isOnNostr) {
          // Generate temporary keypair for phone contact
          final tempKeypair = await NostrInviteService.generateTemporaryKeypair();
          
          // Create and share invite link
          final inviteLink = await NostrInviteService.createInviteLink(
            contactName: contact.name,
            phoneNumber: contact.phoneNumber,
            tempNpub: tempKeypair['npub']!,
          );
          
          // Share via WhatsApp or SMS
          _shareInviteLink(contact, inviteLink, tempKeypair['npub']!);
        }
      }

      // 2. Send encrypted shares via Nostr DM
      await SocialRecoveryService.sendRecoveryShares(
        masterSeed: widget.masterSeed,
        selectedContacts: recoveryContacts,
      );

      print('✅ Sent encrypted shares to all contacts');

      if (!mounted) return;

      // 3. Show success screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SocialRecoverySuccessScreen(
            contacts: recoveryContacts,
          ),
        ),
      );

      if (!mounted) return;

      // Navigate back
      Navigator.pop(context);
    } catch (e) {
      print('❌ Error setting up recovery: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to setup recovery'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _shareInviteLink(
    ContactWithStatus contact,
    String inviteLink,
    String tempNpub,
  ) {
    // TODO: Integrate with share_plus plugin
    final message = NostrInviteService.generateShareMessage(
      contactName: contact.name,
      senderName: 'Auwal', // TODO: Get from user profile
      inviteLink: inviteLink,
    );
    
    print('📱 Share link: $message');
  }

  String _generateDummyPublicKey(String npub) {
    // In production, fetch actual public key from Nostr profile
    return 'pk_$npub'.padRight(64, '0');
  }

  String _generateDummyNpub(String name) {
    // Generate a temporary npub for phone contacts
    final hash = name.hashCode.toRadixString(16).padLeft(8, '0');
    return 'temp_$hash';
  }

  @override
  Widget build(BuildContext context) {
    if (_isSending) {
      return Scaffold(
        backgroundColor: const Color(0xFF0C0C1A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFFF7931A),
              ),
              SizedBox(height: 16.h),
              Text(
                'Setting up recovery...',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.white,
                  fontFamily: 'Google Sans',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C1A),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text(
          'Recovery Setup',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            fontFamily: 'Google Sans',
          ),
        ),
      ),
      body: _selectedContacts == null
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80.r,
                  height: 80.r,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111128),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield,
                    color: Color(0xFFF7931A),
                    size: 40,
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Secure Your Wallet',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Google Sans',
                  ),
                ),
                SizedBox(height: 8.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Text(
                    'Pick 3 trusted people to help you recover if you lose access to your phone',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: const Color(0xFFA1A1B2),
                      fontFamily: 'Google Sans',
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: 32.h),
                GestureDetector(
                  onTap: _startSetup,
                  child: Container(
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(horizontal: 16.w),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7931A),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: Text(
                        'Pick Recovery Contacts',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0C0C1A),
                          fontFamily: 'Google Sans',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Contacts selected: ${_selectedContacts?.length ?? 0}',
                  style: const TextStyle(color: Colors.white),
                ),
                SizedBox(height: 16.h),
                GestureDetector(
                  onTap: () => setState(() => _selectedContacts = null),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7931A),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'Change Contacts',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0C0C1A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
