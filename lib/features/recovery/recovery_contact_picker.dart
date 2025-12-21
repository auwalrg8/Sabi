import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'social_recovery_service.dart';

/// Contact picker for selecting recovery contacts
class RecoveryContactPicker extends StatefulWidget {
  final List<RecoveryContact> availableContacts;
  final Function(List<RecoveryContact>) onContactsSelected;
  final int maxContacts;

  const RecoveryContactPicker({
    Key? key,
    required this.availableContacts,
    required this.onContactsSelected,
    this.maxContacts = 5,
  }) : super(key: key);

  @override
  State<RecoveryContactPicker> createState() => _RecoveryContactPickerState();
}

class _RecoveryContactPickerState extends State<RecoveryContactPicker> {
  final Set<int> _selectedIndices = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Text(
            'Pick 3 trusted guys',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: widget.availableContacts.length,
            itemBuilder: (context, index) {
              final contact = widget.availableContacts[index];
              final isSelected = _selectedIndices.contains(index);

              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedIndices.remove(index);
                      } else if (_selectedIndices.length < 5) {
                        _selectedIndices.add(index);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Maximum 5 contacts selected'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                      _updateSelection();
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF111128),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFF7931A)
                            : const Color(0xFFA1A1B2).withOpacity(0.3),
                        width: isSelected ? 2.w : 1.w,
                      ),
                    ),
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      children: [
                        Container(
                          width: 48.w,
                          height: 48.w,
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
                                color: Colors.white,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
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
                                contact.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (contact.phoneNumber != null)
                                Text(
                                  contact.phoneNumber!,
                                  style: TextStyle(
                                    color: const Color(0xFFA1A1B2),
                                    fontSize: 12.sp,
                                  ),
                                ),
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  contact.npub,
                                  style: TextStyle(
                                    color: const Color(0xFFA1A1B2),
                                    fontSize: 10.sp,
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Container(
                          width: 24.w,
                          height: 24.w,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF7931A)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFF7931A)
                                  : const Color(0xFFA1A1B2),
                              width: 2.w,
                            ),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.black,
                                    size: 16.sp,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedIndices.length} selected (pick 3)',
                style: TextStyle(
                  color: const Color(0xFFA1A1B2),
                  fontSize: 12.sp,
                ),
              ),
              if (_selectedIndices.length >= 3)
                ElevatedButton(
                  onPressed: () => widget.onContactsSelected(
                    _selectedIndices
                        .map((i) => widget.availableContacts[i])
                        .toList(),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF7931A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      color: const Color(0xFF0C0C1A),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _updateSelection() {
    final selected = _selectedIndices
        .map((i) => widget.availableContacts[i])
        .toList();
    widget.onContactsSelected(selected);
  }
}
