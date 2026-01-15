/// Social Profile Widgets - UI components for profile sharing
///
/// Displays social profiles, share requests, and verification badges
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../data/models/social_profile_model.dart';

/// Compact profile chip showing platform and handle
class SocialProfileChip extends StatelessWidget {
  final SocialProfile profile;
  final bool showVerified;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const SocialProfileChip({
    super.key,
    required this.profile,
    this.showVerified = true,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => _openProfile(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color:
                profile.isVerified
                    ? const Color(0xFF00FFB2).withValues(alpha: 0.5)
                    : const Color(0xFF2A2A40),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(profile.platform.emoji, style: TextStyle(fontSize: 16.sp)),
            SizedBox(width: 6.w),
            Text(
              profile.displayHandle,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showVerified && profile.isVerified) ...[
              SizedBox(width: 4.w),
              Icon(Icons.verified, color: const Color(0xFF00FFB2), size: 14.sp),
            ],
            if (onRemove != null) ...[
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.close,
                  color: const Color(0xFF6B6B80),
                  size: 16.sp,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    final url = profile.profileUrl;
    if (url != null) {
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${profile.platform.displayName} link copied!'),
          backgroundColor: const Color(0xFF00FFB2),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Card displaying a single social profile with full details
class SocialProfileCard extends StatelessWidget {
  final SocialProfile profile;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final bool isEditable;

  const SocialProfileCard({
    super.key,
    required this.profile,
    this.onEdit,
    this.onRemove,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF2A2A40)),
      ),
      child: Row(
        children: [
          // Platform Icon
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: Text(
                profile.platform.emoji,
                style: TextStyle(fontSize: 24.sp),
              ),
            ),
          ),
          SizedBox(width: 12.w),

          // Profile Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      profile.platform.displayName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (profile.isVerified) ...[
                      SizedBox(width: 6.w),
                      Icon(
                        Icons.verified,
                        color: const Color(0xFF00FFB2),
                        size: 16.sp,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  profile.displayHandle,
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),

          // Actions
          if (isEditable) ...[
            IconButton(
              onPressed: onEdit,
              icon: Icon(
                Icons.edit_outlined,
                color: const Color(0xFF6B6B80),
                size: 20.sp,
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: Icon(
                Icons.delete_outline,
                color: const Color(0xFFFF6B6B),
                size: 20.sp,
              ),
            ),
          ] else ...[
            // Tap to copy link
            IconButton(
              onPressed: () {
                final url = profile.profileUrl;
                if (url != null) {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${profile.platform.displayName} link copied!',
                      ),
                      backgroundColor: const Color(0xFF00FFB2),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: Icon(
                Icons.copy,
                color: const Color(0xFF00FFB2),
                size: 20.sp,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Grid of shared profiles from counterparty
class SharedProfilesView extends StatelessWidget {
  final List<SocialProfile> profiles;
  final String traderName;

  const SharedProfilesView({
    super.key,
    required this.profiles,
    required this.traderName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1421),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFF00FFB2).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.person_outline,
                color: const Color(0xFF00FFB2),
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                "$traderName's Profiles",
                style: TextStyle(
                  color: const Color(0xFF00FFB2),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FFB2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  'Shared',
                  style: TextStyle(
                    color: const Color(0xFF00FFB2),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Profiles
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children:
                profiles
                    .map(
                      (p) => SocialProfileChip(profile: p, showVerified: true),
                    )
                    .toList(),
          ),

          SizedBox(height: 12.h),

          // Privacy notice
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                color: const Color(0xFF6B6B80),
                size: 12.sp,
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  'These profiles are only visible during this trade',
                  style: TextStyle(
                    color: const Color(0xFF6B6B80),
                    fontSize: 10.sp,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Profile share request card (incoming request)
class ProfileShareRequestCard extends StatelessWidget {
  final ProfileShareRequest request;
  final VoidCallback? onAcceptMutual;
  final VoidCallback? onAcceptViewOnly;
  final VoidCallback? onDecline;

  const ProfileShareRequestCard({
    super.key,
    required this.request,
    this.onAcceptMutual,
    this.onAcceptViewOnly,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    if (!request.isPending) {
      return _buildResponsedCard();
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1A2E), const Color(0xFF0D1421)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFF7931A).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7931A).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.handshake_outlined,
                  color: const Color(0xFFF7931A),
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trust Profile Request',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${request.requesterName} wants to share profiles',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // What they're offering
          Text(
            'They offer to share:',
            style: TextStyle(color: const Color(0xFF6B6B80), fontSize: 12.sp),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children:
                request.offeredPlatforms.map((platform) {
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A40),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(platform.emoji, style: TextStyle(fontSize: 14.sp)),
                        SizedBox(width: 4.w),
                        Text(
                          platform.displayName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
          SizedBox(height: 20.h),

          // Actions
          Row(
            children: [
              // Decline
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B6B80),
                    side: const BorderSide(color: Color(0xFF2A2A40)),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              SizedBox(width: 8.w),

              // View Only
              Expanded(
                child: OutlinedButton(
                  onPressed: onAcceptViewOnly,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00FFB2),
                    side: const BorderSide(color: Color(0xFF00FFB2)),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: const Text('View Only'),
                ),
              ),
              SizedBox(width: 8.w),

              // Accept Mutual
              Expanded(
                child: ElevatedButton(
                  onPressed: onAcceptMutual,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFB2),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: const Text('Share Both'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResponsedCard() {
    final isAccepted = request.isAccepted;
    final color =
        isAccepted ? const Color(0xFF00FFB2) : const Color(0xFF6B6B80);
    final icon = isAccepted ? Icons.check_circle : Icons.cancel;
    final text =
        isAccepted
            ? (request.response == ShareConsent.mutual
                ? 'Profiles shared mutually'
                : 'Viewing their profiles')
            : 'Profile share declined';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(width: 8.w),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Button to initiate profile sharing
class RequestProfileShareButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool hasBeenRequested;

  const RequestProfileShareButton({
    super.key,
    this.onPressed,
    this.hasBeenRequested = false,
  });

  @override
  Widget build(BuildContext context) {
    if (hasBeenRequested) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty,
              color: const Color(0xFFF7931A),
              size: 16.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              'Request Sent',
              style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 12.sp),
            ),
          ],
        ),
      );
    }

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        Icons.handshake_outlined,
        color: const Color(0xFFF7931A),
        size: 18.sp,
      ),
      label: Text(
        'Request Trust Share',
        style: TextStyle(
          color: const Color(0xFFF7931A),
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFFF7931A).withValues(alpha: 0.1),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }
}

/// Dialog to select which profiles to share
class ProfileShareDialog extends StatefulWidget {
  final List<SocialProfile> availableProfiles;
  final String counterpartyName;
  final Function(List<SocialPlatform> platforms) onSubmit;

  const ProfileShareDialog({
    super.key,
    required this.availableProfiles,
    required this.counterpartyName,
    required this.onSubmit,
  });

  @override
  State<ProfileShareDialog> createState() => _ProfileShareDialogState();
}

class _ProfileShareDialogState extends State<ProfileShareDialog> {
  final Set<SocialPlatform> _selected = {};

  @override
  void initState() {
    super.initState();
    // Select all by default
    for (final profile in widget.availableProfiles) {
      _selected.add(profile.platform);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A0A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7931A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.handshake_outlined,
                    color: const Color(0xFFF7931A),
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request Trust Share',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'with ${widget.counterpartyName}',
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
            SizedBox(height: 20.h),

            // Explanation
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFF00FFB2),
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Choose which profiles you want to offer for sharing. '
                      'The other party can choose to share theirs too.',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 12.sp,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Profile selection
            Text(
              'Select profiles to share:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12.h),

            ...widget.availableProfiles.map((profile) {
              final isSelected = _selected.contains(profile.platform);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selected.remove(profile.platform);
                    } else {
                      _selected.add(profile.platform);
                    }
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? const Color(0xFF00FFB2).withValues(alpha: 0.1)
                            : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color:
                          isSelected
                              ? const Color(0xFF00FFB2)
                              : const Color(0xFF2A2A40),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        profile.platform.emoji,
                        style: TextStyle(fontSize: 20.sp),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.platform.displayName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              profile.displayHandle,
                              style: TextStyle(
                                color: const Color(0xFF6B6B80),
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 24.w,
                        height: 24.w,
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? const Color(0xFF00FFB2)
                                  : Colors.transparent,
                          border: Border.all(
                            color:
                                isSelected
                                    ? const Color(0xFF00FFB2)
                                    : const Color(0xFF6B6B80),
                          ),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child:
                            isSelected
                                ? Icon(
                                  Icons.check,
                                  color: Colors.black,
                                  size: 16.sp,
                                )
                                : null,
                      ),
                    ],
                  ),
                ),
              );
            }),

            SizedBox(height: 20.h),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B6B80),
                      side: const BorderSide(color: Color(0xFF2A2A40)),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed:
                        _selected.isEmpty
                            ? null
                            : () {
                              widget.onSubmit(_selected.toList());
                              Navigator.pop(context);
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF7931A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF2A2A40),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text('Send Request (${_selected.length})'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Add profile dialog
class AddProfileDialog extends StatefulWidget {
  final SocialPlatform? initialPlatform;
  final SocialProfile? existingProfile;
  final Function(SocialProfile profile) onSave;

  const AddProfileDialog({
    super.key,
    this.initialPlatform,
    this.existingProfile,
    required this.onSave,
  });

  @override
  State<AddProfileDialog> createState() => _AddProfileDialogState();
}

class _AddProfileDialogState extends State<AddProfileDialog> {
  late SocialPlatform _selectedPlatform;
  final _handleController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedPlatform =
        widget.existingProfile?.platform ??
        widget.initialPlatform ??
        SocialPlatform.x;
    _handleController.text = widget.existingProfile?.handle ?? '';
  }

  @override
  void dispose() {
    _handleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A0A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              widget.existingProfile != null ? 'Edit Profile' : 'Add Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20.h),

            // Platform selector
            if (widget.existingProfile == null) ...[
              Text(
                'Platform',
                style: TextStyle(
                  color: const Color(0xFFA1A1B2),
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children:
                    SocialPlatform.values.map((platform) {
                      final isSelected = _selectedPlatform == platform;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPlatform = platform;
                            _error = null;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? const Color(
                                      0xFF00FFB2,
                                    ).withValues(alpha: 0.1)
                                    : const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? const Color(0xFF00FFB2)
                                      : const Color(0xFF2A2A40),
                            ),
                          ),
                          child: Text(
                            platform.emoji,
                            style: TextStyle(fontSize: 20.sp),
                          ),
                        ),
                      );
                    }).toList(),
              ),
              SizedBox(height: 20.h),
            ],

            // Handle input
            Text(
              _selectedPlatform.displayName,
              style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 13.sp),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _handleController,
              style: TextStyle(color: Colors.white, fontSize: 16.sp),
              decoration: InputDecoration(
                hintText: _selectedPlatform.placeholder,
                hintStyle: TextStyle(
                  color: const Color(0xFF6B6B80),
                  fontSize: 14.sp,
                ),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                errorText: _error,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 12.w, right: 8.w),
                  child: Text(
                    _selectedPlatform.emoji,
                    style: TextStyle(fontSize: 20.sp),
                  ),
                ),
                prefixIconConstraints: BoxConstraints(minWidth: 40.w),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFF2A2A40)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFF2A2A40)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFF00FFB2)),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
                ),
              ),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),
            SizedBox(height: 24.h),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B6B80),
                      side: const BorderSide(color: Color(0xFF2A2A40)),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFB2),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final handle = _handleController.text.trim();

    if (handle.isEmpty) {
      setState(
        () =>
            _error =
                'Please enter your ${_selectedPlatform.displayName} handle',
      );
      return;
    }

    if (!_selectedPlatform.isValidHandle(handle)) {
      setState(
        () => _error = 'Invalid ${_selectedPlatform.displayName} format',
      );
      return;
    }

    final profile = SocialProfile(
      id:
          widget.existingProfile?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      platform: _selectedPlatform,
      handle: handle,
      isVerified: widget.existingProfile?.isVerified ?? false,
      addedAt: widget.existingProfile?.addedAt ?? DateTime.now(),
    );

    widget.onSave(profile);
    Navigator.pop(context);
  }
}
