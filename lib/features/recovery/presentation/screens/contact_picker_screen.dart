import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sabi_wallet/features/nostr/services/nostr_service.dart';
import 'package:sabi_wallet/features/recovery/services/nostr_invite_service.dart';
import 'package:share_plus/share_plus.dart';

/// Contact model for guardian selection
class ContactWithStatus {
  final String id; // Unique identifier
  final String name;
  final String? phoneNumber;
  final String? npub;
  final String? hexPubkey;
  final bool isOnNostr;
  final String? avatarUrl;
  final String source; // 'nostr_follow', 'device_contact', 'manual'

  ContactWithStatus({
    String? id,
    required this.name,
    this.phoneNumber,
    this.npub,
    this.hexPubkey,
    this.isOnNostr = false,
    this.avatarUrl,
    this.source = 'device_contact',
  }) : id = id ?? _generateId(npub, phoneNumber, name);

  static String _generateId(String? npub, String? phoneNumber, String name) {
    // Create unique ID from available identifiers
    if (npub != null && npub.isNotEmpty) return 'nostr_$npub';
    if (phoneNumber != null && phoneNumber.isNotEmpty)
      return 'phone_$phoneNumber';
    return 'name_${name.hashCode}_${DateTime.now().microsecondsSinceEpoch}';
  }

  String get displayIdentifier => npub ?? phoneNumber ?? 'No contact info';

  String get shortNpub {
    if (npub == null) return '';
    if (npub!.length <= 16) return npub!;
    return '${npub!.substring(0, 8)}...${npub!.substring(npub!.length - 8)}';
  }
}

/// Screen for picking trusted contacts as recovery guardians
class ContactPickerScreen extends StatefulWidget {
  final int maxSelection;
  final Function(List<ContactWithStatus>) onContactsSelected;

  const ContactPickerScreen({
    super.key,
    this.maxSelection = 5,
    required this.onContactsSelected,
  });

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen>
    with SingleTickerProviderStateMixin {
  final List<ContactWithStatus> _selectedContacts = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _npubInputController = TextEditingController();

  List<ContactWithStatus> _nostrFollows = [];
  List<ContactWithStatus> _deviceContacts = [];
  List<ContactWithStatus> _allContacts = [];
  List<ContactWithStatus> _filteredContacts = [];
  List<ContactWithStatus> _searchResults = [];

  bool _isLoading = true;
  bool _isSearching = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_filterContacts);
    _loadAllContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _npubInputController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllContacts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    // Only load Nostr follows automatically
    // Device contacts are loaded on-demand when user clicks button
    await _loadNostrFollows();

