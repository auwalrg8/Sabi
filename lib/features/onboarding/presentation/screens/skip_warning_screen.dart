import 'package:flutter/material.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'wallet_success_screen.dart';

class SkipWarningScreen extends StatefulWidget {
  const SkipWarningScreen({super.key});

  @override
  State<SkipWarningScreen> createState() => _SkipWarningScreenState();
}

class _SkipWarningScreenState extends State<SkipWarningScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isCorrect = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(
        () =>
            _isCorrect =
                _controller.text.trim().toUpperCase() == 'I UNDERSTAND',
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.7),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: 350,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accentRed, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: CustomPaint(
                      size: const Size(40, 40),
                      painter: _WarningTrianglePainter(),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'You sure?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 22),
                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.85,
                        fontFamily: 'Inter',
                      ),
                      children: [
                        TextSpan(
                          text: 'If phone loss or spoil, ',
                          style: TextStyle(
                            color: Color(0xFFD1D5DB),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        TextSpan(
                          text: 'nobody can recover this money again',
                          style: TextStyle(
                            color: AppColors.accentRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '. All your Bitcoin will disappear forever.',
                          style: TextStyle(
                            color: Color(0xFFD1D5DB),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.67,
                            fontFamily: 'Inter',
                          ),
                          children: [
                            TextSpan(
                              text: 'Type ',
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            TextSpan(
                              text: '"I UNDERSTAND"',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: ' to continue',
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 17),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF374151),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed:
                              _isCorrect
                                  ? () {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => const WalletSuccessScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.disabled,
                            foregroundColor: AppColors.textPrimary,
                            disabledBackgroundColor: AppColors.disabled
                                .withValues(alpha: 0.5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 17),
                          ),
                          child: const Text(
                            'Skip Backup (Dangerous)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                              color: AppColors.primary,
                              width: 1,
                            ),
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 17),
                          ),
                          child: const Text(
                            'Go Back & Set Up Backup',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WarningTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.accentRed
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.125);
    path.lineTo(size.width * 0.9375, size.height * 0.875);
    path.lineTo(size.width * 0.0625, size.height * 0.875);
    path.close();

    canvas.drawPath(path, paint);

    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.375),
      Offset(size.width * 0.5, size.height * 0.625),
      paint,
    );

    final dotPaint =
        Paint()
          ..color = AppColors.accentRed
          ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.75),
      1.5,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
