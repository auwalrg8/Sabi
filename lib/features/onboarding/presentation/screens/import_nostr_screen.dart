import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

enum ImportMethod { pasteKeys, scanQr, connect }

enum ImportState { inputting, importing, connected }

class ImportNostrScreen extends StatefulWidget {
  const ImportNostrScreen({super.key});

  @override
  State<ImportNostrScreen> createState() => _ImportNostrScreenState();
}

class _ImportNostrScreenState extends State<ImportNostrScreen> {
  ImportMethod selectedMethod = ImportMethod.scanQr;
  ImportState currentState = ImportState.inputting;
  final TextEditingController publicKeyController = TextEditingController();
  final TextEditingController privateKeyController = TextEditingController();
  String? selectedWallet;

  @override
  void dispose() {
    publicKeyController.dispose();
    privateKeyController.dispose();
    super.dispose();
  }

  void handleImport() async {
    setState(() {
      currentState = ImportState.importing;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      currentState = ImportState.connected;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentState == ImportState.connected) {
      return _buildConnectedState();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 31, vertical: 29),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTabBar(),
                      const SizedBox(height: 30),
                      _buildContent(),
                      const SizedBox(height: 30),
                      _buildWarningBox(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _buildBottomButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: CustomPaint(
            size: const Size(24, 24),
            painter: BackArrowPainter(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Import Nostr Keys',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 32 / 18,
                ),
              ),
              Text(
                'Connect your existing Nostr identity',
                style: TextStyle(
                  color: const Color(0xFF9CA3AF),
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 20 / 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Row(
      children: [
        Expanded(
          child: _buildTabButton(
            'Paste Keys',
            ImportMethod.pasteKeys,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildTabButton(
            'Scan QR',
            ImportMethod.scanQr,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildTabButton(
            'Connect',
            ImportMethod.connect,
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, ImportMethod method) {
    final isActive = selectedMethod == method;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMethod = method;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive ? const Color(0xFFF7931A) : const Color(0xFF1A2942),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFF9CA3AF),
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 24 / 14,
            ),
          ),
        ),
      ).animate(target: isActive ? 1 : 0).scaleXY(
        begin: 0.98,
        end: 1.0,
        duration: 200.ms,
      ),
    );
  }

  Widget _buildContent() {
    switch (selectedMethod) {
      case ImportMethod.scanQr:
        return _buildScanQrContent();
      case ImportMethod.pasteKeys:
        return _buildPasteKeysContent();
      case ImportMethod.connect:
        return _buildConnectContent();
    }
  }

  Widget _buildScanQrContent() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF111128),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.15),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(66),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF374151),
                width: 1,
                style: BorderStyle.solid,
              ),
              color: const Color(0xFF0C0C1A),
            ),
            child: CustomPaint(
              size: const Size(60, 60),
              painter: QrCodeIconPainter(),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(
            duration: 2000.ms,
            color: const Color(0xFF4B5563).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Scan QR code from your Nostr client',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF9CA3AF),
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 20 / 12,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildPasteKeysContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF111128),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.15),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Public Key (npub)',
            style: TextStyle(
              color: const Color(0xFF9CA3AF),
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 20 / 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 47,
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF374151)),
              color: const Color(0xFF0C0C1A),
            ),
            child: TextField(
              controller: publicKeyController,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'npub1...',
                hintStyle: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Private Key (nsec) - Optional',
            style: TextStyle(
              color: const Color(0xFF9CA3AF),
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 20 / 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 47,
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF374151)),
              color: const Color(0xFF0C0C1A),
            ),
            child: TextField(
              controller: privateKeyController,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'nsec1...',
                hintStyle: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Only needed for full wallet control',
            style: TextStyle(
              color: const Color(0xFF6B7280),
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w400,
              height: 16 / 10,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildConnectContent() {
    return Column(
      children: [
        _buildWalletOption(
          emoji: '⚡',
          emojiColor: const Color(0xFFEAB308),
          title: 'Alby',
          subtitle: 'Connect via Nostr Wallet Connect',
          walletId: 'alby',
        ),
        const SizedBox(height: 12),
        _buildWalletOption(
          emoji: '💎',
          emojiColor: const Color(0xFFA855F7),
          title: 'Amethyst',
          subtitle: 'Import from Amethyst app',
          walletId: 'amethyst',
        ),
        const SizedBox(height: 12),
        _buildWalletOption(
          emoji: '🔷',
          emojiColor: const Color(0xFF3B82F6),
          title: 'Primal',
          subtitle: 'Connect via Primal wallet',
          walletId: 'primal',
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildWalletOption({
    required String emoji,
    required Color emojiColor,
    required String title,
    required String subtitle,
    required String walletId,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedWallet = walletId;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF111128),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.15),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9999),
                color: emojiColor,
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(
                    fontSize: 20,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 24 / 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFF9CA3AF),
                      fontFamily: 'Inter',
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
      ),
    );
  }

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF7931A)),
        color: const Color(0xFF111128).withValues(alpha: 0.05),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.15),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomPaint(
            size: const Size(20, 20),
            painter: InfoIconPainter(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We will still ask you to set up backup (social recovery or seed phrase) even if you get Nostr keys. Phone can loss anytime.',
                  style: TextStyle(
                    color: const Color(0xFFD1D5DB),
                    fontFamily: 'Inter',
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

  Widget _buildBottomButton() {
    final isImporting = currentState == ImportState.importing;
    final canImport = _canImport();

    return GestureDetector(
      onTap: canImport && !isImporting ? handleImport : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: canImport
              ? const Color(0xFFF7931A)
              : const Color(0xFF814F1A),
        ),
        child: Center(
          child: isImporting
              ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '⚡',
                style: TextStyle(fontSize: 20),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shake(duration: 1000.ms),
              const SizedBox(width: 8),
              const Text(
                'Importing...',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 28 / 15,
                ),
              ),
            ],
          )
              : const Text(
            'Import & Continue',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 24 / 14,
            ),
          ),
        ),
      ),
    );
  }

  bool _canImport() {
    switch (selectedMethod) {
      case ImportMethod.pasteKeys:
        return publicKeyController.text.isNotEmpty;
      case ImportMethod.scanQr:
        return true;
      case ImportMethod.connect:
        return selectedWallet != null;
    }
  }

  Widget _buildConnectedState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 31, vertical: 29),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 28),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(33),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF00FFB2)),
                      color: const Color(0xFF111128),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.15),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9999),
                            color: const Color(0xFF00FFB2)
                                .withValues(alpha: 0.2),
                          ),
                          child: Center(
                            child: CustomPaint(
                              size: const Size(40, 40),
                              painter: CheckIconPainter(),
                            ),
                          ),
                        )
                            .animate()
                            .scale(
                          duration: 600.ms,
                          curve: Curves.elasticOut,
                        )
                            .fadeIn(duration: 400.ms),
                        const SizedBox(height: 13),
                        const Text(
                          'We see you are Nostr OG!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 32 / 20,
                          ),
                        ).animate().fadeIn(
                          delay: 200.ms,
                          duration: 400.ms,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Wallet is ready. We will now help you set up backup.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 24 / 14,
                          ),
                        ).animate().fadeIn(
                          delay: 300.ms,
                          duration: 400.ms,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFF0C0C1A),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Nostr Profile',
                                style: TextStyle(
                                  color: const Color(0xFF9CA3AF),
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 20 / 12,
                                ),
                              ),
                              const Text(
                                'Connected ✓',
                                style: TextStyle(
                                  color: Color(0xFF00FFB2),
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 24 / 14,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(
                          delay: 400.ms,
                          duration: 400.ms,
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
    );
  }
}

class BackArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.2);
    path.lineTo(size.width * 0.2, size.height * 0.5);
    path.lineTo(size.width * 0.5, size.height * 0.8);

    canvas.drawPath(path, paint);

    canvas.drawLine(
      Offset(size.width * 0.8, size.height * 0.5),
      Offset(size.width * 0.2, size.height * 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class QrCodeIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4B5563)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final squareSize = size.width * 0.2;
    final gap = size.width * 0.05;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(gap, gap, squareSize, squareSize),
        const Radius.circular(2),
      ),
      paint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width - gap - squareSize,
          gap,
          squareSize,
          squareSize,
        ),
        const Radius.circular(2),
      ),
      paint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          gap,
          size.height - gap - squareSize,
          squareSize,
          squareSize,
        ),
        const Radius.circular(2),
      ),
      paint,
    );

    canvas.drawLine(
      Offset(size.width * 0.5, gap),
      Offset(size.width * 0.5, gap + squareSize * 0.5),
      paint,
    );

    canvas.drawLine(
      Offset(gap, size.height * 0.5),
      Offset(gap + squareSize * 0.5, size.height * 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class InfoIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF7931A)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );

    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.33),
      Offset(size.width / 2, size.height * 0.5),
      paint,
    );

    final dotPaint = Paint()
      ..color = const Color(0xFFF7931A)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.67),
      1.5,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CheckIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FFB2)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final arcPath = Path();
    arcPath.addArc(
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2,
      ),
      -1.5708,
      5.5,
    );
    canvas.drawPath(arcPath, paint);

    final checkPath = Path();
    checkPath.moveTo(size.width * 0.375, size.width * 0.458);
    checkPath.lineTo(size.width * 0.5, size.width * 0.583);
    checkPath.lineTo(size.width * 0.917, size.width * 0.167);

    canvas.drawPath(checkPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