    _mergeContacts();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadNostrFollows() async {
    try {
      // Check if user has Nostr keys
      final npub = await NostrService.getNpub();
      if (npub == null || npub.isEmpty) {
        if (!mounted) return;
        setState(() {
          _nostrFollows = [];
        });
        return;
      }

      // Fetch user's follows
      final hexPubkey = NostrService.npubToHex(npub);
      if (hexPubkey == null) {
        if (!mounted) return;
        setState(() {
          _nostrFollows = [];
        });
        return;
      }

      final follows = await NostrService.fetchUserFollowsDirect(hexPubkey);

      if (follows.isEmpty) {
        if (!mounted) return;
        setState(() {
          _nostrFollows = [];
        });
        return;
      }

      // Fetch metadata for each follow using direct WebSocket
      final List<ContactWithStatus> nostrContacts = [];

      // Limit to first 20 follows to avoid too many requests
      final limitedFollows = follows.take(20).toList();

      for (final followHex in limitedFollows) {
        try {
          // Use direct metadata fetch for reliability
          final metadata = await NostrService.fetchAuthorMetadataDirect(
            followHex,
          );
          final followNpub = NostrService.hexToNpub(followHex);

          final name =
              metadata['name'] ??
              metadata['display_name'] ??
              metadata['displayName'] ??
              'Nostr User';

          final avatarUrl = metadata['picture'] ?? metadata['avatar'];

          nostrContacts.add(
            ContactWithStatus(
              name: name,
              npub: followNpub,
              hexPubkey: followHex,
              isOnNostr: true,
              avatarUrl: avatarUrl,
              source: 'nostr_follow',
            ),
          );
        } catch (e) {
          // Still add the contact even without metadata
          final followNpub = NostrService.hexToNpub(followHex);
          nostrContacts.add(
            ContactWithStatus(
              name: 'Nostr User',
              npub: followNpub,
              hexPubkey: followHex,
              isOnNostr: true,
              source: 'nostr_follow',
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _nostrFollows = nostrContacts;
      });
    } catch (e) {
      print('Error loading Nostr follows: $e');
      if (!mounted) return;
      setState(() {
        _nostrFollows = [];
      });
    }
  }

  /// Open native contact picker and add selected contact
  Future<void> _openNativeContactPicker() async {
    try {
      // Check permission status using permission_handler
      var status = await Permission.contacts.status;
      debugPrint('📱 Initial contact permission status: $status');

      // If not granted, request permission
      if (!status.isGranted) {
        status = await Permission.contacts.request();
        debugPrint('📱 Permission request result: $status');
      }

      // Handle permission states
      if (status.isPermanentlyDenied) {
        if (!mounted) return;
        // Show dialog to open settings
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: const Color(0xFF111128),
                title: Text(
                  'Permission Required',
                  style: TextStyle(color: Colors.white, fontSize: 18.sp),
                ),
                content: Text(
                  'Contact permission is permanently denied. Please enable it in your device settings to select contacts.',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 14.sp,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: const Color(0xFFA1A1B2)),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      openAppSettings();
                    },
                    child: Text(
                      'Open Settings',
                      style: TextStyle(color: const Color(0xFFF7931A)),
                    ),
                  ),
                ],
              ),
        );
        return;
      }

      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact permission is required to select contacts'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Open native contact picker
      final contact = await FlutterContacts.openExternalPick();

      if (contact != null) {
        // Fetch full contact details
        final fullContact = await FlutterContacts.getContact(
          contact.id,
          withProperties: true,
        );

        if (fullContact != null && fullContact.phones.isNotEmpty) {
          final phoneNumber =
              fullContact.phones.first.number
                  .replaceAll(RegExp(r'[^\d+]'), '')
                  .trim();

          // Check if contact already exists
          final exists = _deviceContacts.any(
            (c) => c.phoneNumber == phoneNumber,
          );

          if (!exists) {
            final newContact = ContactWithStatus(
              name:
                  fullContact.displayName.isNotEmpty
                      ? fullContact.displayName
                      : 'Unknown',
              phoneNumber: phoneNumber,
              isOnNostr: false,
              source: 'device_contact',
            );

            if (!mounted) return;
            setState(() {
              _deviceContacts.add(newContact);
              _mergeContacts();
            });

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added ${newContact.name}'),
                backgroundColor: const Color(0xFF00FFB2),
              ),
            );
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Contact already added'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected contact has no phone number'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error opening contact picker: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _mergeContacts() {
    // Combine all contacts, prioritizing Nostr follows
    _allContacts = [..._nostrFollows, ..._deviceContacts];
    _filterContacts();
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();

    List<ContactWithStatus> sourceList;
    switch (_tabController.index) {
      case 0: // All
        sourceList = _allContacts;
        break;
      case 1: // Nostr
        sourceList = _nostrFollows;
        break;
      case 2: // Phone
        sourceList = _deviceContacts;
        break;
      default:
        sourceList = _allContacts;
    }

    if (query.isEmpty) {
      setState(() {
        _filteredContacts = sourceList;
        _searchResults = [];
        _isSearching = false;
      });
    } else {
      // First filter local contacts
      final localResults =
          sourceList.where((contact) {
            return contact.name.toLowerCase().contains(query) ||
                (contact.phoneNumber?.toLowerCase().contains(query) ?? false) ||
                (contact.npub?.toLowerCase().contains(query) ?? false);
          }).toList();

      setState(() {
        _filteredContacts = localResults;
      });

      // If on Nostr tab or All tab, also search Nostr network
      if (_tabController.index == 0 || _tabController.index == 1) {
        _searchNostrUsers(query);
      }
    }
  }

  /// Search Nostr network for users by name, npub, or NIP-05
  Future<void> _searchNostrUsers(String query) async {
    if (query.length < 2) return; // Require at least 2 characters

    // Debounce search
    await Future.delayed(const Duration(milliseconds: 300));
    if (_searchController.text.toLowerCase() != query) return;

    setState(() => _isSearching = true);

    try {
      final results = await NostrService.searchUsers(query);

      if (!mounted) return;
      if (_searchController.text.toLowerCase() != query) return;

      // Convert results to ContactWithStatus
      final contacts =
          results.map((result) {
            return ContactWithStatus(
              name:
                  result['name'] ??
                  result['display_name'] ??
                  result['displayName'] ??
                  'Nostr User',
              npub: result['npub'],
              hexPubkey: result['pubkey'],
              isOnNostr: true,
              avatarUrl: result['picture'],
              source: 'nostr_search',
            );
          }).toList();

      // Filter out already-added contacts
      final newContacts =
          contacts.where((c) {
            return !_filteredContacts.any((existing) => existing.id == c.id);
          }).toList();

      setState(() {
        _searchResults = newContacts;
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching Nostr users: $e');
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  /// Show dialog to manually enter npub or NIP-05 address
  Future<void> _showAddByNpubDialog() async {
    _npubInputController.clear();
    bool isLoading = false;
    String? error;
    ContactWithStatus? previewContact;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24.r,
                right: 24.r,
                top: 24.r,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.r,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Guardian by Nostr ID',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: 'Google Sans',
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Enter an npub address or NIP-05 identifier (e.g., user@domain.com)',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: const Color(0xFFA1A1B2),
                      fontFamily: 'Google Sans',
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Input field
                  TextField(
                    controller: _npubInputController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'npub1... or user@domain.com',
                      hintStyle: const TextStyle(color: Color(0xFFA1A1B2)),
                      prefixIcon: const Icon(
                        Icons.person_search,
                        color: Color(0xFFA1A1B2),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF111128),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      errorText: error,
                      errorStyle: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12.sp,
                      ),
                    ),
                    onChanged: (value) {
                      setSheetState(() {
                        error = null;
                        previewContact = null;
                      });
                    },
                  ),
                  SizedBox(height: 16.h),

                  // Preview section
                  if (previewContact != null) ...[
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111128),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: const Color(0xFF00FFB2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48.r,
                            height: 48.r,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6),
                              shape: BoxShape.circle,
                            ),
                            child:
                                previewContact!.avatarUrl != null
                                    ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: previewContact!.avatarUrl!,
                                        fit: BoxFit.cover,
                                        width: 48.r,
                                        height: 48.r,
                                        placeholder:
                                            (_, __) => Center(
                                              child: Text(
                                                previewContact!.name.isNotEmpty
                                                    ? previewContact!.name[0]
                                                        .toUpperCase()
                                                    : 'N',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18.sp,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        errorWidget:
                                            (_, __, ___) => Center(
                                              child: Text(
                                                previewContact!.name.isNotEmpty
                                                    ? previewContact!.name[0]
                                                        .toUpperCase()
                                                    : 'N',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18.sp,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                      ),
                                    )
                                    : Center(
                                      child: Text(
                                        previewContact!.name.isNotEmpty
                                            ? previewContact!.name[0]
                                                .toUpperCase()
                                            : 'N',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18.sp,
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
                                  previewContact!.name,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontFamily: 'Google Sans',
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  previewContact!.shortNpub,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: const Color(0xFFA1A1B2),
                                    fontFamily: 'Google Sans',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.check_circle,
                            color: const Color(0xFF00FFB2),
                            size: 24.r,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111128),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFA1A1B2),
                                  fontFamily: 'Google Sans',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap:
                              isLoading
                                  ? null
                                  : () async {
                                    final input =
                                        _npubInputController.text.trim();
                                    if (input.isEmpty) {
                                      setSheetState(() {
                                        error =
                                            'Please enter an npub or NIP-05';
                                      });
                                      return;
                                    }

                                    // If we have a preview, add the contact
                                    if (previewContact != null) {
                                      _addManualContact(previewContact!);
                                      Navigator.pop(context);
                                      return;
                                    }

                                    // Otherwise, look up the user
                                    setSheetState(() {
                                      isLoading = true;
                                      error = null;
                                    });

                                    try {
                                      final contact = await _lookupNostrUser(
                                        input,
                                      );
                                      if (contact != null) {
                                        setSheetState(() {
                                          previewContact = contact;
                                          isLoading = false;
                                        });
                                      } else {
                                        setSheetState(() {
                                          error = 'User not found';
                                          isLoading = false;
                                        });
                                      }
                                    } catch (e) {
                                      setSheetState(() {
                                        error = 'Failed to lookup user';
                                        isLoading = false;
                                      });
                                    }
                                  },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7931A),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Center(
                              child:
                                  isLoading
                                      ? SizedBox(
                                        width: 20.r,
                                        height: 20.r,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF0C0C1A),
                                        ),
                                      )
                                      : Text(
                                        previewContact != null
                                            ? 'Add Guardian'
                                            : 'Look Up',
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Lookup a Nostr user by npub or NIP-05
  Future<ContactWithStatus?> _lookupNostrUser(String input) async {
    try {
      // Check if it's an npub
      if (input.startsWith('npub1')) {
        final hexPubkey = NostrService.npubToHex(input);
        if (hexPubkey != null) {
          final metadata = await NostrService.fetchAuthorMetadataDirect(
            hexPubkey,
          );
          return ContactWithStatus(
            name:
                metadata['name'] ??
                metadata['display_name'] ??
                metadata['displayName'] ??
                'Nostr User',
            npub: input,
            hexPubkey: hexPubkey,
            isOnNostr: true,
            avatarUrl: metadata['picture'],
            source: 'manual_npub',
          );
        }
      }

      // Otherwise, search (handles NIP-05 and names)
      final results = await NostrService.searchUsers(input);
      if (results.isNotEmpty) {
        final first = results.first;
        return ContactWithStatus(
          name:
              first['name'] ??
              first['display_name'] ??
              first['displayName'] ??
              'Nostr User',
          npub: first['npub'],
          hexPubkey: first['pubkey'],
          isOnNostr: true,
          avatarUrl: first['picture'],
          source: 'manual_search',
        );
      }

      return null;
    } catch (e) {
      print('Error looking up Nostr user: $e');
      return null;
    }
  }

  /// Add a manually entered contact
  void _addManualContact(ContactWithStatus contact) {
    // Check if already exists
    final exists =
        _allContacts.any((c) => c.id == contact.id) ||
        _selectedContacts.any((c) => c.id == contact.id);

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This guardian is already added'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if max selection reached
    if (_selectedContacts.length >= widget.maxSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum ${widget.maxSelection} guardians allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _nostrFollows.add(contact);
      _selectedContacts.add(contact);
      _mergeContacts();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${contact.name} as guardian ✓'),
        backgroundColor: const Color(0xFF00FFB2),
      ),
    );
  }

  void _toggleContactSelection(ContactWithStatus contact) {
    setState(() {
      final existingIndex = _selectedContacts.indexWhere(
        (c) => c.id == contact.id,
      );

      if (existingIndex >= 0) {
        _selectedContacts.removeAt(existingIndex);
      } else if (_selectedContacts.length < widget.maxSelection) {
        _selectedContacts.add(contact);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maximum ${widget.maxSelection} contacts allowed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  bool _isContactSelected(ContactWithStatus contact) {
    return _selectedContacts.any((c) => c.id == contact.id);
  }

  void _handleHelpJoinNostr(ContactWithStatus contact) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => _buildInviteBottomSheet(contact),
    );
  }

  Widget _buildInviteBottomSheet(ContactWithStatus contact) {
    return Padding(
      padding: EdgeInsets.all(24.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Help ${contact.name} join Nostr',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'Google Sans',
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Send them an invite link to set up their Nostr account and become your recovery guardian.',
            style: TextStyle(
              fontSize: 14.sp,
              color: const Color(0xFFA1A1B2),
              fontFamily: 'Google Sans',
            ),
          ),
          SizedBox(height: 24.h),

          // WhatsApp invite
          GestureDetector(
            onTap: () => _sendInvite(contact, 'whatsapp'),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.message, color: Colors.white, size: 18),
                  SizedBox(width: 8.w),
                  Text(
                    'Send via WhatsApp',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: 'Google Sans',
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),

          // SMS invite
          GestureDetector(
            onTap: () => _sendInvite(contact, 'sms'),
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
          SizedBox(height: 12.h),

          // Share link
          GestureDetector(
            onTap: () => _sendInvite(contact, 'share'),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                color: const Color(0xFF111128),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.share, color: Color(0xFFA1A1B2), size: 18),
                  SizedBox(width: 8.w),
                  Text(
                    'Share Link',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFA1A1B2),
                      fontFamily: 'Google Sans',
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Future<void> _sendInvite(ContactWithStatus contact, String method) async {
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
        senderName: 'Friend', // TODO: Get from user profile
        inviteLink: inviteLink,
      );

      if (!mounted) return;
      Navigator.pop(context);

      // Share based on method
      if (method == 'share') {
        await Share.share(message);
      } else {
        // For WhatsApp/SMS, we use share_plus which will show share sheet
        await Share.share(message);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invite sent to ${contact.name}! 🚀'),
          backgroundColor: const Color(0xFF00FFB2),
        ),
      );
    } catch (e) {
      print('Error sending invite: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send invite'),
          backgroundColor: Colors.red,
        ),
      );
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
          'Select Recovery Guardians',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Google Sans',
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => _filterContacts(),
          indicatorColor: const Color(0xFFF7931A),
          labelColor: const Color(0xFFF7931A),
          unselectedLabelColor: const Color(0xFFA1A1B2),
          tabs: [
            Tab(text: 'All (${_allContacts.length})'),
            Tab(text: 'Nostr (${_nostrFollows.length})'),
            Tab(text: 'Phone (${_deviceContacts.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: EdgeInsets.all(16.r),
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFF333355)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: const Color(0xFFF7931A),
                  size: 20.r,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Select 3-5 trusted people. They\'ll help you recover your wallet if needed.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFFA1A1B2),
                      fontFamily: 'Google Sans',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar with Add Npub button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.r),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by name, npub, or NIP-05...',
                      hintStyle: const TextStyle(color: Color(0xFFA1A1B2)),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFFA1A1B2),
                      ),
                      suffixIcon:
                          _isSearching
                              ? Padding(
                                padding: EdgeInsets.all(12.r),
                                child: SizedBox(
                                  width: 20.r,
                                  height: 20.r,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFF7931A),
                                  ),
                                ),
                              )
                              : null,
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
                SizedBox(width: 8.w),
                // Add by npub button
                GestureDetector(
                  onTap: _showAddByNpubDialog,
                  child: Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.person_add,
                      color: Colors.white,
                      size: 24.r,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),

          // Selection counter
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.r),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected: ${_selectedContacts.length}/${widget.maxSelection}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color:
                        _selectedContacts.length >= 3
                            ? const Color(0xFF00FFB2)
                            : const Color(0xFFA1A1B2),
                    fontFamily: 'Google Sans',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_selectedContacts.length < 3)
                  Text(
                    'Need ${3 - _selectedContacts.length} more',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFFF7931A),
                      fontFamily: 'Google Sans',
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 8.h),

          // Contacts List
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF7931A),
                      ),
                    )
                    : (_filteredContacts.isEmpty && _searchResults.isEmpty)
                    ? _buildEmptyState()
                    : Stack(
                      children: [
                        ListView.builder(
                          padding: EdgeInsets.all(16.r),
                          itemCount:
                              _filteredContacts.length +
                              (_searchResults.isNotEmpty ? 1 : 0) +
                              _searchResults.length,
                          itemBuilder: (context, index) {
                            // Existing contacts
                            if (index < _filteredContacts.length) {
                              final contact = _filteredContacts[index];
                              return _buildContactTile(contact);
                            }

                            // Search results header
                            if (index == _filteredContacts.length &&
                                _searchResults.isNotEmpty) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  top: 16.h,
                                  bottom: 8.h,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search,
                                      size: 16.r,
                                      color: const Color(0xFF8B5CF6),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Search Results',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: const Color(0xFF8B5CF6),
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Google Sans',
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Search result contacts
                            final searchIndex =
                                index -
                                _filteredContacts.length -
                                (_searchResults.isNotEmpty ? 1 : 0);
                            if (searchIndex >= 0 &&
                                searchIndex < _searchResults.length) {
                              final contact = _searchResults[searchIndex];
                              return _buildContactTile(contact);
                            }

                            return const SizedBox.shrink();
                          },
                        ),
                        // Add contact button for Phone tab
                        if (_tabController.index == 2 ||
                            _tabController.index == 0)
                          Positioned(
                            right: 16.r,
                            bottom: 16.r,
                            child: FloatingActionButton(
                              onPressed: _openNativeContactPicker,
                              backgroundColor: const Color(0xFFF7931A),
                              child: const Icon(
                                Icons.add,
                                color: Color(0xFF0C0C1A),
                              ),
                            ),
                          ),
                      ],
                    ),
          ),

          // Continue Button
          Padding(
            padding: EdgeInsets.all(16.r),
            child: GestureDetector(
              onTap:
                  _selectedContacts.length >= 3
                      ? () {
                        widget.onContactsSelected(_selectedContacts);
                        Navigator.pop(context, _selectedContacts);
                      }
                      : null,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  color:
                      _selectedContacts.length >= 3
                          ? const Color(0xFFF7931A)
                          : const Color(0xFF333355),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Text(
                    _selectedContacts.length >= 3
                        ? 'Continue with ${_selectedContacts.length} Guardians'
                        : 'Select at least 3 guardians',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color:
                          _selectedContacts.length >= 3
                              ? const Color(0xFF0C0C1A)
                              : const Color(0xFFA1A1B2),
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

  Widget _buildEmptyState() {
    final tabIndex = _tabController.index;
    String message;
    IconData icon;

    if (tabIndex == 1) {
      message =
          'No Nostr follows found.\nFollow people on Nostr to add them as guardians.';
      icon = Icons.group_add;
    } else if (tabIndex == 2) {
      message =
          'No phone contacts added yet.\nTap the button below to add contacts from your phone.';
      icon = Icons.contacts;
    } else {
      message = 'No contacts found.\nAdd Nostr follows or phone contacts.';
      icon = Icons.person_search;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64.r, color: const Color(0xFF333355)),
          SizedBox(height: 16.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: const Color(0xFFA1A1B2),
              fontFamily: 'Google Sans',
            ),
          ),
          SizedBox(height: 24.h),
          if (tabIndex == 2 || tabIndex == 0)
            GestureDetector(
              onTap: _openNativeContactPicker,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7931A),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: const Color(0xFF0C0C1A), size: 18.r),
                    SizedBox(width: 8.w),
                    Text(
                      'Add Phone Contact',
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
        ],
      ),
    );
  }

  Widget _buildContactTile(ContactWithStatus contact) {
    final isSelected = _isContactSelected(contact);

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _toggleContactSelection(contact),
            child: Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: const Color(0xFF111128),
                border: Border.all(
                  color:
                      isSelected ? const Color(0xFFF7931A) : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 48.r,
                    height: 48.r,
                    decoration: BoxDecoration(
                      color:
                          contact.isOnNostr
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFFF7931A),
                      shape: BoxShape.circle,
                    ),
                    child:
                        contact.avatarUrl != null &&
                                contact.avatarUrl!.isNotEmpty
                            ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: contact.avatarUrl!,
                                fit: BoxFit.cover,
                                width: 48.r,
                                height: 48.r,
                                placeholder:
                                    (context, url) => Center(
                                      child: Text(
                                        contact.name.isNotEmpty
                                            ? contact.name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => Center(
                                      child: Text(
                                        contact.name.isNotEmpty
                                            ? contact.name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                              ),
                            )
                            : Center(
                              child: Text(
                                contact.name.isNotEmpty
                                    ? contact.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                  ),
                  SizedBox(width: 12.w),

                  // Name + identifier
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                contact.name,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  fontFamily: 'Google Sans',
                                ),
                              ),
                            ),
                            if (contact.source == 'nostr_follow')
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF8B5CF6,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  'Following',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: const Color(0xFF8B5CF6),
                                    fontFamily: 'Google Sans',
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          contact.isOnNostr
                              ? contact.shortNpub
                              : contact.phoneNumber ?? 'No phone',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: const Color(0xFFA1A1B2),
                            fontFamily:
                                contact.isOnNostr ? 'Courier' : 'Google Sans',
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),

                  // Status indicator
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt,
                            color: const Color(0xFF00FFB2),
                            size: 12.r,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Nostr',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF00FFB2),
                              fontFamily: 'Google Sans',
                            ),
                          ),
                        ],
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

          // Help Join Nostr button for non-Nostr contacts when selected
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
                      Icon(
                        Icons.person_add,
                        color: const Color(0xFFF7931A),
                        size: 16.r,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Help ${contact.name} join Nostr',
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
        ],
      ),
    );
  }
}
