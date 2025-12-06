import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/onboarding/presentation/screens/wallet_creation_animation_screen.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bip39/bip39.dart' as bip39;

class SeedPhraseScreen extends ConsumerStatefulWidget {
  const SeedPhraseScreen({super.key});

  @override
  ConsumerState<SeedPhraseScreen> createState() => _SeedPhraseScreenState();
}

class _SeedPhraseScreenState extends ConsumerState<SeedPhraseScreen> {
  List<String> _seedWords = [];
  bool _isRevealed = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMnemonic();
  }

  Future<void> _loadMnemonic() async {
    try {
      // Try to get existing mnemonic from secure storage
      final storage = ref.read(secureStorageServiceProvider);
      String? mnemonic = await storage.getMnemonic();
      
      // If no mnemonic exists, generate a new one (shouldn't happen in normal flow)
      if (mnemonic == null || mnemonic.isEmpty) {
        mnemonic = bip39.generateMnemonic(strength: 128); // 128 bits = 12 words
        await storage.saveMnemonic(mnemonic);
      }
      
      setState(() {
        _seedWords = mnemonic!.split(' ');
        _isLoading = false;
      });
    } catch (e) {
      // Fallback: generate new mnemonic
      final mnemonic = bip39.generateMnemonic(strength: 128);
      final storage = ref.read(secureStorageServiceProvider);
      await storage.saveMnemonic(mnemonic);
      
      setState(() {
        _seedWords = mnemonic.split(' ');
        _isLoading = false;
      });
    }
  }

  void _onRevealPressed() {
    setState(() => _isRevealed = true);
  }

  void _onHidePressed() {
    setState(() => _isRevealed = false);
  }

  void _onCopyToClipboard() {
    final seedPhrase = _seedWords.join(' ');
    Clipboard.setData(ClipboardData(text: seedPhrase));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Seed phrase copied to clipboard'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _onWroteThemDown() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerifyBackupScreen(seedWords: _seedWords),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(31, 29, 31, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CustomPaint(
                        painter: BackArrowPainter(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your 12-Word Backup',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            height: 32 / 18,
                          ),
                        ),
                        Text(
                          'Write these words down in order',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 20 / 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildWarningCard(),
                      const SizedBox(height: 30),
                      _buildSeedPhraseCard(),
                      const SizedBox(height: 30),
                      _buildSecurityTipsCard(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildBottomButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Color(0xFF111128).withValues(alpha: 0.05),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CustomPaint(
              painter: WarningIconPainter(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Never share your seed phrase',
                  style: TextStyle(
                    color: AppColors.accentRed,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 24 / 14,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Anyone with these 12 words can steal your Bitcoin. Write am down for paper and keep am safe.',
                  style: TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 22 / 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeedPhraseCard() {
    return Container(
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
        children: [
          Stack(
            children: [
              _buildSeedGrid(),
              if (!_isRevealed)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_isRevealed)
            _buildRevealButton()
          else
            _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSeedGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _seedWords.length,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(
                '${index + 1}.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 20 / 12,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _seedWords[index],
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 24 / 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevealButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _onRevealPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(
                painter: EyeIconPainter(),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Reveal Seed Phrase',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 24 / 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _onHidePressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1),
              elevation: 0,
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CustomPaint(
                    painter: EyeOffIconPainter(),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Hide Seed Phrase',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 24 / 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _onCopyToClipboard,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CustomPaint(
                    painter: CopyIconPainter(),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Copy to Clipboard',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 24 / 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityTipsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Security Tips',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 24 / 14,
            ),
          ),
          const SizedBox(height: 12),
          _buildSecurityTip('Write am down for paper, no screenshot'),
          const SizedBox(height: 12),
          _buildSecurityTip('Keep multiple copies for different safe\nplaces'),
          const SizedBox(height: 12),
          _buildSecurityTip('Never share am with anybody, even Sabi\nsupport'),
        ],
      ),
    );
  }

  Widget _buildSecurityTip(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CustomPaint(
              painter: CheckIconPainter(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 20 / 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isRevealed ? _onWroteThemDown : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.disabled,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'I Wrote Them Down',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 24 / 14,
          ),
        ),
      ),
    );
  }
}

class VerifyBackupScreen extends StatefulWidget {
  final List<String> seedWords;

  const VerifyBackupScreen({
    super.key,
    required this.seedWords,
  });

  @override
  State<VerifyBackupScreen> createState() => _VerifyBackupScreenState();
}

class _VerifyBackupScreenState extends State<VerifyBackupScreen> {
  final _word3Controller = TextEditingController();
  final _word7Controller = TextEditingController();
  final _word11Controller = TextEditingController();

  @override
  void dispose() {
    _word3Controller.dispose();
    _word7Controller.dispose();
    _word11Controller.dispose();
    super.dispose();
  }

  bool _canVerify() {
    return _word3Controller.text.isNotEmpty &&
        _word7Controller.text.isNotEmpty &&
        _word11Controller.text.isNotEmpty;
  }

  void _onVerify() {
    final word3 = _word3Controller.text.trim().toLowerCase();
    final word7 = _word7Controller.text.trim().toLowerCase();
    final word11 = _word11Controller.text.trim().toLowerCase();

    if (word3 == widget.seedWords[2] &&
        word7 == widget.seedWords[6] &&
        word11 == widget.seedWords[10]) {
      // Show wallet creation animation, then navigate to home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const WalletCreationAnimationScreen(),
        ),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Incorrect words. Please try again.'),
          backgroundColor: AppColors.accentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(31, 29, 31, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CustomPaint(
                        painter: BackArrowPainter(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Verify Your Backup',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            height: 32 / 18,
                          ),
                        ),
                        Text(
                          'Enter the missing words to confirm',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 20 / 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
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
                        Text(
                          'Enter the missing words to verify you wrote them down correctly',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 20 / 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildWordInput('Word #3', _word3Controller),
                        const SizedBox(height: 16),
                        _buildWordInput('Word #7', _word7Controller),
                        const SizedBox(height: 16),
                        _buildWordInput('Word #11', _word11Controller),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _canVerify() ? _onVerify : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.disabled,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Verify & Continue',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 24 / 14,
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

  Widget _buildWordInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 20 / 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFF374151), width: 1),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              hintText: 'Enter word',
              hintStyle: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 17,
                vertical: 13,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }
}

class BackArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.5, size.width * 0.79);
    path.lineTo(size.width * 0.21, size.width * 0.5);
    path.lineTo(size.width * 0.5, size.width * 0.21);

    canvas.drawPath(path, paint);

    canvas.drawLine(
      Offset(size.width * 0.79, size.width * 0.5),
      Offset(size.width * 0.21, size.width * 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WarningIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.906, size.width * 0.75);
    path.lineTo(size.width * 0.572, size.width * 0.167);
    path.cubicTo(
      size.width * 0.565, size.width * 0.154,
      size.width * 0.543, size.width * 0.145,
      size.width * 0.540, size.width * 0.136,
    );
    path.cubicTo(
      size.width * 0.529, size.width * 0.125,
      size.width * 0.518, size.width * 0.124,
      size.width * 0.495, size.width * 0.124,
    );
    path.cubicTo(
      size.width * 0.485, size.width * 0.124,
      size.width * 0.471, size.width * 0.125,
      size.width * 0.458, size.width * 0.136,
    );
    path.cubicTo(
      size.width * 0.448, size.width * 0.145,
      size.width * 0.427, size.width * 0.154,
      size.width * 0.427, size.width * 0.167,
    );
    path.lineTo(size.width * 0.094, size.width * 0.75);
    path.cubicTo(
      size.width * 0.086, size.width * 0.763,
      size.width * 0.083, size.width * 0.780,
      size.width * 0.083, size.width * 0.794,
    );
    path.cubicTo(
      size.width * 0.083, size.width * 0.807,
      size.width * 0.087, size.width * 0.824,
      size.width * 0.094, size.width * 0.837,
    );
    path.cubicTo(
      size.width * 0.101, size.width * 0.851,
      size.width * 0.114, size.width * 0.864,
      size.width * 0.125, size.width * 0.874,
    );
    path.cubicTo(
      size.width * 0.138, size.width * 0.883,
      size.width * 0.153, size.width * 0.888,
      size.width * 0.167, size.width * 0.875,
    );
    path.lineTo(size.width * 0.833, size.width * 0.875);
    path.cubicTo(
      size.width * 0.848, size.width * 0.875,
      size.width * 0.862, size.width * 0.870,
      size.width * 0.875, size.width * 0.861,
    );
    path.cubicTo(
      size.width * 0.888, size.width * 0.851,
      size.width * 0.898, size.width * 0.838,
      size.width * 0.906, size.width * 0.825,
    );
    path.cubicTo(
      size.width * 0.913, size.width * 0.812,
      size.width * 0.917, size.width * 0.796,
      size.width * 0.917, size.width * 0.783,
    );
    path.cubicTo(
      size.width * 0.917, size.width * 0.770,
      size.width * 0.913, size.width * 0.763,
      size.width * 0.906, size.width * 0.75,
    );
    path.close();

    canvas.drawPath(path, paint);

    canvas.drawLine(
      Offset(size.width * 0.5, size.width * 0.375),
      Offset(size.width * 0.5, size.width * 0.542),
      paint,
    );

    canvas.drawLine(
      Offset(size.width * 0.5, size.width * 0.708),
      Offset(size.width * 0.504, size.width * 0.708),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class EyeIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path1 = Path();
    path1.moveTo(size.width * 0.086, size.width * 0.515);
    path1.cubicTo(
      size.width * 0.120, size.width * 0.403,
      size.width * 0.177, size.width * 0.333,
      size.width * 0.251, size.width * 0.284,
    );
    path1.cubicTo(
      size.width * 0.325, size.width * 0.235,
      size.width * 0.411, size.width * 0.208,
      size.width * 0.500, size.width * 0.208,
    );
    path1.cubicTo(
      size.width * 0.589, size.width * 0.208,
      size.width * 0.675, size.width * 0.235,
      size.width * 0.749, size.width * 0.284,
    );
    path1.cubicTo(
      size.width * 0.823, size.width * 0.333,
      size.width * 0.880, size.width * 0.403,
      size.width * 0.914, size.width * 0.515,
    );
    path1.cubicTo(
      size.width * 0.880, size.width * 0.597,
      size.width * 0.823, size.width * 0.666,
      size.width * 0.749, size.width * 0.716,
    );
    path1.cubicTo(
      size.width * 0.675, size.width * 0.765,
      size.width * 0.589, size.width * 0.792,
      size.width * 0.500, size.width * 0.792,
    );
    path1.cubicTo(
      size.width * 0.411, size.width * 0.792,
      size.width * 0.325, size.width * 0.765,
      size.width * 0.251, size.width * 0.716,
    );
    path1.cubicTo(
      size.width * 0.177, size.width * 0.666,
      size.width * 0.120, size.width * 0.597,
      size.width * 0.086, size.width * 0.515,
    );
    path1.close();

    canvas.drawPath(path1, paint);

    final path2 = Path();
    path2.addOval(Rect.fromCircle(
      center: Offset(size.width * 0.5, size.width * 0.5),
      radius: size.width * 0.125,
    ));

    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class EyeOffIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path1 = Path();
    path1.moveTo(size.width * 0.447, size.width * 0.212);
    path1.cubicTo(
      size.width * 0.544, size.width * 0.199,
      size.width * 0.642, size.width * 0.205,
      size.width * 0.727, size.width * 0.270,
    );
    path1.cubicTo(
      size.width * 0.811, size.width * 0.319,
      size.width * 0.868, size.width * 0.395,
      size.width * 0.914, size.width * 0.485,
    );

    canvas.drawPath(path1, paint);

    final path2 = Path();
    path2.moveTo(size.width * 0.587, size.width * 0.590);
    path2.cubicTo(
      size.width * 0.563, size.width * 0.613,
      size.width * 0.532, size.width * 0.625,
      size.width * 0.499, size.width * 0.625,
    );
    path2.cubicTo(
      size.width * 0.466, size.width * 0.625,
      size.width * 0.435, size.width * 0.613,
      size.width * 0.412, size.width * 0.588,
    );
    path2.cubicTo(
      size.width * 0.388, size.width * 0.565,
      size.width * 0.375, size.width * 0.534,
      size.width * 0.375, size.width * 0.501,
    );
    path2.cubicTo(
      size.width * 0.375, size.width * 0.468,
      size.width * 0.387, size.width * 0.437,
      size.width * 0.410, size.width * 0.413,
    );

    canvas.drawPath(path2, paint);

    final path3 = Path();
    path3.moveTo(size.width * 0.729, size.width * 0.729);
    path3.cubicTo(
      size.width * 0.673, size.width * 0.762,
      size.width * 0.611, size.width * 0.782,
      size.width * 0.547, size.width * 0.789,
    );
    path3.cubicTo(
      size.width * 0.484, size.width * 0.796,
      size.width * 0.419, size.width * 0.789,
      size.width * 0.358, size.width * 0.769,
    );
    path3.cubicTo(
      size.width * 0.297, size.width * 0.748,
      size.width * 0.241, size.width * 0.715,
      size.width * 0.194, size.width * 0.671,
    );
    path3.cubicTo(
      size.width * 0.147, size.width * 0.627,
      size.width * 0.110, size.width * 0.574,
      size.width * 0.086, size.width * 0.515,
    );
    path3.cubicTo(
      size.width * 0.123, size.width * 0.396,
      size.width * 0.188, size.width * 0.321,
      size.width * 0.271, size.width * 0.271,
    );

    canvas.drawPath(path3, paint);

    canvas.drawLine(
      Offset(size.width * 0.083, size.width * 0.083),
      Offset(size.width * 0.917, size.width * 0.917),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CopyIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path1 = Path();
    path1.moveTo(size.width * 0.833, size.width * 0.333);
    path1.lineTo(size.width * 0.417, size.width * 0.333);
    path1.cubicTo(
      size.width * 0.371, size.width * 0.333,
      size.width * 0.333, size.width * 0.371,
      size.width * 0.333, size.width * 0.417,
    );
    path1.lineTo(size.width * 0.333, size.width * 0.833);
    path1.cubicTo(
      size.width * 0.333, size.width * 0.879,
      size.width * 0.371, size.width * 0.917,
      size.width * 0.417, size.width * 0.917,
    );
    path1.lineTo(size.width * 0.833, size.width * 0.917);
    path1.cubicTo(
      size.width * 0.879, size.width * 0.917,
      size.width * 0.917, size.width * 0.879,
      size.width * 0.917, size.width * 0.833,
    );
    path1.lineTo(size.width * 0.917, size.width * 0.417);
    path1.cubicTo(
      size.width * 0.917, size.width * 0.371,
      size.width * 0.879, size.width * 0.333,
      size.width * 0.833, size.width * 0.333,
    );
    path1.close();

    canvas.drawPath(path1, paint);

    final path2 = Path();
    path2.moveTo(size.width * 0.167, size.width * 0.667);
    path2.cubicTo(
      size.width * 0.121, size.width * 0.667,
      size.width * 0.083, size.width * 0.629,
      size.width * 0.083, size.width * 0.583,
    );
    path2.lineTo(size.width * 0.083, size.width * 0.167);
    path2.cubicTo(
      size.width * 0.083, size.width * 0.121,
      size.width * 0.121, size.width * 0.083,
      size.width * 0.167, size.width * 0.083,
    );
    path2.lineTo(size.width * 0.583, size.width * 0.083);
    path2.cubicTo(
      size.width * 0.629, size.width * 0.083,
      size.width * 0.667, size.width * 0.121,
      size.width * 0.667, size.width * 0.167,
    );

    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CheckIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFF00FFB2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path1 = Path();
    path1.moveTo(size.width * 0.908, size.width * 0.417);
    path1.cubicTo(
      size.width * 0.927, size.width * 0.510,
      size.width * 0.914, size.width * 0.607,
      size.width * 0.870, size.width * 0.692,
    );
    path1.cubicTo(
      size.width * 0.826, size.width * 0.776,
      size.width * 0.755, size.width * 0.933,
      size.width * 0.667, size.width * 0.878,
    );
    path1.cubicTo(
      size.width * 0.580, size.width * 0.823,
      size.width * 0.482, size.width * 0.894,
      size.width * 0.390, size.width * 0.902,
    );
    path1.cubicTo(
      size.width * 0.298, size.width * 0.910,
      size.width * 0.218, size.width * 0.821,
      size.width * 0.162, size.width * 0.743,
    );
    path1.cubicTo(
      size.width * 0.106, size.width * 0.665,
      size.width * 0.079, size.width * 0.572,
      size.width * 0.084, size.width * 0.477,
    );
    path1.cubicTo(
      size.width * 0.089, size.width * 0.382,
      size.width * 0.127, size.width * 0.291,
      size.width * 0.191, size.width * 0.220,
    );
    path1.cubicTo(
      size.width * 0.255, size.width * 0.150,
      size.width * 0.341, size.width * 0.103,
      size.width * 0.435, size.width * 0.088,
    );
    path1.cubicTo(
      size.width * 0.529, size.width * 0.073,
      size.width * 0.632, size.width * 0.091,
      size.width * 0.708, size.width * 0.139,
    );

    canvas.drawPath(path1, paint);

    final path2 = Path();
    path2.moveTo(size.width * 0.375, size.width * 0.458);
    path2.lineTo(size.width * 0.500, size.width * 0.583);
    path2.lineTo(size.width * 0.917, size.width * 0.167);

    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
