import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'social_recovery_service.dart';
import 'contact_picker_screen.dart';

/// Screen for managing recovery guardians
/// - View current guardians with health status
/// - Add new guardians (up to 5)
/// - Replace guardians
/// - Remove guardians (if more than 3)
/// - Test guardian connectivity
class GuardianManagementScreen extends ConsumerStatefulWidget {
  const GuardianManagementScreen({super.key});

  @override
  ConsumerState<GuardianManagementScreen> createState() =>
      _GuardianManagementScreenState();
}

class _GuardianManagementScreenState
    extends ConsumerState<GuardianManagementScreen> {
  List<RecoveryContact> _guardians = [];
  bool _isLoading = true;
  bool _isPinging = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGuardians();
  }

  Future<void> _loadGuardians() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final guardians = await SocialRecoveryService.getRecoveryContacts();
      if (mounted) {
        setState(() {
          _guardians = guardians;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load guardians';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pingGuardians() async {
    setState(() => _isPinging = true);

    try {
      final updated = await SocialRecoveryService.pingGuardians();
      if (mounted) {
        setState(() {
          _guardians = updated;
          _isPinging = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated health status for ${updated.length} guardians'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPinging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to ping guardians'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addGuardian() async {
    if (_guardians.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 guardians allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to contact picker
    final selected = await Navigator.push<List<ContactWithStatus>>(
      context,
      MaterialPageRoute(
        builder: (_) => ContactPickerScreen(
          maxSelection: 1,
          onContactsSelected: (_) {},
        ),
      ),
    );

    if (selected != null && selected.isNotEmpty) {
      final contact = selected.first;
      
      // Get master seed
      final storage = ref.read(secureStorageServiceProvider);
      final masterSeed = await storage.getWalletSeed();
      
      if (masterSeed == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access wallet seed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final newGuardian = RecoveryContact(
        name: contact.name,
        phoneNumber: contact.phoneNumber,
        npub: contact.npub ?? '',
        publicKey: contact.hexPubkey ?? '',
        isOnNostr: contact.isOnNostr,
      );

      final success = await SocialRecoveryService.addGuardian(
        newGuardian: newGuardian,
        masterSeed: masterSeed,
      );

      if (success) {
        _loadGuardians();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${contact.name} as guardian'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
        }
      }
    }
  }

  Future<void> _replaceGuardian(RecoveryContact oldGuardian) async {
    final selected = await Navigator.push<List<ContactWithStatus>>(
      context,
      MaterialPageRoute(
        builder: (_) => ContactPickerScreen(
          maxSelection: 1,
          onContactsSelected: (_) {},
        ),
      ),
    );

    if (selected != null && selected.isNotEmpty) {
      final contact = selected.first;
      
      final storage = ref.read(secureStorageServiceProvider);
      final masterSeed = await storage.getWalletSeed();
      
      if (masterSeed == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access wallet seed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final newGuardian = RecoveryContact(
        name: contact.name,
        phoneNumber: contact.phoneNumber,
        npub: contact.npub ?? '',
        publicKey: contact.hexPubkey ?? '',
        isOnNostr: contact.isOnNostr,
      );

      try {
        await SocialRecoveryService.replaceGuardian(
          oldGuardian: oldGuardian,
          newGuardian: newGuardian,
          masterSeed: masterSeed,
        );

        _loadGuardians();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Replaced ${oldGuardian.name} with ${contact.name}'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to replace guardian: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeGuardian(RecoveryContact guardian) async {
    if (_guardians.length <= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum 3 guardians required'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Remove Guardian',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove ${guardian.name} as a guardian? '
          'They will no longer be able to help you recover your wallet.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await SocialRecoveryService.removeGuardian(guardian);
      if (success) {
        _loadGuardians();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed ${guardian.name}'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
        }
      }
    }
  }

  void _showGuardianOptions(RecoveryContact guardian) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                guardian.name,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              _buildHealthBadge(guardian.healthStatus),
              SizedBox(height: 24.h),
              _buildOptionTile(
                icon: Icons.swap_horiz,
                label: 'Replace Guardian',
                onTap: () {
                  Navigator.pop(context);
                  _replaceGuardian(guardian);
                },
              ),
              if (_guardians.length > 3)
                _buildOptionTile(
                  icon: Icons.person_remove,
                  label: 'Remove Guardian',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _removeGuardian(guardian);
                  },
                ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textPrimary),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.textPrimary,
          fontSize: 16.sp,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
    );
  }

  Widget _buildHealthBadge(GuardianHealthStatus status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case GuardianHealthStatus.healthy:
        color = AppColors.accentGreen;
        text = 'Healthy';
        icon = Icons.check_circle;
        break;
      case GuardianHealthStatus.warning:
        color = Colors.orange;
        text = 'Warning';
        icon = Icons.warning;
        break;
      case GuardianHealthStatus.offline:
        color = Colors.red;
        text = 'Offline';
        icon = Icons.error;
        break;
      case GuardianHealthStatus.unknown:
        color = AppColors.textSecondary;
        text = 'Unknown';
        icon = Icons.help;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16.sp),
          SizedBox(width: 6.w),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Manage Guardians',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!_isLoading && _guardians.isNotEmpty)
            IconButton(
              icon: _isPinging
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(Icons.refresh, color: AppColors.primary),
              onPressed: _isPinging ? null : _pingGuardians,
              tooltip: 'Check health status',
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _guardians.length < 5 && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _addGuardian,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: Text(
                'Add Guardian',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48.sp),
            SizedBox(height: 16.h),
            Text(
              _error!,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16.sp),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadGuardians,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_guardians.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHealthSummary(),
          SizedBox(height: 24.h),
          Text(
            'Your Guardians (${_guardians.length}/5)',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12.h),
          ..._guardians.map((g) => _buildGuardianCard(g)),
          SizedBox(height: 80.h), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_outlined,
                color: AppColors.primary,
                size: 40.sp,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'No Guardians Set Up',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Add trusted contacts who can help you recover your wallet if you lose access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
                height: 1.5,
              ),
            ),
            SizedBox(height: 32.h),
            ElevatedButton.icon(
              onPressed: _addGuardian,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Your First Guardian'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthSummary() {
    int healthy = 0;
    int warning = 0;
    int offline = 0;

    for (final g in _guardians) {
      switch (g.healthStatus) {
        case GuardianHealthStatus.healthy:
          healthy++;
          break;
        case GuardianHealthStatus.warning:
          warning++;
          break;
        case GuardianHealthStatus.offline:
        case GuardianHealthStatus.unknown:
          offline++;
          break;
      }
    }

    final overallHealthy = healthy >= 3;
    final overallWarning = !overallHealthy && (healthy + warning >= 3);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: overallHealthy
            ? AppColors.accentGreen.withOpacity(0.1)
            : overallWarning
                ? Colors.orange.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: overallHealthy
              ? AppColors.accentGreen.withOpacity(0.3)
              : overallWarning
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                overallHealthy
                    ? Icons.shield
                    : overallWarning
                        ? Icons.shield_outlined
                        : Icons.warning,
                color: overallHealthy
                    ? AppColors.accentGreen
                    : overallWarning
                        ? Colors.orange
                        : Colors.red,
                size: 24.sp,
              ),
              SizedBox(width: 12.w),
              Text(
                overallHealthy
                    ? 'Recovery Protected'
                    : overallWarning
                        ? 'Recovery at Risk'
                        : 'Recovery Compromised',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            overallHealthy
                ? 'At least 3 guardians are healthy and can help you recover.'
                : overallWarning
                    ? 'Some guardians may be unreachable. Consider replacing inactive ones.'
                    : 'Less than 3 guardians are reachable. Add or replace guardians immediately.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.sp,
              height: 1.4,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _buildStatusChip('Healthy', healthy, AppColors.accentGreen),
              SizedBox(width: 8.w),
              _buildStatusChip('Warning', warning, Colors.orange),
              SizedBox(width: 8.w),
              _buildStatusChip('Offline', offline, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            '$count $label',
            style: TextStyle(
              color: color,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianCard(RecoveryContact guardian) {
    final healthColor = switch (guardian.healthStatus) {
      GuardianHealthStatus.healthy => AppColors.accentGreen,
      GuardianHealthStatus.warning => Colors.orange,
      GuardianHealthStatus.offline => Colors.red,
      GuardianHealthStatus.unknown => AppColors.textSecondary,
    };

    return GestureDetector(
      onTap: () => _showGuardianOptions(guardian),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: healthColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // Avatar with health indicator
            Stack(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      guardian.name.isNotEmpty
                          ? guardian.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14.w,
                    height: 14.w,
                    decoration: BoxDecoration(
                      color: healthColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surface,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 14.w),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guardian.name,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: AppColors.textSecondary,
                        size: 12.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        guardian.lastSeenText,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                        ),
                      ),
                      if (guardian.shareIndex != null) ...[
                        SizedBox(width: 12.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            'Share ${guardian.shareIndex}',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Delivery status
            if (guardian.shareDelivered)
              Icon(
                Icons.check_circle,
                color: AppColors.accentGreen,
                size: 20.sp,
              )
            else
              Icon(
                Icons.pending,
                color: Colors.orange,
                size: 20.sp,
              ),
            SizedBox(width: 8.w),
            Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}
