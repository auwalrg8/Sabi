import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/constants/lightning_address.dart';
import 'package:sabi_wallet/features/profile/presentation/screens/backup_recovery_screen.dart';
import 'package:sabi_wallet/features/profile/presentation/screens/settings_screen.dart';
import 'package:sabi_wallet/features/nostr/nostr_service.dart';
import 'package:sabi_wallet/features/nostr/nostr_edit_modal.dart';
import 'package:sabi_wallet/services/nostr/nostr_service.dart' as nostr_v2;
import 'package:sabi_wallet/features/nostr/widgets/nostr_onboarding_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Loading states
  bool _isLoading = true;
  bool _isUpdatingProfile = false;
  bool _isClaimingLightningAddress = false;

  // Nostr data
  String? _nostrNpub;
  String? _nostrNsec;
  bool _showNsec = false;
  nostr_v2.NostrProfile? _nostrProfile;

  // Stats
  int _zapCount = 0;
  int _relaysConnected = 0;

  // Lightning address claiming
  final _usernameController = TextEditingController();
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    // Fast path: Load cached data first, then refresh from network
    try {
      await NostrService.init();
      final npub = await NostrService.getNpub();
      final nsec = await NostrService.getNsec();

      // Immediately set keys and show cached profile
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

        // Try cached profile first (instant)
        profile = profileService.currentProfile;
        relays = relayPool.connectedCount;

        // Show cached immediately if available
        if (profile != null && mounted) {
          setState(() {
            _nostrProfile = profile;
            _relaysConnected = relays;
            _isLoading = false;
          });

          // Pre-fill username
          if (profile.name != null && _usernameController.text.isEmpty) {
            _usernameController.text = profile.name!.toLowerCase().replaceAll(
              ' ',
              '',
            );
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

        // Pre-fill username
        if (freshProfile.name != null && _usernameController.text.isEmpty) {
          _usernameController.text = freshProfile.name!
              .toLowerCase()
              .replaceAll(' ', '');
        }
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

  Future<void> _claimLightningAddress() async {
    final username = _usernameController.text.trim().toLowerCase();

    if (username.isEmpty) {
      setState(() => _usernameError = 'Please enter a username');
      return;
    }

    if (username.length < 3) {
      setState(() => _usernameError = 'Username must be at least 3 characters');
      return;
    }

    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      setState(
        () =>
            _usernameError =
                'Only lowercase letters, numbers, and underscore allowed',
      );
      return;
    }

    setState(() {
      _usernameError = null;
      _isClaimingLightningAddress = true;
    });

    try {
      // Update Nostr profile with lud16
      final profileService = nostr_v2.NostrProfileService();
      final lightningAddress = formatLightningAddress(username);

      final success = await profileService.updateProfile(
        lud16: lightningAddress,
        name: _nostrProfile?.name ?? username,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lightning address claimed: $lightningAddress'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
        await _loadProfile();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to claim lightning address'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClaimingLightningAddress = false);
      }
    }
  }

  Future<void> _showEditLightningAddressModal(String currentAddress) async {
    // Extract username from address
    final currentUsername = currentAddress.split('@').first;
    final usernameController = TextEditingController(text: currentUsername);
    String? errorText;
    bool isUpdating = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24.r),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle
                        Center(
                          child: Container(
                            width: 40.w,
                            height: 4.h,
                            decoration: BoxDecoration(
                              color: AppColors.borderColor,
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),

                        // Title
                        Text(
                          'Edit Lightning Address',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Update your Lightning address on Nostr profile',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13.sp,
                          ),
                        ),
                        SizedBox(height: 20.h),

                        // Username input
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color:
                                  errorText != null
                                      ? Colors.red
                                      : AppColors.borderColor,
                            ),
                          ),
                          child: TextField(
                            controller: usernameController,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14.sp,
                            ),
                            decoration: InputDecoration(
                              hintText: 'username',
                              hintStyle: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 14.sp,
                              ),
                              suffixText: '@$lightningAddressDomain',
                              suffixStyle: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.sp,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 14.h,
                              ),
                            ),
                            onChanged: (_) {
                              if (errorText != null) {
                                setModalState(() => errorText = null);
                              }
                            },
                          ),
                        ),
                        if (errorText != null) ...[
                          SizedBox(height: 8.h),
                          Text(
                            errorText!,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                        SizedBox(height: 20.h),

                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context, false),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppColors.borderColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 14.h),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    isUpdating
                                        ? null
                                        : () async {
                                          final newUsername =
                                              usernameController.text
                                                  .trim()
                                                  .toLowerCase();

                                          // Validate
                                          if (newUsername.isEmpty) {
                                            setModalState(
                                              () =>
                                                  errorText =
                                                      'Username cannot be empty',
                                            );
                                            return;
                                          }
                                          if (newUsername.length < 3) {
                                            setModalState(
                                              () =>
                                                  errorText =
                                                      'At least 3 characters required',
                                            );
                                            return;
                                          }
                                          if (!RegExp(
                                            r'^[a-z0-9_]+$',
                                          ).hasMatch(newUsername)) {
                                            setModalState(
                                              () =>
                                                  errorText =
                                                      'Only letters, numbers, underscore',
                                            );
                                            return;
                                          }

                                          setModalState(
                                            () => isUpdating = true,
                                          );

                                          try {
                                            final profileService =
                                                nostr_v2.NostrProfileService();
                                            final newAddress =
                                                formatLightningAddress(
                                                  newUsername,
                                                );

                                            final success = await profileService
                                                .updateProfile(
                                                  lud16: newAddress,
                                                );

                                            if (success && context.mounted) {
                                              Navigator.pop(context, true);
                                            } else if (context.mounted) {
                                              setModalState(() {
                                                errorText = 'Failed to update';
                                                isUpdating = false;
                                              });
                                            }
                                          } catch (e) {
                                            setModalState(() {
                                              errorText = 'Error: $e';
                                              isUpdating = false;
                                            });
                                          }
                                        },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF7931A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 14.h),
                                ),
                                child:
                                    isUpdating
                                        ? SizedBox(
                                          width: 20.w,
                                          height: 20.w,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : Text(
                                          'Save',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                      ],
                    ),
                  ),
                ),
          ),
    );

    if (result == true) {
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lightning address updated!'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    }
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

  Future<void> _switchWallet() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(
              'Switch Wallet?',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18.sp),
            ),
            content: Text(
              'This will take you back to the wallet selection screen. Your wallet data will remain secure.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
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

  @override
  Widget build(BuildContext context) {
    final hasNostr = _nostrNpub != null && _nostrNpub!.isNotEmpty;
    final displayName =
        _nostrProfile?.displayName ?? _nostrProfile?.name ?? 'Anonymous';
    final username = _nostrProfile?.name;
    final bio = _nostrProfile?.about;
    final picture = _nostrProfile?.picture;
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
                        SizedBox(height: 12.h),

                        _MenuItemTile(
                          icon: Icons.swap_horiz,
                          iconColor: Colors.orange,
                          title: 'Switch Wallet',
                          onTap: _switchWallet,
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
    final hasClaimed =
        currentAddress != null &&
        currentAddress.contains('@$lightningAddressDomain');

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
              Icon(Icons.bolt, color: AppColors.accentYellow, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Lightning Address',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          if (hasClaimed) ...[
            // Show claimed address
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: AppColors.accentGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.accentGreen,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      currentAddress,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: currentAddress));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lightning address copied!'),
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
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: () => _showEditLightningAddressModal(currentAddress),
                    child: Icon(
                      Icons.edit,
                      color: const Color(0xFFF7931A),
                      size: 18.sp,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Receive bitcoin directly to your wallet via this address',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
            ),
          ] else ...[
            // Claim form
            Text(
              'Claim your @$lightningAddressDomain address to receive bitcoin directly',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color:
                            _usernameError != null
                                ? Colors.red
                                : AppColors.borderColor,
                      ),
                    ),
                    child: TextField(
                      controller: _usernameController,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                      ),
                      decoration: InputDecoration(
                        hintText: 'username',
                        hintStyle: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 14.sp,
                        ),
                        suffixText: '@$lightningAddressDomain',
                        suffixStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 12.h,
                        ),
                      ),
                      onChanged: (_) {
                        if (_usernameError != null) {
                          setState(() => _usernameError = null);
                        }
                      },
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                ElevatedButton(
                  onPressed:
                      _isClaimingLightningAddress
                          ? null
                          : _claimLightningAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF7931A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                  ),
                  child:
                      _isClaimingLightningAddress
                          ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                          : Text(
                            'Claim',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ],
            ),
            if (_usernameError != null) ...[
              SizedBox(height: 4.h),
              Text(
                _usernameError!,
                style: TextStyle(color: Colors.red, fontSize: 11.sp),
              ),
            ],
          ],
        ],
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
