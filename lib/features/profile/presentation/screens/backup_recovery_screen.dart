import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'package:sabi_wallet/features/onboarding/presentation/screens/backup_choice_screen.dart';
import 'package:sabi_wallet/features/onboarding/presentation/screens/social_recovery_restore_screen.dart';
import 'package:sabi_wallet/features/onboarding/presentation/screens/seed_phrase_screen.dart';
import 'package:sabi_wallet/features/recovery/presentation/screens/guardian_management_screen.dart';
import 'package:sabi_wallet/features/recovery/services/social_recovery_service.dart';
import 'package:sabi_wallet/features/recovery/presentation/widgets/recovery_setup_flow.dart';

class BackupRecoveryScreen extends ConsumerStatefulWidget {
  const BackupRecoveryScreen({super.key});

  @override
  ConsumerState<BackupRecoveryScreen> createState() =>
      _BackupRecoveryScreenState();
}

class _BackupRecoveryScreenState extends ConsumerState<BackupRecoveryScreen> {
  List<RecoveryContact> _guardians = [];
  bool _isLoading = true;
  Map<String, dynamic> _healthData = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final guardians = await SocialRecoveryService.getRecoveryContacts();
      final health = await SocialRecoveryService.getRecoveryHealth();

      if (mounted) {
        setState(() {
          _guardians = guardians;
          _healthData = health;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pingGuardians() async {
    final updated = await SocialRecoveryService.pingGuardians();
    if (mounted) {
      setState(() => _guardians = updated);
      _loadData(); // Reload health data
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(secureStorageServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                SizedBox(height: 20.h),
                _BackupStatusCard(
                  storage: storage,
                  isRecoverySetUp: _guardians.isNotEmpty,
                ),
                SizedBox(height: 24.h),
                if (_isLoading)
                  _buildLoadingCard()
                else if (_guardians.isEmpty)
                  _buildSetupSocialRecoveryCard(storage)
                else ...[
                  Text(
                    'Your Recovery Guys',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _buildHealthCard(),
                  SizedBox(height: 16.h),
                  _buildSocialRecoveryCard(),
                ],
                SizedBox(height: 28.h),
                Text(
                  'Manual Backup',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 12.h),
                _ManualBackupCard(storage: storage),
                SizedBox(height: 28.h),
                // Guardian section - if user is holding someone else's share
                _GuardianShareSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 24.sp,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        SizedBox(width: 8.w),
        Text(
          'Backup & Recovery',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildSetupSocialRecoveryCard(SecureStorageService storage) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.15),
            AppColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.groups_outlined,
                  color: AppColors.primary,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Social Recovery',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            'Recommended',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Your trusted contacts can help recover your wallet',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Text(
            '• No need to store seed phrases\n'
            '• 3 of 5 contacts needed to recover\n'
            '• End-to-end encrypted via Nostr',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.sp,
              height: 1.6,
            ),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final masterSeed = await storage.getWalletSeed();
                if (masterSeed != null && mounted) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecoverySetupFlow(masterSeed: masterSeed),
                    ),
                  );
                  if (result == true) {
                    _loadData();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Set Up Social Recovery',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard() {
    final isSetUp = _healthData['isSetUp'] ?? false;
    final healthyCount = _healthData['healthyCount'] ?? 0;
    final warningCount = _healthData['warningCount'] ?? 0;
    final totalCount = _healthData['totalCount'] ?? 0;
    final overallStatus = _healthData['overallStatus'] as GuardianHealthStatus?;

    if (!isSetUp) return const SizedBox.shrink();

    final isHealthy = overallStatus == GuardianHealthStatus.healthy;
    final isWarning = overallStatus == GuardianHealthStatus.warning;
    final borderColor =
        isHealthy
            ? AppColors.accentGreen
            : isWarning
            ? Colors.orange
            : Colors.red;

    final statusText =
        isHealthy
            ? 'Health: Strong'
            : isWarning
            ? 'Health: Warning'
            : 'Health: Critical';

    final subtitleText =
        isHealthy
            ? '$healthyCount contacts online recently'
            : isWarning
            ? '$warningCount contacts may need attention'
            : 'Less than 3 contacts reachable';

    final healthValue =
        totalCount > 0 ? (healthyCount + warningCount * 0.5) / totalCount : 0.0;

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor, width: 1.2.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitleText,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _pingGuardians,
                child: Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: borderColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    color: borderColor,
                    size: 20.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: healthValue.clamp(0.0, 1.0),
              minHeight: 6.h,
              backgroundColor: AppColors.surface.withOpacity(0.4),
              valueColor: AlwaysStoppedAnimation(borderColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialRecoveryCard() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B1C),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.groups_outlined,
                  color: AppColors.primary,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Social Recovery',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${_guardians.length} trusted contacts',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Real guardian list
          ..._guardians.take(3).map((g) => _GuardianTile(guardian: g)),
          if (_guardians.length > 3)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(
                '+${_guardians.length - 3} more guardians',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
            ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GuardianManagementScreen(),
                      ),
                    );
                    _loadData(); // Reload after managing
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary, width: 1.w),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  child: Text(
                    'Manage Guardians',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SocialRecoveryRestoreScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.textSecondary.withOpacity(0.4),
                      width: 1.w,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  child: Text(
                    'Test Recovery',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
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
}

class _BackupStatusCard extends StatelessWidget {
  final SecureStorageService storage;
  final bool isRecoverySetUp;

  const _BackupStatusCard({
    required this.storage,
    required this.isRecoverySetUp,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: storage.getBackupStatus(),
      builder: (context, snapshot) {
        final status = snapshot.data;
        final isBackedUp =
            (status != null && status != 'none' && status != 'skipped') ||
            isRecoverySetUp;
        final borderColor =
            isBackedUp ? AppColors.accentGreen : AppColors.accentRed;
        final title = isBackedUp ? 'Wallet Backed Up' : 'Wallet Not Backed Up';
        final subtitle =
            isBackedUp
                ? isRecoverySetUp
                    ? 'Protected by Social Recovery'
                    : 'Seed phrase backed up'
                : 'Set up a backup to protect your funds';

        return Container(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: borderColor, width: 1.2.w),
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: borderColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_moon_outlined,
                  color: borderColor,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isBackedUp)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BackupChoiceScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Set up',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GuardianTile extends StatelessWidget {
  final RecoveryContact guardian;

  const _GuardianTile({required this.guardian});

  @override
  Widget build(BuildContext context) {
    final healthColor = switch (guardian.healthStatus) {
      GuardianHealthStatus.healthy => AppColors.accentGreen,
      GuardianHealthStatus.warning => Colors.orange,
      GuardianHealthStatus.offline => Colors.red,
      GuardianHealthStatus.unknown => AppColors.textSecondary,
    };

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1024),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    guardian.name.isNotEmpty
                        ? guardian.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: healthColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0E1024),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guardian.name,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  guardian.lastSeenText,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (guardian.shareDelivered)
            Icon(Icons.check_circle, color: AppColors.accentGreen, size: 20.sp)
          else
            Icon(Icons.pending, color: Colors.orange, size: 20.sp),
        ],
      ),
    );
  }
}

class _ManualBackupCard extends ConsumerWidget {
  final SecureStorageService storage;

  const _ManualBackupCard({required this.storage});

  Future<void> _viewSeedPhrase(BuildContext context, WidgetRef ref) async {
    final mnemonic = await storage.getMnemonic();
    if (mnemonic == null || mnemonic.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.accentRed,
          content: Text(
            'No seed phrase found. Please set up backup first.',
            style: TextStyle(color: AppColors.surface),
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SeedPhraseScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B1C),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.key_outlined,
                  color: AppColors.primary,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seed Phrase',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '12-word recovery phrase',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _viewSeedPhrase(context, ref),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary, width: 1.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
              child: Text(
                'View Seed Phrase',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section shown if user is holding a recovery share for someone else
class _GuardianShareSection extends StatefulWidget {
  const _GuardianShareSection();

  @override
  State<_GuardianShareSection> createState() => _GuardianShareSectionState();
}

class _GuardianShareSectionState extends State<_GuardianShareSection> {
  bool _hasShare = false;
  Map<String, dynamic>? _shareInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShareInfo();
  }

  Future<void> _loadShareInfo() async {
    final hasShare = await SocialRecoveryService.hasReceivedShare();
    Map<String, dynamic>? info;
    if (hasShare) {
      info = await SocialRecoveryService.getReceivedShare();
    }
    if (mounted) {
      setState(() {
        _hasShare = hasShare;
        _shareInfo = info;
        _isLoading = false;
      });
    }
  }

  void _showShareDetails() async {
    final shareJson = await SocialRecoveryService.getShareForManualSending();
    if (shareJson == null || !mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recovery Share',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'You are holding a recovery share for someone. Copy this JSON and send it as an encrypted DM (NIP-04) when they request recovery.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 16.h),

              // Share info
              if (_shareInfo != null) ...[
                Row(
                  children: [
                    Text(
                      'Share Index: ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                    Text(
                      '#${_shareInfo!['share_index']}',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Text(
                      'Owner: ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _shareInfo!['owner_npub'] ?? 'Unknown',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11.sp,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
              ],

              // Share JSON
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: SelectableText(
                  shareJson,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 10.sp,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Copy button
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: shareJson));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Share copied! Send as encrypted DM.'),
                        backgroundColor: AppColors.accentGreen,
                      ),
                    );
                  },
                  icon: Icon(Icons.copy, size: 18.sp),
                  label: Text(
                    'Copy to Clipboard',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Help text
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: AppColors.primary,
                      size: 18.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'You can send this via Primal, Damus, or any Nostr client that supports NIP-04 encrypted DMs.',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (!_hasShare) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You Are a Guardian',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.purple.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield, color: Colors.purple, size: 22.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Holding Share #${_shareInfo?['share_index'] ?? '?'}',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'You can resend this via any Nostr client',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _showShareDetails,
                child: Text(
                  'View',
                  style: TextStyle(
                    color: AppColors.primary,
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
}
