/// P2P Escrow Info Screen - Educational content about how P2P works
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Educational screen explaining P2P escrow, risks, and tips
class P2PEscrowInfoScreen extends StatelessWidget {
  const P2PEscrowInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C1A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'How P2P Trading Works',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero section
            _buildHeroSection(),
            SizedBox(height: 24.h),

            // What is Escrow
            _buildSection(
              icon: Icons.lock_outline,
              iconColor: const Color(0xFF00FFB2),
              title: 'What is Escrow?',
              content: '''
In P2P trading, "escrow" means the seller's Bitcoin is locked via a Lightning invoice during the trade.

• The seller creates a Lightning invoice for the trade amount
• This invoice is only valid for 4 minutes
• If the buyer pays fiat and the seller confirms, the invoice gets paid
• If the timer expires, the invoice becomes invalid - no funds move

Unlike traditional escrow, there's NO third party holding funds. It's pure Lightning Network magic! ⚡
''',
            ),
            SizedBox(height: 20.h),

            // Why 4 Minutes
            _buildSection(
              icon: Icons.timer_outlined,
              iconColor: const Color(0xFFF7931A),
              title: 'Why Only 4 Minutes?',
              content: '''
The 4-minute window exists because:

• Bitcoin price changes every second
• The seller locks in a rate when creating the invoice
• If payment takes too long, the rate becomes stale
• Short windows protect both parties from rate manipulation

💡 Tip: Have your payment app open BEFORE starting a trade!
''',
            ),
            SizedBox(height: 20.h),

            // Trade Code Verification
            _buildSection(
              icon: Icons.verified_user_outlined,
              iconColor: const Color(0xFF6B4EFF),
              title: 'Trade Code Verification',
              content: '''
Some sellers enable "Trade Code" for extra security:

• A 6-digit code is generated for each trade
• You see the first 3 digits
• The seller sees the last 3 digits
• Both must share codes to verify identity

This prevents scammers from claiming they made a payment they didn't make.

✅ Optional but recommended for larger trades
''',
            ),
            SizedBox(height: 20.h),

            // The Trade Flow
            _buildSection(
              icon: Icons.swap_horiz,
              iconColor: const Color(0xFF00D4FF),
              title: 'The Trade Flow',
              content: '''
FOR BUYERS (You want Bitcoin):
1. Browse sell offers and select one
2. Enter amount and start trade (4-min timer begins)
3. Send fiat payment using the seller's details
4. Upload payment proof (optional but recommended)
5. Exchange trade codes if enabled
6. Wait for seller to release sats

FOR SELLERS (You want fiat):
1. Create a sell offer with your price and limits
2. When a buyer accepts, you'll be notified
3. A Lightning invoice is created automatically
4. Verify the buyer's fiat payment
5. Exchange trade codes if enabled
6. Release the sats to complete the trade
''',
            ),
            SizedBox(height: 20.h),

