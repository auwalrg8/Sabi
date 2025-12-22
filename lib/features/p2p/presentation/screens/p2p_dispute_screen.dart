import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';

/// P2P Dispute Screen - Submit dispute via Nostr DM
class P2PDisputeScreen extends ConsumerStatefulWidget {
  final P2POfferModel offer;
  final double tradeAmount;

  const P2PDisputeScreen({
    super.key,
    required this.offer,
    required this.tradeAmount,
  });

  @override
  ConsumerState<P2PDisputeScreen> createState() => _P2PDisputeScreenState();
}

class _P2PDisputeScreenState extends ConsumerState<P2PDisputeScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final formatter = NumberFormat('#,###');
  
  String _selectedReason = 'Payment not received';
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  final List<String> _proofPaths = [];

  final List<String> _disputeReasons = [
    'Payment not received',
    'Wrong amount received',
    'Seller not responding',
    'Fraudulent activity',
    'Other',
  ];

  // Sabi team npubs for dispute resolution
  static const List<String> _sabiTeamNpubs = [
    'npub1sabi...dispute1',
    'npub1sabi...dispute2',
    'npub1sabi...dispute3',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitDispute() async {
    if (_descriptionController.text.trim().isEmpty) {
      _showError('Please describe your issue');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // TODO: Implement actual Nostr encrypted DM to Sabi team
      // Send to team members: ${_sabiTeamNpubs.join(', ')}
      // 1. Get user's private key
      // 2. Encrypt message with each Sabi team member's public key
      // 3. Send NIP-04 encrypted DM to each
      // 4. Store dispute locally for tracking
      debugPrint('Sending dispute to ${_sabiTeamNpubs.length} Sabi team members');

      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('Failed to submit dispute. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF6B6B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return _buildSubmittedView();
    }

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
          'Open Dispute',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Warning Card
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: const Color(0xFFFF6B6B).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: const Color(0xFFFF6B6B),
                          size: 24.sp,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'Disputes are reviewed by Sabi moderators. False claims may result in account restrictions.',
                            style: TextStyle(
                              color: const Color(0xFFFF6B6B),
                              fontSize: 13.sp,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Trade Info
                  _SectionTitle(title: 'Trade Information'),
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111128),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Merchant',
                          value: widget.offer.name,
                        ),
                        SizedBox(height: 12.h),
                        _InfoRow(
                          label: 'Amount',
                          value: '₦${formatter.format(widget.tradeAmount.toInt())}',
                        ),
                        SizedBox(height: 12.h),
                        _InfoRow(
                          label: 'Payment Method',
                          value: widget.offer.paymentMethod,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Dispute Reason
                  _SectionTitle(title: 'Reason for Dispute'),
                  SizedBox(height: 12.h),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF111128),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Column(
                      children: _disputeReasons.map((reason) {
                        final isSelected = _selectedReason == reason;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedReason = reason),
                          child: Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: reason != _disputeReasons.last
                                    ? BorderSide(
                                        color: const Color(0xFF2A2A3E),
                                        width: 1,
                                      )
                                    : BorderSide.none,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 22.w,
                                  height: 22.h,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFF7931A)
                                          : const Color(0xFFA1A1B2),
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 12.w,
                                            height: 12.h,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFF7931A),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                SizedBox(width: 12.w),
                                Text(
                                  reason,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Description
                  _SectionTitle(title: 'Describe Your Issue'),
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111128),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: 'Provide details about what happened...',
                        hintStyle: TextStyle(
                          color: const Color(0xFF6B6B80),
                          fontSize: 14.sp,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Evidence Upload
                  _SectionTitle(title: 'Upload Evidence (Optional)'),
                  SizedBox(height: 12.h),
                  GestureDetector(
                    onTap: _pickEvidence,
                    child: Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111128),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: const Color(0xFF2A2A3E),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            color: const Color(0xFFA1A1B2),
                            size: 40.sp,
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'Tap to upload screenshots or proof',
                            style: TextStyle(
                              color: const Color(0xFFA1A1B2),
                              fontSize: 14.sp,
                            ),
                          ),
                          if (_proofPaths.isNotEmpty) ...[
                            SizedBox(height: 12.h),
                            Text(
                              '${_proofPaths.length} file(s) selected',
                              style: TextStyle(
                                color: const Color(0xFF00FFB2),
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Encrypted Notice
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111128),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: const Color(0xFF00FFB2),
                          size: 20.sp,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'Your dispute will be encrypted and sent via Nostr to our moderation team.',
                            style: TextStyle(
                              color: const Color(0xFFA1A1B2),
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Submit Button
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: const BoxDecoration(
              color: Color(0xFF111128),
              border: Border(
                top: BorderSide(color: Color(0xFF2A2A3E)),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitDispute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B),
                    disabledBackgroundColor: const Color(0xFF2A2A3E),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 24.w,
                          height: 24.h,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          'Submit Dispute',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7931A).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pending_actions,
                  color: const Color(0xFFF7931A),
                  size: 64.sp,
                ),
              ),
              SizedBox(height: 32.h),
              Text(
                'Dispute Submitted',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Your dispute has been submitted to our moderation team. You will receive updates via Nostr DM.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFA1A1B2),
                  fontSize: 14.sp,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 32.h),

              // Dispute ID
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF111128),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Dispute ID: ',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 14.sp,
                      ),
                    ),
                    Text(
                      '#DSP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                      style: TextStyle(
                        color: const Color(0xFFF7931A),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 48.h),

              // Timeline
              _TimelineItem(
                icon: Icons.check_circle,
                title: 'Dispute Submitted',
                subtitle: 'Just now',
                isCompleted: true,
                isFirst: true,
              ),
              _TimelineItem(
                icon: Icons.hourglass_empty,
                title: 'Under Review',
                subtitle: 'Moderators will review your case',
                isCompleted: false,
              ),
              _TimelineItem(
                icon: Icons.gavel,
                title: 'Resolution',
                subtitle: 'Decision will be announced',
                isCompleted: false,
                isLast: true,
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF7931A),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    'Back to P2P',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickEvidence() async {
    // TODO: Implement image picker
    setState(() {
      _proofPaths.add('proof_${_proofPaths.length + 1}.jpg');
    });
  }
}

/// Section Title
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Info Row
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFFA1A1B2),
            fontSize: 14.sp,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Timeline Item
class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isFirst;
  final bool isLast;

  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32.w,
              height: 32.h,
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFF00FFB2)
                    : const Color(0xFF2A2A3E),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isCompleted ? const Color(0xFF0C0C1A) : const Color(0xFF6B6B80),
                size: 18.sp,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40.h,
                color: isCompleted ? const Color(0xFF00FFB2) : const Color(0xFF2A2A3E),
              ),
          ],
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isCompleted ? Colors.white : const Color(0xFF6B6B80),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
