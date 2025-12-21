import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:sabi_wallet/features/recovery/nostr_invite_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// Smart contact picker with dual source: phone contacts + Nostr follows
/// - Shows phone contacts with "Help join Nostr" option
/// - Shows Nostr follows with "Already on Nostr ✓" badge
/// - Allows selection of 3 trusted contacts
class ContactPickerScreen extends ConsumerStatefulWidget {
  final Function(List<ContactWithStatus>) onContactsSelected;

  const ContactPickerScreen({
    required this.onContactsSelected,
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends ConsumerState<ContactPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ContactWithStatus> _allContacts = [];
  List<ContactWithStatus> _filteredContacts = [];
  List<ContactWithStatus> _selectedContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      setState(() => _isLoading = true);

      // Request contacts permission
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        print('Contacts permission denied');
        setState(() => _isLoading = false);
        return;
      }

      // Load phone contacts
      final phoneContacts = await ContactsService.getContacts();
      final phoneContactsList = phoneContacts
          .where((contact) => contact.displayName != null && contact.displayName!.isNotEmpty)
          .map((contact) => ContactWithStatus(
            name: contact.displayName ?? 'Unknown',
            phoneNumber: contact.phones?.isNotEmpty == true 
              ? contact.phones!.first.value 
              : null,
            email: contact.emails?.isNotEmpty == true 
              ? contact.emails!.first.value 
              : null,
            npub: null,
            isOnNostr: false,
          ))
          .toList();

      // In production, fetch Nostr follows from NostrService
      // For now, we'll just use phone contacts
      // final nostrFollows = await _getNostrFollows();

      setState(() {
        _allContacts = phoneContactsList;
        _filteredContacts = _allContacts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading contacts: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _allContacts
          .where((contact) =>
            contact.name.toLowerCase().contains(query) ||
            (contact.phoneNumber?.contains(query) ?? false) ||
            (contact.npub?.contains(query) ?? false))
          .toList();
    });
  }

  void _toggleContactSelection(ContactWithStatus contact) {
    setState(() {
      final index = _selectedContacts.indexWhere(
        (c) => c.phoneNumber == contact.phoneNumber && c.name == contact.name,
      );

      if (index >= 0) {
        _selectedContacts.removeAt(index);
      } else if (_selectedContacts.length < 3) {
        _selectedContacts.add(contact);
      }
    });
  }

  bool _isContactSelected(ContactWithStatus contact) {
    return _selectedContacts.any(
      (c) => c.phoneNumber == contact.phoneNumber && c.name == contact.name,
    );
  }

