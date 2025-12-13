import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/profile_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class EditProfileScreen extends StatefulWidget {
  final UserProfile currentProfile;

  const EditProfileScreen({super.key, required this.currentProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  String? _profilePicturePath;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentProfile.fullName,
    );
    _usernameController = TextEditingController(
      text: widget.currentProfile.username,
    );
    _profilePicturePath = widget.currentProfile.profilePicturePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            'profile_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
        final savedImage = File('${appDir.path}/$fileName');
        await File(image.path).copy(savedImage.path);

        setState(() {
          _profilePicturePath = savedImage.path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to pick image: $e',
            style: TextStyle(color: AppColors.surface),
          ),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (photo != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            'profile_${DateTime.now().millisecondsSinceEpoch}${path.extension(photo.path)}';
        final savedImage = File('${appDir.path}/$fileName');
        await File(photo.path).copy(savedImage.path);

        setState(() {
          _profilePicturePath = savedImage.path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to take photo: $e',
            style: TextStyle(color: AppColors.surface),
          ),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Choose Profile Picture',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  ListTile(
                    leading: Icon(
                      Icons.photo_library_outlined,
                      color: AppColors.primary,
                      size: 24.sp,
                    ),
                    title: Text(
                      'Choose from Gallery',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage();
                    },
                  ),
                    suffixText: '@sabiwallet.xyz',
                    suffixStyle: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16.sp,
                    ),
                      Icons.camera_alt,
                      color: AppColors.primary,
                      size: 24.sp,
                    ),
                    title: Text(
                      'Take a Photo',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _takePhoto();
                    },
                  ),
                  if (_profilePicturePath != null)
                    ListTile(
                      leading: Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 24.sp,
                      ),
                      title: Text(
                        'Remove Picture',
                        style: TextStyle(color: Colors.red, fontSize: 16.sp),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _profilePicturePath = null);
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updatedProfile = widget.currentProfile.copyWith(
        fullName: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        profilePicturePath: _profilePicturePath,
      );

      await ProfileService.saveProfile(updatedProfile);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile updated successfully',
            style: TextStyle(fontSize: 14.sp, color: AppColors.surface),
          ),
          backgroundColor: AppColors.accentGreen,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update profile: $e',
            style: TextStyle(fontSize: 14.sp, color: AppColors.surface),
          ),
          backgroundColor: AppColors.accentRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(30.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildProfilePicture(),
                      SizedBox(height: 40.h),
                      _buildNameField(),
                        'Your Lightning address: ${_usernameController.text}@sabiwallet.xyz',
                      _buildUsernameField(),
                      SizedBox(height: 40.h),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 10.w),
          Text(
            'Edit Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePicture() {
    return GestureDetector(
      onTap: _showImageSourceDialog,
      child: Stack(
        children: [
          Container(
            width: 140.w,
            height: 140.w,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              image:
                  _profilePicturePath != null
                      ? DecorationImage(
                        image: FileImage(File(_profilePicturePath!)),
                        fit: BoxFit.cover,
                      )
                      : null,
            ),
            child:
                _profilePicturePath == null
                    ? Center(
                      child: Text(
                        _nameController.text.isNotEmpty
                            ? _nameController.text[0].toUpperCase()
                            : 'User',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                    : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 3.w),
              ),
              child: Icon(
                Icons.camera_alt,
                color: AppColors.surface,
                size: 18.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Full Name',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: _nameController,
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
          decoration: InputDecoration(
            hintText: 'Enter your full name',
            hintStyle: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14.sp,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20.w,
              vertical: 16.h,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your name';
            }
            if (value.trim().length < 2) {
              return 'Name must be at least 2 characters';
            }
            return null;
          },
          onChanged: (value) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Username',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: _usernameController,
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
          decoration: InputDecoration(
            hintText: 'Enter username',
            hintStyle: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14.sp,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20.w,
              vertical: 16.h,
            ),
<<<<<<< HEAD
            prefixText: '@sabi/',
            prefixStyle: TextStyle(color: AppColors.primary, fontSize: 16.sp),
=======
            suffixText: '@sabiwallet.xyz',
            suffixStyle: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
            ),
>>>>>>> 2ada74a (Add lightning address persistence)
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a username';
            }
            if (value.trim().length < 3) {
              return 'Username must be at least 3 characters';
            }
            if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
              return 'Only letters, numbers, and underscores allowed';
            }
            return null;
          },
        ),
        SizedBox(height: 8.h),
        Text(
<<<<<<< HEAD
          'Your unique Sabi wallet address: @sabi/${_usernameController.text}',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 12.sp),
=======
          'Your Lightning address: ${_usernameController.text}@sabiwallet.xyz',
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
>>>>>>> 2ada74a (Add lightning address persistence)
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        child:
            _isSaving
                ? SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.sp,
                  ),
                )
                : Text(
                  'Save Changes',
                  style: TextStyle(
                    color: AppColors.surface,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
      ),
    );
  }
}
