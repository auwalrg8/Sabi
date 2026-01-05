import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../nostr_service.dart';
import 'what_is_nostr_modal.dart';

/// Nostr Onboarding Screen - Guides new users through Nostr setup
/// Shows options to create new identity or import existing keys
class NostrOnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  final bool canSkip;

  const NostrOnboardingScreen({
    super.key,
    this.onComplete,
    this.canSkip = true,
  });

  @override
  State<NostrOnboardingScreen> createState() => _NostrOnboardingScreenState();
}

class _NostrOnboardingScreenState extends State<NostrOnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isCreatingKeys = false;
  bool _showImportFields = false;
  String? _errorMessage;

  final _nsecController = TextEditingController();
  final _npubController = TextEditingController();
  bool _obscureNsec = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nsecController.dispose();
    _npubController.dispose();
    super.dispose();
  }

  Future<void> _createNewIdentity() async {
    setState(() {
      _isCreatingKeys = true;
      _errorMessage = null;
    });

    try {
      final keys = await NostrService.generateKeys();
      await NostrOnboardingManager.markSetupComplete();
      await NostrOnboardingManager.markIntroSeen();

      if (mounted) {
        // Show success dialog with keys
        _showKeysDialog(keys['npub']!, keys['nsec']!);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create identity: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingKeys = false;
        });
      }
    }
  }

  Future<void> _importKeys() async {
    final nsec = _nsecController.text.trim();

    if (nsec.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your nsec (private key)';
      });
      return;
    }

    if (!nsec.startsWith('nsec1')) {
      setState(() {
        _errorMessage = 'Invalid nsec format. It should start with "nsec1"';
      });
      return;
    }

    setState(() {
      _isCreatingKeys = true;
      _errorMessage = null;
    });

    try {
      // Derive npub from nsec
      final derivedNpub = NostrService.getPublicKeyFromNsec(nsec);
      if (derivedNpub == null) {
        setState(() {
          _errorMessage = 'Invalid nsec - could not derive public key';
          _isCreatingKeys = false;
        });
        return;
      }

      // Import keys
      await NostrService.importKeys(nsec: nsec, npub: derivedNpub);
      await NostrOnboardingManager.markSetupComplete();
      await NostrOnboardingManager.markIntroSeen();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nostr identity imported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onComplete?.call();
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error importing keys: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingKeys = false;
        });
      }
    }
  }

  void _showKeysDialog(String npub, String nsec) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28.sp),
                SizedBox(width: 12.w),
                Text(
                  'Identity Created!',
                  style: TextStyle(color: Colors.white, fontSize: 20.sp),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 20.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'IMPORTANT: Save your private key (nsec) securely. It cannot be recovered!',
                            style: TextStyle(
                              color: Colors.red[300],
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Public Key (npub)',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12.sp),
                  ),
                  SizedBox(height: 4.h),
                  _buildKeyContainer(npub, 'npub'),
                  SizedBox(height: 16.h),
                  Text(
                    'Private Key (nsec) - KEEP SECRET!',
                    style: TextStyle(
                      color: Colors.red[300],
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  _buildKeyContainer(nsec, 'nsec', isSecret: true),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final text = 'npub:\n$npub\n\nnsec (KEEP SECRET!):\n$nsec';
                  await Clipboard.setData(ClipboardData(text: text));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Keys copied to clipboard'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: Text(
                  'Copy Both',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  widget.onComplete?.call();
                  Navigator.pop(context, true); // Return true to indicate success
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9945FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'I\'ve Saved My Keys',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildKeyContainer(String key, String label, {bool isSecret = false}) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color:
              isSecret
                  ? Colors.red.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              key.length > 40
                  ? '${key.substring(0, 20)}...${key.substring(key.length - 16)}'
                  : key,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, color: Colors.grey[400], size: 18.sp),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: key));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied to clipboard'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading:
            widget.canSkip
                ? IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[400]),
                  onPressed: () => Navigator.pop(context),
                )
                : null,
        actions: [
          TextButton(
            onPressed: () {
              WhatIsNostrModal.show(context);
            },
            child: Text(
              'What is Nostr?',
              style: TextStyle(color: const Color(0xFF9945FF), fontSize: 14.sp),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20.h),

                // Logo/Icon
                Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9945FF), Color(0xFF14F195)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9945FF).withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 50.sp,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 32.h),

                // Title
                Text(
                  'Your Decentralized Identity',
                  style: TextStyle(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),

                // Subtitle
                Text(
                  'Create or import your Nostr identity to join the decentralized social network and access P2P trading.',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.grey[400],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40.h),

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red[300],
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],

                // Import fields (if showing)
                if (_showImportFields) ...[
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111128),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Existing Keys',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Private Key (nsec)',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[400],
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: _nsecController,
                          obscureText: _obscureNsec,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontFamily: 'monospace',
                          ),
                          decoration: InputDecoration(
                            hintText: 'nsec1...',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            filled: true,
                            fillColor: const Color(0xFF0C0C1A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNsec
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey[500],
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureNsec = !_obscureNsec;
                                });
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showImportFields = false;
                                    _errorMessage = null;
                                  });
                                },
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isCreatingKeys ? null : _importKeys,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF14F195),
                                  padding: EdgeInsets.symmetric(vertical: 14.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                                child:
                                    _isCreatingKeys
                                        ? SizedBox(
                                          width: 20.w,
                                          height: 20.w,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.black,
                                            ),
                                          ),
                                        )
                                        : Text(
                                          'Import',
                                          style: TextStyle(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Main action buttons
                  // Create New Identity button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreatingKeys ? null : _createNewIdentity,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9945FF),
                        padding: EdgeInsets.symmetric(vertical: 18.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 0,
                      ),
                      child:
                          _isCreatingKeys
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20.w,
                                    height: 20.w,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Text(
                                    'Creating Identity...',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 22.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'Create New Identity',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Import Existing button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed:
                          _isCreatingKeys
                              ? null
                              : () {
                                setState(() {
                                  _showImportFields = true;
                                  _errorMessage = null;
                                });
                              },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 18.h),
                        side: BorderSide(color: Colors.grey[600]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.download,
                            color: Colors.grey[300],
                            size: 22.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Import Existing Keys',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[300],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                SizedBox(height: 32.h),

                // Benefits section
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111128),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    children: [
                      _buildBenefitRow(
                        Icons.bolt,
                        Colors.orange,
                        'Send & receive Bitcoin tips (Zaps)',
                      ),
                      SizedBox(height: 16.h),
                      _buildBenefitRow(
                        Icons.swap_horiz,
                        Colors.green,
                        'Access P2P Bitcoin trading',
                      ),
                      SizedBox(height: 16.h),
                      _buildBenefitRow(
                        Icons.chat_bubble_outline,
                        Colors.blue,
                        'Direct encrypted messages',
                      ),
                      SizedBox(height: 16.h),
                      _buildBenefitRow(
                        Icons.public,
                        const Color(0xFF14F195),
                        'Join global decentralized social',
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 32.h),

                // Skip option
                if (widget.canSkip && !_showImportFields)
                  TextButton(
                    onPressed: () {
                      NostrOnboardingManager.markIntroSeen();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[500],
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

  Widget _buildBenefitRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, color: color, size: 18.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[300]),
          ),
        ),
      ],
    );
  }
}