  void _handleHelpJoinNostr(ContactWithStatus contact) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111128),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => _buildHelpJoinModal(contact),
    );
  }

  Widget _buildHelpJoinModal(ContactWithStatus contact) {
    return Container(
      padding: EdgeInsets.all(20.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Help ${contact.name} join Nostr (30 seconds)',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              fontFamily: 'Google Sans',
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'We go create Nostr account for am sharp sharp',
            style: TextStyle(
              fontSize: 14.sp,
              color: const Color(0xFFA1A1B2),
              fontFamily: 'Google Sans',
            ),
          ),
          SizedBox(height: 24.h),
          GestureDetector(
            onTap: () => _sendInvite(contact),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF7931A),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.share, color: Color(0xFF0C0C1A), size: 18),
                  SizedBox(width: 8.w),
                  Text(
                    'Send Invite via WhatsApp',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0C0C1A),
                      fontFamily: 'Google Sans',
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          GestureDetector(
            onTap: () => _sendInviteSms(contact),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFF7931A), width: 2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
                child: Text(
                  'Send via SMS',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF7931A),
                    fontFamily: 'Google Sans',
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Future<void> _sendInvite(ContactWithStatus contact) async {
    try {
      // Generate temporary keypair for this contact
      final tempKeypair = await NostrInviteService.generateTemporaryKeypair();
      
      // Create invite link
      final inviteLink = await NostrInviteService.createInviteLink(
        contactName: contact.name,
        phoneNumber: contact.phoneNumber,
        tempNpub: tempKeypair['npub']!,
      );
      
      // Generate share message
      final message = NostrInviteService.generateShareMessage(
        contactName: contact.name,
        senderName: 'Auwal', // TODO: Get from user profile
        inviteLink: inviteLink,
      );
      
      // TODO: Share via WhatsApp/SMS (use share_plus plugin)
      print('📱 Share message: $message');
      
      if (!mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invite sent to ${contact.name}! 🚀'),
          backgroundColor: const Color(0xFF00FFB2),
        ),
      );
    } catch (e) {
      print('Error sending invite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send invite'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendInviteSms(ContactWithStatus contact) async {
    try {
      final tempKeypair = await NostrInviteService.generateTemporaryKeypair();
      final inviteLink = await NostrInviteService.createInviteLink(
        contactName: contact.name,
        phoneNumber: contact.phoneNumber,
        tempNpub: tempKeypair['npub']!,
      );
      
      final message = NostrInviteService.generateSmsMessage(
        senderName: 'Auwal',
        inviteLink: inviteLink,
      );
      
      print('📱 SMS message: $message');
      
      if (!mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SMS sent to ${contact.name}! 📲'),
          backgroundColor: const Color(0xFF00FFB2),
        ),
      );
    } catch (e) {
      print('Error sending SMS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Pick 3 trusted guys',
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            fontFamily: 'Google Sans',
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(16.r),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                hintStyle: const TextStyle(color: Color(0xFFA1A1B2)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFA1A1B2)),
                filled: true,
                fillColor: const Color(0xFF111128),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 12.h),
              ),
            ),
          ),
          
          // Contact Count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.r),
            child: Text(
              'Selected: ${_selectedContacts.length}/3',
              style: TextStyle(
                fontSize: 12.sp,
                color: const Color(0xFFA1A1B2),
                fontFamily: 'Google Sans',
              ),
            ),
          ),
          
          // Contacts List
          Expanded(
            child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF7931A)),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16.r),
                  itemCount: _filteredContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _filteredContacts[index];
                    final isSelected = _isContactSelected(contact);
                    
                    return Column(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleContactSelection(contact),
                          child: Container(
                            padding: EdgeInsets.all(12.r),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111128),
                              border: Border.all(
                                color: isSelected 
                                  ? const Color(0xFFF7931A) 
                                  : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 44.r,
                                  height: 44.r,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7931A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      contact.name.isNotEmpty 
                                        ? contact.name[0].toUpperCase() 
                                        : '?',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0C0C1A),
                                        fontFamily: 'Google Sans',
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                
                                // Name + Phone/Npub
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                          fontFamily: 'Google Sans',
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        contact.phoneNumber ?? contact.npub ?? 'No contact',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: const Color(0xFFA1A1B2),
                                          fontFamily: 'Courier', // Monospace
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Badge or Checkbox
                                if (contact.isOnNostr)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00FFB2).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Text(
                                      'Already on Nostr ✓',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF00FFB2),
                                        fontFamily: 'Google Sans',
                                      ),
                                    ),
                                  )
                                else if (isSelected)
                                  Container(
                                    width: 24.r,
                                    height: 24.r,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF7931A),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Color(0xFF0C0C1A),
                                      size: 16,
                                    ),
                                  )
                                else
                                  Container(
                                    width: 24.r,
                                    height: 24.r,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFF555566),
                                        width: 2,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Help Join Nostr Button (for phone contacts not on Nostr)
                        if (!contact.isOnNostr && isSelected)
                          Padding(
                            padding: EdgeInsets.only(top: 8.h),
                            child: GestureDetector(
                              onTap: () => _handleHelpJoinNostr(contact),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFF7931A),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.mail_outline,
                                      color: Color(0xFFF7931A),
                                      size: 16,
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      'Help join Nostr',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFF7931A),
                                        fontFamily: 'Google Sans',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        
                        SizedBox(height: 12.h),
                      ],
                    );
                  },
                ),
          ),
          
          // Continue Button
          Padding(
            padding: EdgeInsets.all(16.r),
            child: GestureDetector(
              onTap: _selectedContacts.length >= 3
                ? () {
                    widget.onContactsSelected(_selectedContacts);
                    Navigator.pop(context, _selectedContacts);
                  }
                : null,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  color: _selectedContacts.length >= 3
                    ? const Color(0xFFF7931A)
                    : const Color(0xFF555566),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Text(
                    'Continue to Recovery Setup',
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
          ),
        ],
      ),
    );
  }
}
