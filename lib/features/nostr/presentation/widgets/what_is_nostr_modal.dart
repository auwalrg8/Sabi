import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "What is Nostr?" educational modal
/// Shows an explanation of Nostr for new users with key benefits
class WhatIsNostrModal extends StatelessWidget {
  final VoidCallback? onGetStarted;
  final bool showGetStartedButton;

  const WhatIsNostrModal({
    super.key,
    this.onGetStarted,
    this.showGetStartedButton = false,
  });

  /// Shows the modal as a bottom sheet
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onGetStarted,
    bool showGetStartedButton = false,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => WhatIsNostrModal(
            onGetStarted: onGetStarted,
            showGetStartedButton: showGetStartedButton,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with purple icon
                  Center(
                    child: Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9945FF), Color(0xFF14F195)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Icon(
                        Icons.lan_outlined,
                        size: 40.sp,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Title
                  Center(
                    child: Text(
                      'What is Nostr?',
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Center(
                    child: Text(
                      'Notes and Other Stuff Transmitted by Relays',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Main explanation
                  Text(
                    'Nostr is a decentralized social protocol that gives you true ownership of your identity and data. Unlike traditional social media, no company controls your account.',
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: Colors.grey[300],
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Feature cards
                  _buildFeatureCard(
                    icon: Icons.key,
                    iconColor: const Color(0xFFFFD700),
                    title: 'Your Keys, Your Identity',
                    description:
                        'Your identity is a cryptographic key pair. You own it forever - no one can ban or shadowban you.',
                  ),
                  SizedBox(height: 12.h),
                  _buildFeatureCard(
                    icon: Icons.hub_outlined,
                    iconColor: const Color(0xFF14F195),
                    title: 'Decentralized Network',
                    description:
                        'Messages are sent through relays - independent servers anyone can run. Your data isn\'t locked in any one platform.',
                  ),
                  SizedBox(height: 12.h),
                  _buildFeatureCard(
                    icon: Icons.bolt,
                    iconColor: const Color(0xFFFF9500),
                    title: 'Bitcoin-Native',
                    description:
                        'Send and receive Bitcoin tips instantly via Lightning. No intermediaries, no fees to platforms.',
                  ),
                  SizedBox(height: 12.h),
                  _buildFeatureCard(
                    icon: Icons.lock_outline,
                    iconColor: const Color(0xFF9945FF),
                    title: 'Censorship Resistant',
                    description:
                        'No central authority can delete your posts or suspend your account. Your voice remains yours.',
                  ),
                  SizedBox(height: 12.h),
                  _buildFeatureCard(
                    icon: Icons.swap_horiz,
                    iconColor: const Color(0xFF00D4FF),
                    title: 'Portable & Interoperable',
                    description:
                        'Use any Nostr app with the same identity. Switch apps anytime without losing followers or posts.',
                  ),
                  SizedBox(height: 24.h),

                  // Key concepts
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔑 Key Concepts',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        _buildKeyConceptRow(
                          'npub',
                          'Your public key - share this like a username',
                        ),
                        SizedBox(height: 8.h),
                        _buildKeyConceptRow(
                          'nsec',
                          'Your private key - NEVER share this!',
                        ),
                        SizedBox(height: 8.h),
                        _buildKeyConceptRow(
                          'Relays',
                          'Servers that store and forward your messages',
                        ),
                        SizedBox(height: 8.h),
                        _buildKeyConceptRow(
                          'Zaps',
                          'Bitcoin tips sent via Lightning Network',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Get Started button or Close button
                  if (showGetStartedButton) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onGetStarted?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9945FF),
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        showGetStartedButton ? 'Maybe Later' : 'Got It',
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: iconColor, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey[400],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyConceptRow(String term, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text(
            term,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.purple[300],
              fontFamily: 'monospace',
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            description,
            style: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
          ),
        ),
      ],
    );
  }
}

/// Helper class to manage Nostr onboarding state
class NostrOnboardingManager {
  static const _hasSeenNostrIntroKey = 'has_seen_nostr_intro';
  static const _hasCompletedNostrSetupKey = 'has_completed_nostr_setup';

  /// Check if user has seen the Nostr intro
  static Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenNostrIntroKey) ?? false;
  }

  /// Mark that user has seen the Nostr intro
  static Future<void> markIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenNostrIntroKey, true);
  }

  /// Check if user has completed Nostr setup (has keys)
  static Future<bool> hasCompletedSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasCompletedNostrSetupKey) ?? false;
  }

  /// Mark that user has completed Nostr setup
  static Future<void> markSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasCompletedNostrSetupKey, true);
  }

  /// Reset onboarding state (for testing)
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasSeenNostrIntroKey);
    await prefs.remove(_hasCompletedNostrSetupKey);
  }
}
