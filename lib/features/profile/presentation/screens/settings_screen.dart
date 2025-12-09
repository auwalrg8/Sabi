import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.settings,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            // Settings Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(30, 10, 30, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Account Section
                    _SectionHeader(title: AppLocalizations.of(context)!.account),
                    const SizedBox(height: 12),
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
                        // Recheck PIN status after returning
                        _checkPinCode();
                      },
                    ),
                    const SizedBox(height: 12),
                    _SettingToggleTile(
                      icon: Icons.fingerprint,
                      iconColor: AppColors.accentGreen,
                      title: 'Biometric Login',
                      value: settings.biometricEnabled,
                      onChanged: (value) {
                        ref
                            .read(settingsNotifierProvider.notifier)
                            .toggleBiometric(value);
                      },
                    ),
                    const SizedBox(height: 12),
                    _SettingValueTile(
                      icon: Icons.currency_exchange,
                      iconColor: AppColors.accentYellow,
                      title: 'Currency Preference',
                      value: settings.currency,
                      onTap: () {
                        _showCurrencyPicker(context, ref);
                      },
                    ),
                    const SizedBox(height: 32),

                    // Security Section
                    _SectionHeader(title: AppLocalizations.of(context)!.security),
                    const SizedBox(height: 12),
                    _SettingValueTile(
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: AppColors.accentRed,
                      title: 'Transaction Limits',
                      value: settings.transactionLimit,
                      onTap: () {
                        _showTransactionLimitPicker(context, ref);
                      },
                    ),
                    const SizedBox(height: 32),

                    // Preferences Section
                    _SectionHeader(title: AppLocalizations.of(context)!.preferences),
                    const SizedBox(height: 12),
                    _SettingValueTile(
                      icon: Icons.language_outlined,
                      iconColor: AppColors.primary,
                      title: 'Language',
                      value: settings.language,
                      onTap: () {
                        _showLanguagePicker(context, ref);
                      },
                    ),
                    const SizedBox(height: 12),
                    _SettingToggleTile(
                      icon: Icons.notifications_outlined,
                      iconColor: AppColors.accentYellow,
                      title: 'Notifications',
                      value: settings.notificationsEnabled,
                      onChanged: (value) {
                        ref
                            .read(settingsNotifierProvider.notifier)
                            .toggleNotifications(value);
                      },
                    ),
                    const SizedBox(height: 12),
                    _SettingValueTile(
                      icon: Icons.speed_outlined,
                      iconColor: AppColors.accentGreen,
                      title: 'Network Fees',
                      value: settings.networkFee,
                      onTap: () {
                        _showNetworkFeePicker(context, ref);
                      },
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

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    final currencies = ['NGN', 'USD', 'EUR', 'GBP'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'Select Currency',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.borderColor),
                ...currencies.map(
                  (currency) => ListTile(
                    title: Text(
                      currency,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                        fontSize: 16,
                      ),
                    ),
                    trailing:
                        ref.watch(settingsNotifierProvider).currency == currency
                            ? const Icon(Icons.check, color: AppColors.primary)
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'Transaction Limit',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.borderColor),
                ...limits.map(
                  (limit) => ListTile(
                    title: Text(
                      limit,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                        fontSize: 16,
                      ),
                    ),
                    trailing:
                        ref.watch(settingsNotifierProvider).transactionLimit ==
                                limit
                            ? const Icon(Icons.check, color: AppColors.primary)
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'Select Language',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.borderColor),
                ...languages.map(
                  (language) => ListTile(
                    title: Text(
                      language,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                        fontSize: 16,
                      ),
                    ),
                    trailing:
                        ref.watch(settingsNotifierProvider).language == language
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                    onTap: () {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .setLanguage(language);
                      // Also update the app locale
                      ref
                          .read(languageProvider.notifier)
                          .setLanguage(language);
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'Network Fees',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.borderColor),
                ...fees.map(
                  (fee) => ListTile(
                    title: Text(
                      fee['label']!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      fee['subtitle']!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Inter',
                        fontSize: 14,
                      ),
                    ),
                    trailing:
                        ref.watch(settingsNotifierProvider).networkFee ==
                                fee['label']
                            ? const Icon(Icons.check, color: AppColors.primary)
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
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontFamily: 'Inter',
        fontSize: 12,
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 24,
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 24,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
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
