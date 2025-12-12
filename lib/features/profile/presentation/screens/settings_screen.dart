import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'package:sabi_wallet/features/profile/presentation/screens/change_pin_screen.dart';
import 'package:sabi_wallet/features/profile/presentation/providers/settings_provider.dart';
import 'package:sabi_wallet/l10n/language_provider.dart';
import 'package:sabi_wallet/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _hasPinCode = false;

  @override
  void initState() {
    super.initState();
    _checkPinCode();
  }

  Future<void> _checkPinCode() async {
    final storage = ref.read(secureStorageServiceProvider);
    final pin = await storage.getPinCode();
    setState(() {
      _hasPinCode = pin != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
              child: Row(
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
                    AppLocalizations.of(context)!.settings,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(30.w, 10.h, 30.w, 30.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: AppLocalizations.of(context)!.account,
                    ),
                    SizedBox(height: 12.h),

                    _SettingTile(
                      icon: Icons.lock_outline,
                      iconColor: AppColors.primary,
                      title: _hasPinCode ? 'Change PIN' : 'Create PIN',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ChangePinScreen(isCreate: !_hasPinCode),
                          ),
                        );
                        _checkPinCode();
                      },
                    ),

                    SizedBox(height: 12.h),

                    _SettingToggleTile(
                      icon: Icons.fingerprint,
                      iconColor: AppColors.accentGreen,
                      title: 'Biometric Login',
                      value: settings.biometricEnabled,
                      onChanged:
                          (value) => ref
                              .read(settingsNotifierProvider.notifier)
                              .toggleBiometric(value),
                    ),

                    SizedBox(height: 12.h),

                    _SettingValueTile(
                      icon: Icons.currency_exchange,
                      iconColor: AppColors.accentYellow,
                      title: 'Currency Preference',
                      value: settings.currency,
                      onTap: () => _showCurrencyPicker(context, ref),
                    ),

                    SizedBox(height: 32.h),

                    _SectionHeader(
                      title: AppLocalizations.of(context)!.security,
                    ),
                    SizedBox(height: 12.h),

                    _SettingValueTile(
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: AppColors.accentRed,
                      title: 'Transaction Limits',
                      value: settings.transactionLimit,
                      onTap: () => _showTransactionLimitPicker(context, ref),
                    ),

                    SizedBox(height: 32.h),

                    _SectionHeader(
                      title: AppLocalizations.of(context)!.preferences,
                    ),
                    SizedBox(height: 12.h),

                    _SettingValueTile(
                      icon: Icons.language_outlined,
                      iconColor: AppColors.primary,
                      title: 'Language',
                      value: settings.language,
                      onTap: () => _showLanguagePicker(context, ref),
                    ),

                    SizedBox(height: 12.h),

                    _SettingToggleTile(
                      icon: Icons.notifications_outlined,
                      iconColor: AppColors.accentYellow,
                      title: 'Notifications',
                      value: settings.notificationsEnabled,
                      onChanged:
                          (value) => ref
                              .read(settingsNotifierProvider.notifier)
                              .toggleNotifications(value),
                    ),

                    SizedBox(height: 12.h),

                    _SettingValueTile(
                      icon: Icons.speed_outlined,
                      iconColor: AppColors.accentGreen,
                      title: 'Network Fees',
                      value: settings.networkFee,
                      onTap: () => _showNetworkFeePicker(context, ref),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bottom sheets remain structurally same—just scaled

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    final currencies = ['NGN', 'USD', 'EUR', 'GBP'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder:
          (_) => Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 10.h,
                  ),
                  child: Text(
                    'Select Currency',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.borderColor),
                ...currencies.map(
                  (currency) => ListTile(
                    title: Text(
                      currency,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.sp,
                      ),
                    ),
                    trailing:
                        ref.watch(settingsNotifierProvider).currency == currency
                            ? Icon(
                              Icons.check,
                              color: AppColors.primary,
                              size: 22.sp,
                            )
                            : null,
                    onTap: () {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .setCurrency(currency);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showTransactionLimitPicker(BuildContext context, WidgetRef ref) {
    final limits = ['₦10,000', '₦50,000', '₦100,000', '₦500,000', 'No Limit'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder:
          (_) => Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 10.h,
                  ),
                  child: Text(
                    'Transaction Limit',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.borderColor),
                ...limits.map(
                  (limit) => ListTile(
                    title: Text(
                      limit,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.sp,
                      ),
                    ),
                    trailing:
                        ref.watch(settingsNotifierProvider).transactionLimit ==
                                limit
                            ? Icon(
                              Icons.check,
                              color: AppColors.primary,
                              size: 22.sp,
                            )
                            : null,
                    onTap: () {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .setTransactionLimit(limit);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final languages = ['English', 'Hausa', 'Yoruba', 'Pidgin'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder:
          (_) => Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 10.h,
                  ),
                  child: Text(
                    'Select Language',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.borderColor),
                ...languages.map(
                  (language) => ListTile(
                    title: Text(
                      language,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.sp,
                      ),
                    ),
                    trailing:
                        ref.watch(settingsNotifierProvider).language == language
                            ? Icon(
                              Icons.check,
                              color: AppColors.primary,
                              size: 22.sp,
                            )
                            : null,
                    onTap: () {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .setLanguage(language);
                      ref.read(languageProvider.notifier).setLanguage(language);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showNetworkFeePicker(BuildContext context, WidgetRef ref) {
    final fees = [
      {'label': 'Economy', 'subtitle': 'Lower fee, slower confirmation'},
      {'label': 'Standard', 'subtitle': 'Balanced fee and speed'},
      {'label': 'Priority', 'subtitle': 'Higher fee, faster confirmation'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder:
          (_) => Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 10.h,
                  ),
                  child: Text(
                    'Network Fees',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.borderColor),
                ...fees.map(
                  (fee) => ListTile(
                    title: Text(
                      fee['label']!,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      fee['subtitle']!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14.sp,
                      ),
                    ),
                    trailing:
                        ref.watch(settingsNotifierProvider).networkFee ==
                                fee['label']
                            ? Icon(
                              Icons.check,
                              color: AppColors.primary,
                              size: 22.sp,
                            )
                            : null,
                    onTap: () {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .setNetworkFee(fee['label']!);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.textSecondary,
        fontFamily: 'Inter',
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _SettingTile({
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

class _SettingValueTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SettingValueTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
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
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16.sp),
              ),
            ),
            Text(
              value,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
            ),
            SizedBox(width: 8.w),
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

class _SettingToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
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
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16.sp),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.all(AppColors.primary),
            trackColor: WidgetStateProperty.all(
              AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
