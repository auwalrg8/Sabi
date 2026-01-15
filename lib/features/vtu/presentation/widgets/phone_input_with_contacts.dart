import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/services/contact_service.dart';

/// Enhanced phone number input field with contact integration
/// Shows recent contacts and allows importing from device contacts
class PhoneInputWithContacts extends StatefulWidget {
  final TextEditingController controller;
  final String? detectedNetwork;
  final Color? networkColor;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final Color accentColor;

  const PhoneInputWithContacts({
    super.key,
    required this.controller,
    this.detectedNetwork,
    this.networkColor,
    this.errorText,
    this.onChanged,
    this.accentColor = const Color(0xFFF7931A),
  });

  @override
  State<PhoneInputWithContacts> createState() => _PhoneInputWithContactsState();
}

class _PhoneInputWithContactsState extends State<PhoneInputWithContacts> {
  List<ContactInfo> _recentContacts = [];
  List<ContactInfo> _deviceContacts = [];
  List<ContactInfo> _searchResults = [];
  bool _isLoadingContacts = false;
  bool _showContactPicker = false;
  bool _hasLoadedDeviceContacts = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecentContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentContacts() async {
    final contacts = await ContactService.getRecentContacts(limit: 5);
    // Filter only phone type contacts
    final phoneContacts = contacts.where((c) => c.type == 'phone').toList();
    if (mounted) {
      setState(() {
        _recentContacts = phoneContacts;
      });
    }
  }

  Future<void> _loadDeviceContacts() async {
    if (_isLoadingContacts || _hasLoadedDeviceContacts) return;

    setState(() {
      _isLoadingContacts = true;
    });

    final contacts = await ContactService.importPhoneContacts();
    // Filter only phone type contacts
    final phoneContacts = contacts.where((c) => c.type == 'phone').toList();

    if (mounted) {
      setState(() {
        _deviceContacts = phoneContacts;
        _isLoadingContacts = false;
        _hasLoadedDeviceContacts = true;
      });
    }
  }

  void _selectContact(ContactInfo contact) {
    widget.controller.text = _formatPhoneNumber(contact.identifier);
    widget.onChanged?.call(contact.identifier);
    setState(() {
      _showContactPicker = false;
    });
  }

  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Convert international format to local
    if (cleaned.startsWith('+234')) {
      cleaned = '0${cleaned.substring(4)}';
    } else if (cleaned.startsWith('234') && cleaned.length > 10) {
      cleaned = '0${cleaned.substring(3)}';
    }

