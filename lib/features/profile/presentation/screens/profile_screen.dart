import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/profile/presentation/screens/backup_recovery_screen.dart';
import 'package:sabi_wallet/features/profile/presentation/screens/settings_screen.dart';
import 'package:sabi_wallet/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isSyncingLightning = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile = await ProfileService.getProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToEditProfile() async {
    if (_profile == null) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(currentProfile: _profile!),
      ),
    );

    if (result == true) {
      _loadProfile(); // Reload profile after edit
    }
  }

  Future<void> _switchWallet() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Switch Wallet?', style: TextStyle(fontSize: 18.sp)),
            content: Text(
              'This will take you back to the wallet selection screen. Your wallet data will remain secure.',
              style: TextStyle(fontSize: 14.sp),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(fontSize: 14.sp)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Switch',
                  style: TextStyle(color: Colors.red, fontSize: 14.sp),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/splash', (route) => false);
    }
  }


  Future<void> _refreshProfileSilently() async {
    final profile = await ProfileService.getProfile();
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  Future<void> _registerLightningAddress() async {
    if (_profile == null || _isSyncingLightning) return;
    setState(() => _isSyncingLightning = true);
    try {
      await BreezSparkService.registerLightningAddress(
        username: _profile!.username,
        description: _profile!.lightningAddressDescription,
      );
      await BreezSparkService.fetchLightningAddress();
      await _refreshProfileSilently();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lightning address registered successfully'),
          backgroundColor: AppColors.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to register address: $e'),
          backgroundColor: AppColors.surface,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncingLightning = false);
    }
  }

  Future<void> _refreshLightningAddress() async {
    if (_profile == null || _isSyncingLightning) return;
    setState(() => _isSyncingLightning = true);
    try {
      await BreezSparkService.fetchLightningAddress();
      await _refreshProfileSilently();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lightning address refreshed'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh address: $e'),
          backgroundColor: AppColors.surface,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncingLightning = false);
    }
  }
  
  Widget _buildLightningAddressCard(UserProfile profile) {
    final registered = profile.hasLightningAddress;
    final address = profile.sabiUsername;
    final statusText = registered
        ? 'Lightning address registered'
        : 'Lightning address not yet claimed';
    final button = registered
        ? OutlinedButton(
            onPressed: _isSyncingLightning ? null : _refreshLightningAddress,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _isSyncingLightning ? 'Refreshing…' : 'Refresh Lightning address',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        : ElevatedButton(
            onPressed: _isSyncingLightning ? null : _registerLightningAddress,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _isSyncingLightning ? 'Registering…' : 'Register Lightning address',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb,
                color: registered ? AppColors.accentGreen : AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            address,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Inter',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            profile.lightningAddressDescription,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
          if (profile.lightningAddress?.lnurl != null) ...[
            const SizedBox(height: 6),
            Text(
              'LNURL: ${profile.lightningAddress!.lnurl}',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          button,
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final profile = _profile!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(30.w, 30.h, 30.w, 30.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Inter',
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 30.h),

                // Profile Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 32.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        width: 80.w,
                        height: 80.w,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          image:
                              profile.profilePicturePath != null
                                  ? DecorationImage(
                                    image: FileImage(
                                      File(profile.profilePicturePath!),
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                  : null,
                        ),
                        child:
                            profile.profilePicturePath == null
                                ? Center(
                                  child: Text(
                                    profile.initial,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Inter',
                                      fontSize: 32.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                                : null,
                      ),
                      SizedBox(height: 16.h),

                      // Name
                      Text(
                        profile.fullName,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'Inter',
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8.h),

                      // Username
                      Text(
                        profile.sabiUsername,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildLightningAddressCard(profile),
                      const SizedBox(height: 24),
                      // Edit Profile Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _navigateToEditProfile,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColors.primary,
                              width: 1.w,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                          ),
                          child: Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontFamily: 'Inter',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24.h),

                // Menu Items
                _MenuItemTile(
                  icon: Icons.settings_outlined,
                  iconColor: AppColors.primary,
                  title: 'Settings',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                SizedBox(height: 12.h),

                _MenuItemTile(
                  icon: Icons.shield_outlined,
                  iconColor: AppColors.accentYellow,
                  title: 'Backup & Recovery',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BackupRecoveryScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 12.h),

                _MenuItemTile(
                  icon: Icons.people_outline,
                  iconColor: AppColors.accentGreen,
                  title: 'Agent Mode',
                  onTap: () {},
                ),
                SizedBox(height: 12.h),

                _MenuItemTile(
                  icon: Icons.card_giftcard_outlined,
                  iconColor: AppColors.accentRed,
                  title: 'Earn Rewards',
                  onTap: () {},
                ),
                SizedBox(height: 12.h),

                _MenuItemTile(
                  icon: Icons.swap_horiz,
                  iconColor: Colors.orange,
                  title: 'Switch Wallet',
                  onTap: _switchWallet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _MenuItemTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24.sp),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 24.sp,
            ),
          ],
        ),
      ),
    );
  }
}