            // What Could Go Wrong
            _buildSection(
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFFF6B6B),
              title: 'What Could Go Wrong',
              isWarning: true,
              content: '''
⚠️ UNDERSTAND THESE RISKS:

Timer Expires Before Payment
→ Trade is cancelled. Start a new one.

Buyer Claims Paid But Didn't
→ Seller keeps their Bitcoin. NEVER release without verification!

Seller Doesn't Release After Payment
→ This is the main risk for buyers. You may lose your fiat.
→ Only trade with users who have good ratings.

Wrong Amount Sent
→ May cause delays or disputes. Always double-check!

Network Issues
→ Invoice may fail. Retry with a new trade.

⛔ THERE IS NO DISPUTE SYSTEM
Since there's no server, we cannot resolve disputes. Trade carefully!
''',
            ),
            SizedBox(height: 20.h),

            // Safety Tips
            _buildSection(
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFF00FFB2),
              title: 'Safety Tips',
              content: '''
✅ DO:
• Start with small test trades
• Check the trader's ratings and history
• Have payment app open before starting
• Use Trade Code verification when offered
• Keep proof of all payments
• Read payment instructions carefully

❌ DON'T:
• Rush into large trades with new users
• Release sats without verifying payment
• Ignore the timer - it's serious!
• Trade more than you can afford to lose
• Share trade details publicly
''',
            ),
            SizedBox(height: 20.h),

            // No Server Disclaimer
            _buildNoServerDisclaimer(),
            SizedBox(height: 32.h),

            // Got it button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7931A),
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Text(
                  'I Understand',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF7931A).withOpacity(0.2),
            const Color(0xFFF7931A).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFF7931A).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 48.sp,
            color: const Color(0xFFF7931A),
          ),
          SizedBox(height: 12.h),
          Text(
            'Peer-to-Peer Trading',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Trade Bitcoin directly with other users.\nNo middlemen. No custody. Pure Lightning. ⚡',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFA1A1B2),
              fontSize: 14.sp,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    bool isWarning = false,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isWarning 
            ? const Color(0xFFFF6B6B).withOpacity(0.1)
            : const Color(0xFF111128),
        borderRadius: BorderRadius.circular(16.r),
        border: isWarning 
            ? Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, color: iconColor, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            content.trim(),
            style: TextStyle(
              color: const Color(0xFFA1A1B2),
              fontSize: 13.sp,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoServerDisclaimer() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6B4EFF).withOpacity(0.2),
            const Color(0xFF6B4EFF).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF6B4EFF).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: const Color(0xFF6B4EFF),
                size: 24.sp,
              ),
              SizedBox(width: 12.w),
              Text(
                'No Server, No Tracking',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'Sabi Wallet has no server. We cannot:\n'
            '• See your trades or balances\n'
            '• Intervene in disputes\n'
            '• Reverse or cancel transactions\n'
            '• Know who you trade with\n\n'
            'This is true financial freedom - but it comes with responsibility. '
            'You are in full control, and that means you must trade carefully.',
            style: TextStyle(
              color: const Color(0xFFA1A1B2),
              fontSize: 13.sp,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick info bottom sheet for inline help
class P2PQuickInfoSheet extends StatelessWidget {
  final String topic;

  const P2PQuickInfoSheet({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 24.h),
          _buildContent(),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Got it',
                style: TextStyle(
                  color: const Color(0xFFF7931A),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (topic) {
      case 'timer':
        return _buildInfoContent(
          icon: Icons.timer_outlined,
          color: const Color(0xFFF7931A),
          title: 'Payment Timer',
          body: 'You have 4 minutes to complete payment. '
              'This protects both parties from price changes. '
              'If time runs out, the trade is cancelled automatically.',
        );
      case 'trade_code':
        return _buildInfoContent(
          icon: Icons.verified_user_outlined,
          color: const Color(0xFF6B4EFF),
          title: 'Trade Code',
          body: 'Trade codes add security by splitting a 6-digit code between buyer and seller. '
              'Both must share their part to verify identity before completing the trade.',
        );
      case 'escrow':
        return _buildInfoContent(
          icon: Icons.lock_outline,
          color: const Color(0xFF00FFB2),
          title: 'Lightning Escrow',
          body: 'Your sats are locked via a Lightning invoice during the trade. '
              'No third party holds your funds - it\'s pure Bitcoin magic!',
        );
      case 'release':
        return _buildInfoContent(
          icon: Icons.send,
          color: const Color(0xFF00D4FF),
          title: 'Releasing Sats',
          body: 'When you release sats, the Lightning invoice is paid and '
              'the buyer receives their Bitcoin. This action is IRREVERSIBLE. '
              'Only release after confirming payment!',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInfoContent({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 32.sp),
        ),
        SizedBox(height: 16.h),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFA1A1B2),
            fontSize: 14.sp,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Show quick info bottom sheet
void showP2PQuickInfo(BuildContext context, String topic) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => P2PQuickInfoSheet(topic: topic),
  );
}