    return cleaned;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // Search in device contacts
    final allContacts =
        _hasLoadedDeviceContacts ? _deviceContacts : _recentContacts;
    ContactService.searchContacts(query, allContacts: allContacts).then((
      results,
    ) {
      if (mounted) {
        setState(() {
          _searchResults = results.take(10).toList();
        });
      }
    });
  }

  void _showContactPickerModal() {
    _loadDeviceContacts();
    setState(() {
      _showContactPicker = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with contact picker button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Phone Number',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            GestureDetector(
              onTap: _showContactPickerModal,
              child: Row(
                children: [
                  Icon(Icons.contacts, color: widget.accentColor, size: 18.sp),
                  SizedBox(width: 4.w),
                  Text(
                    'Contacts',
                    style: TextStyle(
                      color: widget.accentColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),

        // Phone input field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color:
                  widget.errorText != null
                      ? const Color(0xFFFF4D4F)
                      : const Color(0xFF2A2A3E),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF111128),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12.r),
                    bottomLeft: Radius.circular(12.r),
                  ),
                ),
                child: Row(
                  children: [
                    Text('🇳🇬', style: TextStyle(fontSize: 18.sp)),
                    SizedBox(width: 4.w),
                    Text(
                      '+234',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  decoration: InputDecoration(
                    hintText: '0801 234 5678',
                    hintStyle: TextStyle(
                      color: const Color(0xFF6B7280),
                      fontSize: 16.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 14.h,
                    ),
                    suffixIcon:
                        widget.detectedNetwork != null
                            ? Padding(
                              padding: EdgeInsets.only(right: 12.w),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      widget.networkColor?.withOpacity(0.2) ??
                                      Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  widget.detectedNetwork!,
                                  style: TextStyle(
                                    color: widget.networkColor ?? Colors.grey,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            : null,
                    suffixIconConstraints: BoxConstraints(minHeight: 24.h),
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
            ],
          ),
        ),

        // Error text
        if (widget.errorText != null) ...[
          SizedBox(height: 6.h),
          Text(
            widget.errorText!,
            style: TextStyle(color: const Color(0xFFFF4D4F), fontSize: 12.sp),
          ),
        ],

        // Recent Contacts
        if (_recentContacts.isNotEmpty && !_showContactPicker) ...[
          SizedBox(height: 16.h),
          Text(
            'Recent',
            style: TextStyle(
              color: const Color(0xFFA1A1B2),
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          SizedBox(
            height: 70.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recentContacts.length,
              separatorBuilder: (_, __) => SizedBox(width: 12.w),
              itemBuilder: (context, index) {
                final contact = _recentContacts[index];
                return _RecentContactChip(
                  contact: contact,
                  accentColor: widget.accentColor,
                  onTap: () => _selectContact(contact),
                );
              },
            ),
          ),
        ],

        // Contact Picker Modal
        if (_showContactPicker) ...[
          SizedBox(height: 16.h),
          _ContactPickerSection(
            deviceContacts: _deviceContacts,
            recentContacts: _recentContacts,
            searchResults: _searchResults,
            searchController: _searchController,
            searchQuery: _searchQuery,
            isLoading: _isLoadingContacts,
            accentColor: widget.accentColor,
            onContactSelected: _selectContact,
            onSearchChanged: _onSearchChanged,
            onClose: () {
              setState(() {
                _showContactPicker = false;
                _searchController.clear();
                _searchQuery = '';
                _searchResults = [];
              });
            },
          ),
        ],
      ],
    );
  }
}

class _RecentContactChip extends StatelessWidget {
  final ContactInfo contact;
  final Color accentColor;
  final VoidCallback onTap;

  const _RecentContactChip({
    required this.contact,
    required this.accentColor,
    required this.onTap,
  });

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 65.w,
        child: Column(
          children: [
            Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getInitials(contact.displayName),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              contact.displayName.split(' ').first,
              style: TextStyle(color: Colors.white, fontSize: 11.sp),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactPickerSection extends StatelessWidget {
  final List<ContactInfo> deviceContacts;
  final List<ContactInfo> recentContacts;
  final List<ContactInfo> searchResults;
  final TextEditingController searchController;
  final String searchQuery;
  final bool isLoading;
  final Color accentColor;
  final ValueChanged<ContactInfo> onContactSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClose;

  const _ContactPickerSection({
    required this.deviceContacts,
    required this.recentContacts,
    required this.searchResults,
    required this.searchController,
    required this.searchQuery,
    required this.isLoading,
    required this.accentColor,
    required this.onContactSelected,
    required this.onSearchChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final displayContacts =
        searchQuery.isNotEmpty
            ? searchResults
            : (deviceContacts.isNotEmpty
                ? deviceContacts.take(20).toList()
                : recentContacts);

    return Container(
      constraints: BoxConstraints(maxHeight: 300.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with search and close
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111128),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: TextField(
                      controller: searchController,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: 'Search contacts...',
                        hintStyle: TextStyle(
                          color: const Color(0xFF6B7280),
                          fontSize: 14.sp,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: const Color(0xFF6B7280),
                          size: 20.sp,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                      ),
                      onChanged: onSearchChanged,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 40.w,
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111128),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.close,
                      color: const Color(0xFFA1A1B2),
                      size: 20.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading indicator
          if (isLoading)
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                children: [
                  SizedBox(
                    width: 24.w,
                    height: 24.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Loading contacts...',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
            ),

          // Contact list
          if (!isLoading && displayContacts.isNotEmpty)
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.only(bottom: 8.h),
                itemCount: displayContacts.length,
                itemBuilder: (context, index) {
                  final contact = displayContacts[index];
                  return _ContactListItem(
                    contact: contact,
                    accentColor: accentColor,
                    onTap: () => onContactSelected(contact),
                  );
                },
              ),
            ),

          // Empty state
          if (!isLoading && displayContacts.isEmpty)
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                children: [
                  Icon(
                    Icons.person_search,
                    color: const Color(0xFF6B7280),
                    size: 32.sp,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    searchQuery.isNotEmpty
                        ? 'No contacts found'
                        : 'No contacts available',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactListItem extends StatelessWidget {
  final ContactInfo contact;
  final Color accentColor;
  final VoidCallback onTap;

  const _ContactListItem({
    required this.contact,
    required this.accentColor,
    required this.onTap,
  });

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getInitials(contact.displayName),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 14.sp,
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
                    contact.displayName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    contact.identifier,
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 12.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: const Color(0xFF6B7280),
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}
