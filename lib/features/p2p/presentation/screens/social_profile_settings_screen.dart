/// Social Profile Settings Screen - Manage linked social accounts
///
/// Allows users to add, edit, and remove their social profiles
/// that can be optionally shared during P2P trades.
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../data/models/social_profile_model.dart';
import '../widgets/social_profile_widget.dart';

class SocialProfileSettingsScreen extends StatefulWidget {
  const SocialProfileSettingsScreen({super.key});

  @override
  State<SocialProfileSettingsScreen> createState() =>
      _SocialProfileSettingsScreenState();
}

class _SocialProfileSettingsScreenState
    extends State<SocialProfileSettingsScreen> {
  bool _isLoading = true;
  bool _sharingEnabled = true;
  List<SocialProfile> _profiles = [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    await SocialProfileService.init();
    setState(() {
      _profiles = SocialProfileService.getProfiles();
      _sharingEnabled = SocialProfileService.isSharingEnabled;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.arrow_back, color: Colors.white, size: 20.sp),
          ),
        ),
        title: Text(
          'Trust Profiles',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Card
                    _buildInfoCard(),
                    SizedBox(height: 24.h),

                    // Global Toggle
                    _buildGlobalToggle(),
                    SizedBox(height: 24.h),

                    // Linked Profiles Section
                    _buildLinkedProfilesSection(),
                    SizedBox(height: 24.h),

                    // Add More Section
                    _buildAddMoreSection(),
                    SizedBox(height: 24.h),

                    // Privacy Notice
                    _buildPrivacyNotice(),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF7931A).withValues(alpha: 0.1),
            const Color(0xFF0D1421),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFF7931A).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7931A).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.handshake_outlined,
                  color: const Color(0xFFF7931A),
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Build Trust Without KYC',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'Link your social profiles to optionally share them with trading partners. '
            'This builds trust without requiring identity verification.',
            style: TextStyle(
              color: const Color(0xFFA1A1B2),
              fontSize: 13.sp,
              height: 1.5,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              _buildFeatureBadge('🔒 Optional'),
              SizedBox(width: 8.w),
              _buildFeatureBadge('👥 Consent-based'),
              SizedBox(width: 8.w),
              _buildFeatureBadge('🗑️ Not stored'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        text,
        style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 10.sp),
      ),
    );
  }

  Widget _buildGlobalToggle() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable Profile Sharing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _sharingEnabled
                      ? 'Others can request to see your profiles'
                      : 'Profile sharing is disabled',
                  style: TextStyle(
                    color: const Color(0xFF6B6B80),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _sharingEnabled,
            onChanged: (value) async {
              await SocialProfileService.setSharingEnabled(value);
              setState(() => _sharingEnabled = value);
            },
            activeColor: const Color(0xFF00FFB2),
            activeTrackColor: const Color(0xFF00FFB2).withValues(alpha: 0.3),
            inactiveThumbColor: const Color(0xFF6B6B80),
            inactiveTrackColor: const Color(0xFF2A2A40),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedProfilesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Linked Profiles',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: const Color(0xFF00FFB2).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                '${_profiles.length}',
                style: TextStyle(
                  color: const Color(0xFF00FFB2),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        if (_profiles.isEmpty)
          _buildEmptyState()
        else
          ..._profiles.map(
            (profile) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: SocialProfileCard(
                profile: profile,
                onEdit: () => _showAddEditDialog(existingProfile: profile),
                onRemove: () => _confirmRemoveProfile(profile),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFF2A2A40),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_add_outlined,
            color: const Color(0xFF6B6B80),
            size: 48.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            'No Profiles Linked',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Add your social profiles to build trust with trading partners',
            textAlign: TextAlign.center,
            style: TextStyle(color: const Color(0xFF6B6B80), fontSize: 13.sp),
          ),
          SizedBox(height: 16.h),
          ElevatedButton.icon(
            onPressed: () => _showAddEditDialog(),
            icon: Icon(Icons.add, size: 18.sp),
            label: const Text('Add Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF7931A),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMoreSection() {
    if (_profiles.isEmpty) return const SizedBox.shrink();

    // Find platforms not yet linked
    final linkedPlatforms = _profiles.map((p) => p.platform).toSet();
    final availablePlatforms =
        SocialPlatform.values
            .where((p) => !linkedPlatforms.contains(p))
            .toList();

    if (availablePlatforms.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF00FFB2).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: const Color(0xFF00FFB2).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: const Color(0xFF00FFB2),
              size: 24.sp,
            ),
            SizedBox(width: 12.w),
            Text(
              'All platforms linked!',
              style: TextStyle(
                color: const Color(0xFF00FFB2),
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add More',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          children:
              availablePlatforms.map((platform) {
                return GestureDetector(
                  onTap: () => _showAddEditDialog(initialPlatform: platform),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFF2A2A40)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(platform.emoji, style: TextStyle(fontSize: 18.sp)),
                        SizedBox(width: 8.w),
                        Text(
                          platform.displayName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.add_circle_outline,
                          color: const Color(0xFF6B6B80),
                          size: 16.sp,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1421),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                color: const Color(0xFF00FFB2),
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'Privacy & Security',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildPrivacyItem(
            Icons.storage_outlined,
            'Stored locally on your device only',
          ),
          SizedBox(height: 8.h),
          _buildPrivacyItem(
            Icons.visibility_off_outlined,
            'Never visible on your public profile or offers',
          ),
          SizedBox(height: 8.h),
          _buildPrivacyItem(
            Icons.handshake_outlined,
            'Only shared when you explicitly consent',
          ),
          SizedBox(height: 8.h),
          _buildPrivacyItem(
            Icons.timer_outlined,
            'Shared only during active trades, then hidden',
          ),
          SizedBox(height: 8.h),
          _buildPrivacyItem(
            Icons.cancel_outlined,
            'You can revoke access anytime during a trade',
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6B6B80), size: 16.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 12.sp),
          ),
        ),
      ],
    );
  }

  void _showAddEditDialog({
    SocialPlatform? initialPlatform,
    SocialProfile? existingProfile,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AddProfileDialog(
            initialPlatform: initialPlatform,
            existingProfile: existingProfile,
            onSave: (profile) async {
              await SocialProfileService.setProfile(profile);
              await _loadProfiles();
            },
          ),
    );
  }

  void _confirmRemoveProfile(SocialProfile profile) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Text(
              'Remove ${profile.platform.displayName}?',
              style: TextStyle(color: Colors.white, fontSize: 18.sp),
            ),
            content: Text(
              'This will remove your ${profile.platform.displayName} profile from your trust profiles.',
              style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: const Color(0xFF6B6B80),
                    fontSize: 14.sp,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await SocialProfileService.removeProfile(profile.platform);
                  await _loadProfiles();
                },
                child: Text(
                  'Remove',
                  style: TextStyle(
                    color: const Color(0xFFFF6B6B),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
