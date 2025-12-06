// ignore_for_file: unused_element
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/widgets/painters/painters.dart';
import 'package:sabi_wallet/features/onboarding/domain/models/contact.dart';
import 'wallet_success_screen.dart';

import '../providers/onboarding_provider.dart';

class RecoverySetScreen extends ConsumerWidget {
  const RecoverySetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedContacts = ref.watch(onboardingNotifierProvider).contactList;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 31, vertical: 30),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CustomPaint(
                            size: Size(56, 56),
                            painter: CheckCirclePainter(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Recovery Set!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.accentGreen,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const SizedBox(
                        width: 337,
                        child: Text(
                          'Your wallet is now protected. These people can help you recover if your phone loss or spoil.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CustomPaint(
                                  size: Size(20, 20),
                                  painter: ShieldIconPainter(),
                                ),
                                const SizedBox(width: 17),
                                const Text(
                                  'Your Recovery Guys',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            ...selectedContacts.asMap().entries.map((entry) {
                              final contact = entry.value;
                              final isLast =
                                  entry.key == selectedContacts.length - 1;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: isLast ? 0 : 17,
                                ),
                                child: _buildContactItem(contact),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(21),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const SizedBox(
                          width: 309,
                          child: Text(
                            'Each person don receive one encrypted share via Nostr DM. If you need to recover, any 3 of them go help you get your wallet back.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  // Example in RecoverySetScreen (bottom button)
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const WalletSuccessScreen()),
                      (route) => false, // Clear onboarding stack
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Continue to Wallet', style: TextStyle(color: AppColors.surface)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactItem(Contact contact) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary,
                child: Text(
                  contact.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background),
                  ),
                  child: const Center(
                    child: CustomPaint(
                      size: Size(14, 14),
                      painter: SmallCheckIconPainter(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contact.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                contact.phone,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '✓ Share is send',
                style: TextStyle(
                  color: AppColors.accentGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

extension on Set<Contact> {
  get selectedList => null;

  get list => null;
}

class CheckCirclePainter extends CustomPainter {
  const CheckCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.accentGreen
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.425;

    final path = Path();
    path.addArc(Rect.fromCircle(center: center, radius: radius), -1.9, 5.5);
    canvas.drawPath(path, paint);

    final checkPath = Path();
    checkPath.moveTo(size.width * 0.375, size.height * 0.46);
    checkPath.lineTo(size.width * 0.5, size.height * 0.583);
    checkPath.lineTo(size.width * 0.917, size.height * 0.167);
    canvas.drawPath(checkPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SmallCheckIconPainter extends CustomPainter {
  const SmallCheckIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45;

    final circlePath =
        Path()
          ..addArc(Rect.fromCircle(center: center, radius: radius), -1.9, 5.5);

    final checkPath =
        Path()
          ..moveTo(size.width * 0.375, size.height * 0.46)
          ..lineTo(size.width * 0.5, size.height * 0.583)
          ..lineTo(size.width * 0.917, size.height * 0.167);

    canvas.drawPath(circlePath, paint);
    canvas.drawPath(checkPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
