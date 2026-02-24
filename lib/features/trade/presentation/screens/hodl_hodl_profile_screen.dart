import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/hodl_hodl/hodl_hodl.dart';

/// HodlHodl Profile Edit Screen
/// Allows users to edit their HodlHodl trading profile
class HodlHodlProfileScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> userData;

  const HodlHodlProfileScreen({super.key, required this.userData});

  @override
  ConsumerState<HodlHodlProfileScreen> createState() =>
      _HodlHodlProfileScreenState();
}

class _HodlHodlProfileScreenState extends ConsumerState<HodlHodlProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _verifiedOnly = false;
  bool _willSendFirst = false;
  String? _selectedCountry;
  String? _selectedCurrency;

  bool _isLoading = false;
  bool _hasChanges = false;

  // Common countries for P2P trading
  static const List<Map<String, String>> _countries = [
    {'code': 'Global', 'name': 'Global (Worldwide)'},
    {'code': 'NG', 'name': 'Nigeria'},
    {'code': 'GH', 'name': 'Ghana'},
    {'code': 'KE', 'name': 'Kenya'},
    {'code': 'ZA', 'name': 'South Africa'},
    {'code': 'US', 'name': 'United States'},
    {'code': 'GB', 'name': 'United Kingdom'},
    {'code': 'DE', 'name': 'Germany'},
    {'code': 'FR', 'name': 'France'},
    {'code': 'ES', 'name': 'Spain'},
    {'code': 'IT', 'name': 'Italy'},
    {'code': 'CA', 'name': 'Canada'},
    {'code': 'AU', 'name': 'Australia'},
    {'code': 'IN', 'name': 'India'},
    {'code': 'BR', 'name': 'Brazil'},
    {'code': 'MX', 'name': 'Mexico'},
    {'code': 'AE', 'name': 'UAE'},
  ];

  // Common currencies
  static const List<Map<String, String>> _currencies = [
    {'code': 'NGN', 'name': 'Nigerian Naira'},
    {'code': 'USD', 'name': 'US Dollar'},
    {'code': 'EUR', 'name': 'Euro'},
    {'code': 'GBP', 'name': 'British Pound'},
    {'code': 'GHS', 'name': 'Ghanaian Cedi'},
    {'code': 'KES', 'name': 'Kenyan Shilling'},
    {'code': 'ZAR', 'name': 'South African Rand'},
    {'code': 'INR', 'name': 'Indian Rupee'},
    {'code': 'BRL', 'name': 'Brazilian Real'},
    {'code': 'CAD', 'name': 'Canadian Dollar'},
    {'code': 'AUD', 'name': 'Australian Dollar'},
    {'code': 'AED', 'name': 'UAE Dirham'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final userData = widget.userData;
    _nicknameController.text = userData['nickname'] ?? '';
    _descriptionController.text = userData['description'] ?? '';
    _verifiedOnly = userData['verified_only'] == true;
    _willSendFirst = userData['will_send_first'] == true;
    
    // Get country code, ensure it exists in our list
    final countryCode = userData['country_code'] as String?;
    if (countryCode != null && _countries.any((c) => c['code'] == countryCode)) {
      _selectedCountry = countryCode;
    } else {
      _selectedCountry = null;
    }
    
    // Get currency code, ensure it exists in our list
    final currencyCode = userData['currency_code'] as String?;
    if (currencyCode != null && _currencies.any((c) => c['code'] == currencyCode)) {
      _selectedCurrency = currencyCode;
    } else {
      _selectedCurrency = null;
    }

    // Listen for changes
    _nicknameController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final hodlHodlService = HodlHodlService();
      await hodlHodlService.updateMe(
        nickname: _nicknameController.text.trim().isEmpty
            ? null
            : _nicknameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        verifiedOnly: _verifiedOnly,
        willSendFirst: _willSendFirst,
        countryCode: _selectedCountry,
        currencyCode: _selectedCurrency,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('Exception:')) {
          errorMsg = errorMsg.replaceFirst('Exception:', '').trim();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMsg'),
            backgroundColor: AppColors.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.w,
                        color: AppColors.primary,
                      ),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Info Section
                _buildSectionTitle('Profile Information'),
                SizedBox(height: 16.h),
                _buildProfileInfo(),
                SizedBox(height: 24.h),

                // Nickname Field
                _buildSectionTitle('Display Name'),
                SizedBox(height: 12.h),
                _buildNicknameField(),
                SizedBox(height: 24.h),

                // Description Field
                _buildSectionTitle('About You'),
                SizedBox(height: 12.h),
                _buildDescriptionField(),
                SizedBox(height: 24.h),

                // Location Settings
                _buildSectionTitle('Location & Currency'),
                SizedBox(height: 12.h),
                _buildLocationSettings(),
                SizedBox(height: 24.h),

                // Trading Preferences
                _buildSectionTitle('Trading Preferences'),
                SizedBox(height: 12.h),
                _buildTradingPreferences(),
                SizedBox(height: 40.h),

                // Save Button
                _buildSaveButton(),
                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildProfileInfo() {
    final login = widget.userData['login'] ?? 'Trader';
    final rating = widget.userData['rating'];
    final verified = widget.userData['verified'] == true;
    final tradesCount = widget.userData['trades_count'] ?? 0;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28.r,
            backgroundColor: AppColors.primary,
            child: Text(
              login.isNotEmpty ? login[0].toUpperCase() : 'T',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
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
                      login,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (verified) ...[
                      SizedBox(width: 6.w),
                      Icon(
                        Icons.verified_rounded,
                        color: AppColors.accentGreen,
                        size: 16.sp,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    if (rating != null) ...[
                      Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 14.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        rating.toString(),
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(width: 10.w),
                    ],
                    Text(
                      '$tradesCount trades',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNicknameField() {
    return TextFormField(
      controller: _nicknameController,
      style: TextStyle(color: Colors.white, fontSize: 14.sp),
      decoration: InputDecoration(
        hintText: 'Enter display name',
        hintStyle: TextStyle(color: Colors.white38, fontSize: 14.sp),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      ),
      validator: (value) {
        if (value != null && value.isNotEmpty && value.length < 3) {
          return 'Name must be at least 3 characters';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      style: TextStyle(color: Colors.white, fontSize: 14.sp),
      maxLines: 4,
      maxLength: 500,
      decoration: InputDecoration(
        hintText: 'Tell other traders about yourself...',
        hintStyle: TextStyle(color: Colors.white38, fontSize: 14.sp),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        counterStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11.sp),
      ),
    );
  }

  Widget _buildLocationSettings() {
    return Column(
      children: [
        // Country dropdown
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCountry,
              hint: Text(
                'Select country',
                style: TextStyle(color: Colors.white38, fontSize: 14.sp),
              ),
              items: _countries.map((country) {
                return DropdownMenuItem<String>(
                  value: country['code'],
                  child: Text(
                    country['name']!,
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCountry = value;
                  _hasChanges = true;
                });
              },
              dropdownColor: AppColors.surface,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down,
                  color: Colors.white54, size: 24.sp),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        // Currency dropdown
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCurrency,
              hint: Text(
                'Select preferred currency',
                style: TextStyle(color: Colors.white38, fontSize: 14.sp),
              ),
              items: _currencies.map((currency) {
                return DropdownMenuItem<String>(
                  value: currency['code'],
                  child: Text(
                    '${currency['code']} - ${currency['name']}',
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCurrency = value;
                  _hasChanges = true;
                });
              },
              dropdownColor: AppColors.surface,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down,
                  color: Colors.white54, size: 24.sp),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTradingPreferences() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          // Verified only toggle
          _buildToggleOption(
            icon: Icons.verified_user_outlined,
            iconColor: AppColors.accentGreen,
            title: 'Trade with verified users only',
            subtitle: 'Only accept trades from verified accounts',
            value: _verifiedOnly,
            onChanged: (value) {
              setState(() {
                _verifiedOnly = value;
                _hasChanges = true;
              });
            },
          ),
          Divider(color: Colors.white12, height: 1),
          // Will send first toggle
          _buildToggleOption(
            icon: Icons.send_rounded,
            iconColor: AppColors.primary,
            title: 'Willing to send payment first',
            subtitle: 'Indicate you\'re open to paying before escrow',
            value: _willSendFirst,
            onChanged: (value) {
              setState(() {
                _willSendFirst = value;
                _hasChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: iconColor, size: 20.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_hasChanges && !_isLoading) ? _saveProfile : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 20.w,
                height: 20.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2.w,
                  color: Colors.white,
                ),
              )
            : Text(
                'Save Changes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
