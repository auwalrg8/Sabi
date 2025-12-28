import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/profile/presentation/screens/backup_recovery_screen.dart';
import 'package:sabi_wallet/features/profile/presentation/screens/settings_screen.dart';
import 'package:sabi_wallet/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/profile_service.dart';
import 'package:sabi_wallet/features/nostr/nostr_service.dart';
import 'package:sabi_wallet/features/nostr/nostr_edit_modal.dart';
import 'package:sabi_wallet/services/nostr/nostr_service.dart' as nostr_v2;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _editNostrKeys() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              NostrEditModal(initialNpub: _nostrNpub, onSaved: _loadNostrStats),
    );
  }

  UserProfile? _profile;
  bool _isLoading = true;
  bool _isSyncingLightning = false;
  String? _nostrNpub;
  int _zapCount = 0;
  int _zapTotal = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  int _relaysConnected = 0;
  bool _isLoadingNostr = true;
  nostr_v2.NostrProfile? _nostrProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadNostrStats();
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

  Future<void> _loadNostrStats() async {
    setState(() => _isLoadingNostr = true);
    try {
      await NostrService.init();
      final npub = await NostrService.getNpub();
      int zapCount = 0;
      int zapTotal = 0;
      int followers = 0;
      int following = 0;
      int relays = 0;
      nostr_v2.NostrProfile? profile;

      if (npub != null) {
        // Use new services to get real stats
        try {
          final profileService = nostr_v2.NostrProfileService();
          final relayPool = nostr_v2.RelayPoolManager();
          final feedAggregator = nostr_v2.FeedAggregator();

          // Get connected relay count
          relays = relayPool.connectedCount;

          // Get following count from feed aggregator
          following = feedAggregator.followsCount;

          // Get profile from new service
          profile = profileService.currentProfile;

          // Get zap stats from ZapService (if available)
          final zapService = nostr_v2.ZapService();
          final recentZaps = zapService.recentZapsReceived;
          zapCount = recentZaps.length;
          zapTotal = recentZaps.fold(0, (sum, zap) => sum + zap.amountSats);
        } catch (e) {
          debugPrint('⚠️ Could not load enhanced stats: $e');
        }
      }

      if (mounted) {
        setState(() {
          _nostrNpub = npub;
          _zapCount = zapCount;
          _zapTotal = zapTotal;
          _followersCount = followers;
          _followingCount = following;
          _relaysConnected = relays;
          _nostrProfile = profile;
          _isLoadingNostr = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading Nostr stats: $e');
      if (mounted) {
        setState(() => _isLoadingNostr = false);
      }
    }
  }

  Future<void> _createNostrAccount() async {
    try {
      final result = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text(
                'Create Nostr Identity',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18.sp),
              ),
              content: Text(
                'This will generate a new Nostr keypair. Make sure to backup your nsec (private key) securely - it cannot be recovered if lost!',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel', style: TextStyle(fontSize: 14.sp)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF7931A),
                  ),
                  child: Text(
                    'Create',
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  ),
                ),
              ],
            ),
      );

      if (result != true) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFF7931A)),
              ),
            ),
      );

      final keys = await NostrService.generateKeys();
      Navigator.pop(context); // Close loading

      // Show the generated keys for backup
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.accentGreen,
                    size: 24.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Nostr Identity Created!',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.sp,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '⚠️ BACKUP YOUR PRIVATE KEY!',
                      style: TextStyle(
                        color: AppColors.accentRed,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Public Key (npub):',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: SelectableText(
                        keys['npub'] ?? '',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11.sp,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Private Key (nsec) - KEEP SECRET:',
                      style: TextStyle(
                        color: AppColors.accentRed,
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: AppColors.accentRed.withValues(alpha: 0.3),
                        ),
                      ),
                      child: SelectableText(
                        keys['nsec'] ?? '',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11.sp,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Long press to copy each key. Store your nsec safely - it\'s the only way to access your Nostr identity!',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF7931A),
                  ),
                  child: Text(
                    'I\'ve Backed Up My Keys',
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  ),
                ),
              ],
            ),
      );

      await _loadNostrStats();
    } catch (e) {
      Navigator.pop(context); // Close loading if still showing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create Nostr identity: $e',
            style: TextStyle(color: AppColors.surface),
          ),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }

  Widget _buildNostrIdentityCard() {
    if (_isLoadingNostr) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFFF7931A)),
          ),
        ),
      );
    }

    final hasNostr = _nostrNpub != null && _nostrNpub!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFF7931A).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.electric_bolt,
                color: const Color(0xFFF7931A),
                size: 24.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'Nostr Identity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (hasNostr)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'Connected',
                    style: TextStyle(
                      color: AppColors.accentGreen,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),

          if (hasNostr) ...[
            // Profile name if available
            if (_nostrProfile?.name != null ||
                _nostrProfile?.displayName != null) ...[
              Text(
                _nostrProfile?.displayName ?? _nostrProfile?.name ?? '',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
            ],

            // npub display
            Text(
              'Public Key:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11.sp),
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _nostrNpub!.length > 30
                          ? '${_nostrNpub!.substring(0, 15)}...${_nostrNpub!.substring(_nostrNpub!.length - 10)}'
                          : _nostrNpub!,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12.sp,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _editNostrKeys,
                    child: Icon(
                      Icons.edit,
                      color: const Color(0xFFF7931A),
                      size: 18.sp,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Connection status
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color:
                    _relaysConnected > 0
                        ? AppColors.accentGreen.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color:
                      _relaysConnected > 0
                          ? AppColors.accentGreen.withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6.w,
                    height: 6.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          _relaysConnected > 0
                              ? AppColors.accentGreen
                              : Colors.orange,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    _relaysConnected > 0
                        ? '$_relaysConnected relays connected'
                        : 'Connecting...',
                    style: TextStyle(
                      color:
                          _relaysConnected > 0
                              ? AppColors.accentGreen
                              : Colors.orange,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Stats grid - now with 4 stats
            Row(
              children: [
                _StatBadge(
                  icon: Icons.electric_bolt,
                  label: 'Zaps',
                  value: _zapCount.toString(),
                ),
                SizedBox(width: 8.w),
                _StatBadge(
                  icon: Icons.bolt,
                  label: 'Sats',
                  value: _formatSats(_zapTotal),
                ),
                SizedBox(width: 8.w),
                _StatBadge(
                  icon: Icons.people_outline,
                  label: 'Following',
                  value: _followingCount.toString(),
                ),
                if (_followersCount > 0) ...[
                  SizedBox(width: 8.w),
                  _StatBadge(
                    icon: Icons.person_add_outlined,
                    label: 'Followers',
                    value: _followersCount.toString(),
                  ),
                ],
              ],
            ),
          ] else ...[
            // No Nostr identity
            Text(
              'Connect to the decentralized social network. Send and receive zaps, post notes, and more!',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _createNostrAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF7931A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text(
                      'Create New',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _editNostrKeys,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: const Color(0xFFF7931A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text(
                      'Import Keys',
                      style: TextStyle(
                        color: const Color(0xFFF7931A),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
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

  // ignore: unused_element
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

  // ignore: unused_element
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
    // ignore: unused_local_variable
    final address = profile.sabiUsername;
    final statusText =
        registered ? 'Lightning address is set' : 'Lightning address not set';
    // final button =
    //     registered
    //         ? OutlinedButton(
    //           onPressed: _isSyncingLightning ? null : _refreshLightningAddress,
    //           style: OutlinedButton.styleFrom(
    //             side: const BorderSide(color: AppColors.primary),
    //             shape: RoundedRectangleBorder(
    //               borderRadius: BorderRadius.circular(16.r),
    //             ),
    //             padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10.w),
    //           ),
    //           child: Text(
    //             _isSyncingLightning
    //                 ? 'Refreshing…'
    //                 : 'Refresh Lightning address',
    //             style: TextStyle(
    //               color: AppColors.primary,
    //               fontSize: 14.sp,
    //               fontWeight: FontWeight.w500,
    //             ),
    //           ),
    //         )
    //         : ElevatedButton(
    //           onPressed: _isSyncingLightning ? null : _registerLightningAddress,
    //           style: ElevatedButton.styleFrom(
    //             backgroundColor: AppColors.primary,
    //             shape: RoundedRectangleBorder(
    //               borderRadius: BorderRadius.circular(16.r),
    //             ),
    //             padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
    //           ),
    //           child: Text(
    //             _isSyncingLightning
    //                 ? 'Registering…'
    //                 : 'Register Lightning address',
    //             style: TextStyle(
    //               color: Colors.white,
    //               fontSize: 14.sp,
    //               fontWeight: FontWeight.w500,
    //             ),
    //           ),
    //         );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb,
                color: registered ? AppColors.accentGreen : AppColors.primary,
                size: 20.sp,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Inter',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.w),
          // Text(
          //   address,
          //   style: TextStyle(
          //     color: AppColors.textSecondary,
          //     fontFamily: 'Inter',
          //     fontSize: 12.sp,
          //   ),
          // ),
          // SizedBox(height: 6.h),
          // Text(
          //   profile.lightningAddressDescription,
          //   style: TextStyle(color: AppColors.textTertiary, fontSize: 12.sp),
          // ),
          // if (profile.lightningAddress?.lnurl != null) ...[
          //   SizedBox(height: 6.h),
          //   Text(
          //     'LNURL: ${profile.lightningAddress!.lnurl}',
          //     style: TextStyle(color: AppColors.textTertiary, fontSize: 10.sp),
          //     maxLines: 1,
          //     overflow: TextOverflow.ellipsis,
          //   ),
          // ],
          // SizedBox(height: 12.sp),
          // button,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use placeholder profile during loading for skeleton
    final profile =
        _profile ??
        UserProfile(fullName: 'Loading User', username: 'loading_user');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Skeletonizer(
          enabled: _isLoading,
          enableSwitchAnimation: true,
          containersColor: AppColors.surface,
          effect: PulseEffect(
            duration: const Duration(milliseconds: 1000),
            from: AppColors.background,
            to: AppColors.borderColor.withValues(alpha: 0.3),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(30.w, 10.h, 30.w, 30.h),
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
                  SizedBox(height: 15.h),

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
                        SizedBox(height: 12.h),
                        _buildLightningAddressCard(profile),
                        SizedBox(height: 12.h),
                        // Nostr Identity Card
                        _buildNostrIdentityCard(),
                        SizedBox(height: 24.h),
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
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
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
      ),
    );
  }

  /// Format sats for display (e.g., 1000 -> 1k, 1000000 -> 1M)
  String _formatSats(int sats) {
    if (sats >= 1000000) {
      return '${(sats / 1000000).toStringAsFixed(1)}M';
    } else if (sats >= 1000) {
      return '${(sats / 1000).toStringAsFixed(1)}k';
    }
    return sats.toString();
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

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFF7931A), size: 14.sp),
                SizedBox(width: 4.w),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10.sp),
            ),
          ],
        ),
      ),
    );
  }
}
