import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/profile/presentation/screens/backup_recovery_screen.dart';
import 'package:sabi_wallet/features/profile/presentation/screens/settings_screen.dart';
import 'package:sabi_wallet/features/nostr/services/nostr_service.dart';
import 'package:sabi_wallet/features/nostr/presentation/widgets/nostr_edit_modal.dart';
import 'package:sabi_wallet/services/nostr/nostr_service.dart' as nostr_v2;
import 'package:sabi_wallet/features/nostr/presentation/widgets/nostr_onboarding_screen.dart';
import 'package:sabi_wallet/features/wallet/presentation/widgets/edit_lightning_address_modal.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Loading states
  bool _isLoading = true;
  bool _isUpdatingProfile = false;

  // Nostr data
  String? _nostrNpub;
  String? _nostrNsec;
  bool _showNsec = false;
  nostr_v2.NostrProfile? _nostrProfile;

  // Stats
  int _zapCount = 0;
  int _relaysConnected = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadProfile() async {
    // Fast path: Use quick cache for instant display, then load full profile
    try {
      await NostrService.init();
      final npub = await NostrService.getNpub();
      final nsec = await NostrService.getNsec();

      // Immediately set keys and show quick cached data
      if (mounted) {
        setState(() {
          _nostrNpub = npub;
          _nostrNsec = nsec;
        });
      }

      nostr_v2.NostrProfile? profile;
      int relays = 0;

      if (npub != null) {
        final profileService = nostr_v2.NostrProfileService();
        final relayPool = nostr_v2.RelayPoolManager();

        // Force reinit to pick up any newly created/imported keys
        await profileService.init(force: true);

        // Use quick cache for instant display (name + picture)
        final quickName = nostr_v2.NostrProfileService.cachedDisplayName;
        // quickPicture is used via NostrProfileService.cachedPicture in build()

        // Try full cached profile
        profile = profileService.currentProfile;
        relays = relayPool.connectedCount;

        // Show UI immediately with whatever data we have
        if (mounted) {
          if (profile != null) {
            setState(() {
              _nostrProfile = profile;
              _relaysConnected = relays;
              _isLoading = false;
            });
          } else if (quickName != null) {
            // Create a minimal profile from quick cache for instant display
            setState(() {
              _isLoading = false;
            });
          }
        }

        // Fetch fresh profile in background
        _refreshProfileFromNetwork(npub, profileService, relayPool);
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshProfileFromNetwork(
    String npub,
    nostr_v2.NostrProfileService profileService,
    nostr_v2.RelayPoolManager relayPool,
  ) async {
    try {
      final hexPubkey = nostr_v2.NostrProfileService.npubToHex(npub);
      if (hexPubkey == null) return;

      // Fetch fresh profile from relays
      final freshProfile = await profileService.fetchProfile(hexPubkey);

      // Get zap stats
      final zapService = nostr_v2.ZapService();
      final recentZaps = zapService.recentZapsReceived;
      final zapCount = recentZaps.length;

      if (mounted && freshProfile != null) {
        setState(() {
          _nostrProfile = freshProfile;
          _zapCount = zapCount;
          _relaysConnected = relayPool.connectedCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Background profile refresh failed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editNostrKeys() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => NostrEditModal(
            initialNpub: _nostrNpub,
            onSaved: () async {
              await _loadProfile();
            },
          ),
    );
    if (result == true) {
      await _loadProfile();
    }
  }

  Future<void> _showEditProfileModal() async {
    if (_nostrNpub == null) return;

    final nameController = TextEditingController(
      text: _nostrProfile?.displayName ?? _nostrProfile?.name ?? '',
    );
    final usernameController = TextEditingController(
      text: _nostrProfile?.name ?? '',
    );
    final bioController = TextEditingController(
      text: _nostrProfile?.about ?? '',
    );
    String? tempImageUrl = _nostrProfile?.picture;
    Uint8List? selectedImageBytes;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24.r),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 12.h),
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: AppColors.borderColor,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                            Text(
                              'Edit Profile',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  _isUpdatingProfile
                                      ? null
                                      : () async {
                                        setModalState(
                                          () => _isUpdatingProfile = true,
                                        );
                                        try {
                                          String? pictureUrl = tempImageUrl;

                                          // Upload new image if selected
                                          if (selectedImageBytes != null) {
                                            final profileService =
                                                nostr_v2.NostrProfileService();
                                            pictureUrl = await profileService
                                                .uploadImageBytes(
                                                  selectedImageBytes!,
                                                  'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                                );
                                          }

                                          // Update profile on Nostr
                                          final profileService =
                                              nostr_v2.NostrProfileService();
                                          final success = await profileService
                                              .updateProfile(
                                                name:
                                                    usernameController.text
                                                        .trim(),
                                                displayName:
                                                    nameController.text.trim(),
                                                about:
                                                    bioController.text.trim(),
                                                picture: pictureUrl,
                                              );

                                          if (success && mounted) {
                                            Navigator.pop(context, true);
                                          } else if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Failed to update profile',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (mounted) {
                                            setModalState(
                                              () => _isUpdatingProfile = false,
                                            );
                                          }
                                        }
                                      },
                              child:
                                  _isUpdatingProfile
                                      ? SizedBox(
                                        width: 16.w,
                                        height: 16.w,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            Color(0xFFF7931A),
                                          ),
                                        ),
                                      )
                                      : Text(
                                        'Save',
                                        style: TextStyle(
                                          color: const Color(0xFFF7931A),
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                            ),
                          ],
                        ),
                      ),

                      Divider(color: AppColors.borderColor, height: 1),

                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(20.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar
                              GestureDetector(
                                onTap: () async {
                                  final picker = ImagePicker();
                                  final image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 512,
                                    maxHeight: 512,
                                    imageQuality: 85,
                                  );
                                  if (image != null) {
                                    final bytes = await image.readAsBytes();
                                    setModalState(() {
                                      selectedImageBytes = bytes;
                                      tempImageUrl = null;
                                    });
                                  }
                                },
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 100.w,
                                      height: 100.w,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7931A),
                                        shape: BoxShape.circle,
                                        image:
                                            selectedImageBytes != null
                                                ? DecorationImage(
                                                  image: MemoryImage(
                                                    selectedImageBytes!,
                                                  ),
                                                  fit: BoxFit.cover,
                                                )
                                                : tempImageUrl != null
                                                ? DecorationImage(
                                                  image: NetworkImage(
                                                    tempImageUrl!,
                                                  ),
                                                  fit: BoxFit.cover,
                                                )
                                                : null,
                                      ),
                                      child:
                                          (selectedImageBytes == null &&
                                                  tempImageUrl == null)
                                              ? Center(
                                                child: Icon(
                                                  Icons.person,
                                                  size: 48.sp,
                                                  color: Colors.white,
                                                ),
                                              )
                                              : null,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: EdgeInsets.all(8.w),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF7931A),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.surface,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.camera_alt,
                                          size: 16.sp,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Tap to change photo',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12.sp,
                                ),
                              ),

                              SizedBox(height: 24.h),

                              // Display Name
                              _buildEditField(
                                label: 'Display Name',
                                controller: nameController,
                                hint: 'Your display name',
                              ),
                              SizedBox(height: 16.h),

                              // Username
                              _buildEditField(
                                label: 'Username',
                                controller: usernameController,
                                hint: 'username',
                                prefix: '@',
                              ),
                              SizedBox(height: 16.h),

                              // Bio
                              _buildEditField(
                                label: 'Bio',
                                controller: bioController,
                                hint: 'Tell the world about yourself...',
                                maxLines: 3,
                              ),

                              SizedBox(height: 24.h),

                              // Info
                              Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppColors.textSecondary,
                                      size: 20.sp,
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Text(
                                        'Your profile will be published to Nostr relays and visible to everyone.',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );

    if (result == true) {
      await _loadProfile();
    }
  }

  Widget _buildEditField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? prefix,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 14.sp,
              ),
              prefixText: prefix,
              prefixStyle: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 14.h,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showNostrOnboarding() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const NostrOnboardingScreen(),
        fullscreenDialog: true,
      ),
    );
    if (result == true) {
      await _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNostr = _nostrNpub != null && _nostrNpub!.isNotEmpty;
    // Use quick cache as fallback for instant display
    final displayName =
        _nostrProfile?.displayName ??
        _nostrProfile?.name ??
        nostr_v2.NostrProfileService.cachedDisplayName ??
        'Anonymous';
    final username = _nostrProfile?.name;
    final bio = _nostrProfile?.about;
    final picture =
        _nostrProfile?.picture ?? nostr_v2.NostrProfileService.cachedPicture;
    final banner = _nostrProfile?.banner;
    final lightningAddress = _nostrProfile?.lud16;

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
            child: Column(
              children: [
                // Header with banner image or gradient background
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Banner image or gradient
                    Container(
                      width: double.infinity,
                      height: 140.h,
                      decoration: BoxDecoration(
                        gradient:
                            banner == null
                                ? LinearGradient(
                                  colors: [
                                    const Color(0xFF1A1A2E),
                                    AppColors.background,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                                : null,
                        image:
                            banner != null
                                ? DecorationImage(
                                  image: NetworkImage(banner),
                                  fit: BoxFit.cover,
                                )
                                : null,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.background.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    // Top bar (positioned over banner)
                    Positioned(
                      top: 10.h,
                      left: 20.w,
                      right: 20.w,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: EdgeInsets.all(8.w),
                                  decoration: BoxDecoration(
                                    color: AppColors.background.withValues(
                                      alpha: 0.7,
                                    ),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Icon(
                                    Icons.arrow_back,
                                    color: AppColors.textPrimary,
                                    size: 20.w,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                'Profile',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w700,
                                  shadows:
                                      banner != null
                                          ? [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 4,
                                            ),
                                          ]
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          if (hasNostr)
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.background.withValues(
                                  alpha: 0.7,
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: IconButton(
                                onPressed: _showEditProfileModal,
                                icon: Icon(
                                  Icons.edit,
                                  color: const Color(0xFFF7931A),
                                  size: 22.sp,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Profile content (overlaps banner slightly)
                Transform.translate(
                  offset: Offset(0, -30.h),
                  child: Column(
                    children: [
                      SizedBox(height: 20.h),

                      // Avatar
                      Container(
                        width: 100.w,
                        height: 100.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7931A),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFFF7931A,
                            ).withValues(alpha: 0.3),
                            width: 3,
                          ),
                          image:
                              picture != null
                                  ? DecorationImage(
                                    image: NetworkImage(picture),
                                    fit: BoxFit.cover,
                                  )
                                  : null,
                        ),
                        child:
                            picture == null
                                ? Center(
                                  child: Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 40.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                                : null,
                      ),

                      SizedBox(height: 16.h),

                      // Display Name
                      Text(
                        displayName,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      // Username
                      if (username != null && username.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          '@$username',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],

                      // Bio - show full text
                      if (bio != null && bio.isNotEmpty) ...[
                        SizedBox(height: 12.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          child: Text(
                            bio,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14.sp,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],

                      SizedBox(height: 20.h),

                      // Stats Row - Only Zaps and Relays
                      if (hasNostr)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40.w),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem('Zaps', _zapCount.toString()),
                              _buildStatDivider(),
                              _buildStatItem(
                                'Relays',
                                _relaysConnected.toString(),
                              ),
                            ],
                          ),
                        ),

                      SizedBox(height: 24.h),
                    ],
                  ),
                ),

                // Content (adjust for the transform)
                Transform.translate(
                  offset: Offset(0, -30.h),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      children: [
                        // Nostr Identity Section
                        if (!hasNostr) ...[
                          _buildSetupNostrCard(),
                          SizedBox(height: 16.h),
                        ] else ...[
                          _buildNostrIdentityCard(),
                          SizedBox(height: 16.h),

                          // Lightning Address Section
                          _buildLightningAddressCard(lightningAddress),
                          SizedBox(height: 16.h),
                        ],

                        // Menu Items
                        _MenuItemTile(
                          icon: Icons.settings_outlined,
                          iconColor: AppColors.primary,
                          title: 'Settings',
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              ),
                        ),
                        SizedBox(height: 12.h),

                        _MenuItemTile(
                          icon: Icons.shield_outlined,
                          iconColor: AppColors.accentYellow,
                          title: 'Backup & Recovery',
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BackupRecoveryScreen(),
                                ),
                              ),
                        ),

                        SizedBox(height: 30.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 30.h, width: 1, color: AppColors.borderColor);
  }

  Widget _buildSetupNostrCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
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
        children: [
          Icon(
            Icons.electric_bolt,
            color: const Color(0xFFF7931A),
            size: 48.sp,
          ),
          SizedBox(height: 16.h),
          Text(
            'Setup Your Nostr Identity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Connect to the decentralized social network. Send zaps, post notes, and own your identity.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _showNostrOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF7931A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  child: Text(
                    'Get Started',
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
                    side: const BorderSide(color: Color(0xFFF7931A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
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
      ),
    );
  }

  Widget _buildNostrIdentityCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
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
                Icons.electric_bolt,
                color: const Color(0xFFF7931A),
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'Nostr Identity',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: BoxDecoration(
                        color:
                            _relaysConnected > 0
                                ? AppColors.accentGreen
                                : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      _relaysConnected > 0 ? 'Connected' : 'Connecting',
                      style: TextStyle(
                        color:
                            _relaysConnected > 0
                                ? AppColors.accentGreen
                                : Colors.orange,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // npub
          Text(
            'Public Key',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11.sp),
          ),
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _nostrNpub!.length > 24
                        ? '${_nostrNpub!.substring(0, 12)}...${_nostrNpub!.substring(_nostrNpub!.length - 8)}'
                        : _nostrNpub!,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.sp,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _nostrNpub!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Public key copied!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.copy,
                    color: const Color(0xFFF7931A),
                    size: 18.sp,
                  ),
                ),
              ],
            ),
          ),

          // nsec (hidden by default)
          if (_nostrNsec != null && _nostrNsec!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            GestureDetector(
              onTap: () => setState(() => _showNsec = !_showNsec),
              child: Row(
                children: [
                  Text(
                    'Private Key',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.sp,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showNsec ? Icons.visibility_off : Icons.visibility,
                    color: Colors.orange,
                    size: 16.sp,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    _showNsec ? 'Hide' : 'Show',
                    style: TextStyle(color: Colors.orange, fontSize: 11.sp),
                  ),
                ],
              ),
            ),
            if (_showNsec) ...[
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red, size: 14.sp),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        'Never share your private key!',
                        style: TextStyle(
                          color: Colors.red[300],
                          fontSize: 10.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _nostrNsec!.length > 24
                            ? '${_nostrNsec!.substring(0, 12)}...${_nostrNsec!.substring(_nostrNsec!.length - 8)}'
                            : _nostrNsec!,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12.sp,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _nostrNsec!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Private key copied! Keep it safe!'),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Icon(
                        Icons.copy,
                        color: Colors.orange,
                        size: 18.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          SizedBox(height: 12.h),

          // Edit Keys button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _editNostrKeys,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 10.h),
              ),
              child: Text(
                'Manage Keys',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightningAddressCard(String? currentAddress) {
    // Try to get address from Breez SDK first, then from Nostr profile
    final breezAddress = BreezSparkService.lightningAddressDetails?.address;
    final displayAddress = breezAddress ?? currentAddress;
    final hasAddress = displayAddress != null && displayAddress.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border:
            hasAddress
                ? Border.all(color: AppColors.accentGreen.withOpacity(0.3))
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.bolt, color: AppColors.primary, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lightning Address',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      hasAddress ? displayAddress : 'Setting up...',
                      style: TextStyle(
                        color:
                            hasAddress
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasAddress) ...[
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: displayAddress));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lightning address copied!'),
                        backgroundColor: AppColors.accentGreen,
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.copy_rounded,
                    color: AppColors.primary,
                    size: 20.sp,
                  ),
                  tooltip: 'Copy',
                ),
                IconButton(
                  onPressed: () => _showEditLightningAddressModalNew(),
                  icon: Icon(
                    Icons.edit_rounded,
                    color: AppColors.textSecondary,
                    size: 20.sp,
                  ),
                  tooltip: 'Edit',
                ),
              ],
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            hasAddress
                ? 'Share this address to receive Bitcoin instantly'
                : 'Your lightning address is being set up automatically...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
          ),
          if (!hasAddress) ...[
            SizedBox(height: 8.h),
            LinearProgressIndicator(
              backgroundColor: AppColors.surface,
              color: AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEditLightningAddressModalNew() async {
    final currentUsername =
        BreezSparkService.lightningAddressDetails?.username ?? '';
    final hasExisting = BreezSparkService.lightningAddressDetails != null;

    final result = await showEditLightningAddressModal(
      context: context,
      currentUsername: currentUsername,
      hasExistingAddress: hasExisting,
    );

    if (result == true) {
      // Refresh profile data
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lightning address updated!'),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22.sp),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 22.sp,
            ),
          ],
        ),
      ),
    );
  }
}
