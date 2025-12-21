import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'social_recovery_service.dart';

/// Success screen shown after recovery shares are sent
class SocialRecoverySuccessScreen extends StatefulWidget {
  final List<RecoveryContact> contacts;

  const SocialRecoverySuccessScreen({
    Key? key,
    required this.contacts,
  }) : super(key: key);

  @override
  State<SocialRecoverySuccessScreen> createState() =>
      _SocialRecoverySuccessScreenState();
}

class _SocialRecoverySuccessScreenState
    extends State<SocialRecoverySuccessScreen> {
  @override
  void initState() {
    super.initState();
    _showConfetti();
  }

  void _showConfetti() {
    Confetti.launch(
      context,
      options: const ConfettiOptions(
        particleCount: 100,
        spread: 360,
        y: 0.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Success icon
                      Container(
                        width: 80.w,
                        height: 80.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FFB2).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(40.r),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check_circle,
                            color: const Color(0xFF00FFB2),
                            size: 48.sp,
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // Title
                      Text(
                        'Recovery Set!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // Description
                      Text(
                        'Each person received one encrypted share via Nostr DM',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 14.sp,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 32.h),

                      // Contact list
                      ...widget.contacts.map(
                        (contact) => Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF111128),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            padding: EdgeInsets.all(16.w),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 44.w,
                                  height: 44.w,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7931A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      contact.name.isNotEmpty
                                          ? contact.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),

                                // Name
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (contact.phoneNumber != null)
                                        Text(
                                          contact.phoneNumber!,
                                          style: TextStyle(
                                            color: const Color(0xFFA1A1B2),
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Check mark
                                Icon(
                                  Icons.check_circle,
                                  color: const Color(0xFF00FFB2),
                                  size: 20.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Continue button
            Padding(
              padding: EdgeInsets.all(16.w),
              child: SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/home', (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF7931A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Continue to Wallet',
                    style: TextStyle(
                      color: const Color(0xFF0C0C1A),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
