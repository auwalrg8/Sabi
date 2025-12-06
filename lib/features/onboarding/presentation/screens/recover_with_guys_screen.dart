import 'package:flutter/material.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'wallet_success_screen.dart';
import 'dart:math' as math;

enum RecoveryState {
  input,
  searching,
  requestingShares,
  restored,
}

class RecoverWithGuysScreen extends StatefulWidget {
  const RecoverWithGuysScreen({super.key});

  @override
  State<RecoverWithGuysScreen> createState() => _RecoverWithGuysScreenState();
}

class _RecoverWithGuysScreenState extends State<RecoverWithGuysScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  RecoveryState _state = RecoveryState.input;
  int _sharesReceived = 0;
  late AnimationController _spinController;
  late AnimationController _progressController;

  final List<RecoveryContact> _contacts = [
    RecoveryContact(name: 'Chidi Okafor', initial: 'C', shareReceived: false),
    RecoveryContact(
      name: 'Blessing Adeyemi',
      initial: 'B',
      shareReceived: false,
    ),
    RecoveryContact(name: 'Tunde Bakare', initial: 'T', shareReceived: false),
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _spinController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _startRecovery() {
    setState(() => _state = RecoveryState.searching);

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _state = RecoveryState.requestingShares);
      _simulateShareReceiving();
    });
  }

  void _simulateShareReceiving() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _contacts[0].shareReceived = true;
        _sharesReceived = 1;
        _progressController.animateTo(0.33);
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          _contacts[1].shareReceived = true;
          _sharesReceived = 2;
          _progressController.animateTo(0.66);
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() {
            _contacts[2].shareReceived = true;
            _sharesReceived = 3;
            _progressController.animateTo(1.0);
          });

          Future.delayed(const Duration(seconds: 1), () {
            if (!mounted) return;
            setState(() => _state = RecoveryState.restored);
          });
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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
                child: _buildContent(),
              ),
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
                'Recover Your Wallet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.78,
                ),
              ),
              const Text(
                'Your guys go help you get am back',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.67,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case RecoveryState.input:
        return _buildInputState();
      case RecoveryState.searching:
        return _buildSearchingState();
      case RecoveryState.requestingShares:
        return _buildRequestingSharesState();
      case RecoveryState.restored:
        return _buildRestoredState();
    }
  }

  Widget _buildInputState() {
    final bool hasInput = _controller.text.isNotEmpty;
    final bool isEnabled = hasInput || _controller.text == '@sabi/auwal';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.accentGreen.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: CustomPaint(
                              size: const Size(24, 24),
                              painter: UsersIconPainter(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Social Recovery',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    height: 1.71,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Enter your old phone number or @sabi  handle',
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    height: 1.67,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 17),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF374151),
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 1.75,
                          ),
                          decoration: const InputDecoration(
                            hintText: '+234 803 456 7890 or @sabi/yourname',
                            hintStyle: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(21),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.accentGreen,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'We go look up your Nostr profile, find your 3 ',
                        style: TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.83,
                        ),
                      ),
                      Text(
                        'recovery contacts, and send them automatic ',
                        style: TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.83,
                        ),
                      ),
                      Text(
                        'message to help you recover.',
                        style: TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.83,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          height: 60,
          margin: const EdgeInsets.only(top: 16),
          child: ElevatedButton(
            onPressed: isEnabled ? _startRecovery : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isEnabled
                  ? AppColors.primary
                  : const Color(0xFF814F1A),
              foregroundColor: Colors.white,
              elevation: 0,
              disabledBackgroundColor: const Color(0xFF814F1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Start Recovery',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.71,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 26,
              ),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _spinController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _spinController.value * 2 * math.pi,
                        child: CustomPaint(
                          size: const Size(71, 71),
                          painter: LoadingIconPainter(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Looking Up Your Profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Searching Nostr network for your \nrecovery contacts...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.71,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          height: 60,
          margin: const EdgeInsets.only(top: 16),
          child: ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF814F1A),
              disabledBackgroundColor: const Color(0xFF814F1A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Start Recovery',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.71,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestingSharesState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: CustomPaint(
                      size: const Size(24, 24),
                      painter: UsersIconPainter(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Requesting Shares',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.71,
                          ),
                        ),
                        Text(
                          '$_sharesReceived/3 shares received',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.67,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  return Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progressController.value,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Expanded(
          child: ListView.separated(
            itemCount: _contacts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 17),
            itemBuilder: (context, index) {
              final contact = _contacts[index];
              return _buildContactCard(contact);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard(RecoveryContact contact) {
    return Container(
      padding: EdgeInsets.all(contact.shareReceived ? 17 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: contact.shareReceived
            ? Border.all(color: AppColors.accentGreen)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF7931A), Color(0xFFEA580C)],
                stops: [0.25, 0.96],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                contact.initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.87,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.71,
                  ),
                ),
                Text(
                  contact.shareReceived
                      ? 'Share received ✓'
                      : 'Waiting for approval...',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.67,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (contact.shareReceived)
            CustomPaint(
              size: const Size(20, 20),
              painter: CheckIconPainter(),
            )
          else
            AnimatedBuilder(
              animation: _spinController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _spinController.value * 2 * math.pi,
                  child: CustomPaint(
                    size: const Size(26, 26),
                    painter: SmallLoadingIconPainter(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRestoredState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(33),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accentGreen),
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
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(40, 40),
                        painter: LargeCheckIconPainter(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Wallet Restored!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your wallet has been successfully \nrecovered. All your funds are safe and \naccessible.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.71,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recovery Time',
                              style: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                height: 1.67,
                              ),
                            ),
                            Text(
                              '~8 seconds',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.71,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Shares Combined',
                              style: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                height: 1.67,
                              ),
                            ),
                            Text(
                              '3/3',
                              style: TextStyle(
                                color: Color(0xFF00FFB2),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.71,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          height: 50,
          margin: const EdgeInsets.only(top: 16),
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const WalletSuccessScreen(),
                ),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Continue to Wallet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.71,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class RecoveryContact {
  final String name;
  final String initial;
  bool shareReceived;

  RecoveryContact({
    required this.name,
    required this.initial,
    this.shareReceived = false,
  });
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
    path.moveTo(size.width * 0.5, size.height * 0.21);
    path.lineTo(size.width * 0.21, size.height * 0.5);
    path.lineTo(size.width * 0.5, size.height * 0.79);

    canvas.drawPath(path, paint);

    final linePath = Path();
    linePath.moveTo(size.width * 0.79, size.height * 0.5);
    linePath.lineTo(size.width * 0.21, size.height * 0.5);

    canvas.drawPath(linePath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class UsersIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentGreen
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path1 = Path();
    path1.moveTo(size.width * 0.67, size.height * 0.88);
    path1.lineTo(size.width * 0.67, size.height * 0.79);
    path1.cubicTo(
      size.width * 0.67,
      size.height * 0.75,
      size.width * 0.65,
      size.height * 0.71,
      size.width * 0.62,
      size.height * 0.68,
    );
    path1.cubicTo(
      size.width * 0.59,
      size.height * 0.65,
      size.width * 0.54,
      size.height * 0.63,
      size.width * 0.5,
      size.height * 0.63,
    );
    path1.lineTo(size.width * 0.25, size.height * 0.63);
    path1.cubicTo(
      size.width * 0.21,
      size.height * 0.63,
      size.width * 0.16,
      size.height * 0.65,
      size.width * 0.13,
      size.height * 0.68,
    );
    path1.cubicTo(
      size.width * 0.10,
      size.height * 0.71,
      size.width * 0.08,
      size.height * 0.75,
      size.width * 0.08,
      size.height * 0.79,
    );
    path1.lineTo(size.width * 0.08, size.height * 0.88);

    canvas.drawPath(path1, paint);

    final circlePath = Path();
    circlePath.addOval(
      Rect.fromCircle(
        center: Offset(size.width * 0.375, size.height * 0.29),
        radius: size.width * 0.17,
      ),
    );
    canvas.drawPath(circlePath, paint);

    final path2 = Path();
    path2.moveTo(size.width * 0.67, size.height * 0.13);
    path2.cubicTo(
      size.width * 0.71,
      size.height * 0.14,
      size.width * 0.76,
      size.height * 0.16,
      size.width * 0.80,
      size.height * 0.19,
    );
    path2.cubicTo(
      size.width * 0.84,
      size.height * 0.22,
      size.width * 0.87,
      size.height * 0.25,
      size.width * 0.87,
      size.height * 0.29,
    );
    path2.cubicTo(
      size.width * 0.87,
      size.height * 0.33,
      size.width * 0.84,
      size.height * 0.36,
      size.width * 0.80,
      size.height * 0.39,
    );
    path2.cubicTo(
      size.width * 0.76,
      size.height * 0.42,
      size.width * 0.71,
      size.height * 0.44,
      size.width * 0.67,
      size.height * 0.45,
    );

    canvas.drawPath(path2, paint);

    final path3 = Path();
    path3.moveTo(size.width * 0.92, size.height * 0.88);
    path3.lineTo(size.width * 0.92, size.height * 0.79);
    path3.cubicTo(
      size.width * 0.92,
      size.height * 0.76,
      size.width * 0.89,
      size.height * 0.73,
      size.width * 0.84,
      size.height * 0.69,
    );
    path3.cubicTo(
      size.width * 0.79,
      size.height * 0.66,
      size.width * 0.73,
      size.height * 0.65,
      size.width * 0.67,
      size.height * 0.63,
    );

    canvas.drawPath(path3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoadingIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentGreen
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final lines = [
      [Offset(size.width * 0.5, size.height * 0.08), Offset(size.width * 0.5, size.height * 0.25)],
      [Offset(size.width * 0.68, size.height * 0.33), Offset(size.width * 0.80, size.height * 0.20)],
      [Offset(size.width * 0.75, size.height * 0.5), Offset(size.width * 0.92, size.height * 0.5)],
      [Offset(size.width * 0.68, size.height * 0.68), Offset(size.width * 0.80, size.height * 0.80)],
      [Offset(size.width * 0.5, size.height * 0.75), Offset(size.width * 0.5, size.height * 0.92)],
      [Offset(size.width * 0.20, size.height * 0.80), Offset(size.width * 0.33, size.height * 0.68)],
      [Offset(size.width * 0.08, size.height * 0.5), Offset(size.width * 0.25, size.height * 0.5)],
      [Offset(size.width * 0.20, size.height * 0.20), Offset(size.width * 0.33, size.height * 0.33)],
    ];

    for (var line in lines) {
      canvas.drawLine(line[0], line[1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SmallLoadingIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentGreen
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final lines = [
      [Offset(size.width * 0.5, size.height * 0.08), Offset(size.width * 0.5, size.height * 0.25)],
      [Offset(size.width * 0.68, size.height * 0.33), Offset(size.width * 0.80, size.height * 0.20)],
      [Offset(size.width * 0.75, size.height * 0.5), Offset(size.width * 0.92, size.height * 0.5)],
      [Offset(size.width * 0.68, size.height * 0.68), Offset(size.width * 0.80, size.height * 0.80)],
      [Offset(size.width * 0.5, size.height * 0.75), Offset(size.width * 0.5, size.height * 0.92)],
      [Offset(size.width * 0.20, size.height * 0.80), Offset(size.width * 0.33, size.height * 0.68)],
      [Offset(size.width * 0.08, size.height * 0.5), Offset(size.width * 0.25, size.height * 0.5)],
      [Offset(size.width * 0.20, size.height * 0.20), Offset(size.width * 0.33, size.height * 0.33)],
    ];

    for (var line in lines) {
      canvas.drawLine(line[0], line[1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CheckIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentGreen
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final circlePath = Path();
    circlePath.moveTo(size.width * 0.91, size.height * 0.42);
    circlePath.cubicTo(
      size.width * 0.93,
      size.height * 0.51,
      size.width * 0.91,
      size.height * 0.61,
      size.width * 0.87,
      size.height * 0.69,
    );
    circlePath.cubicTo(
      size.width * 0.83,
      size.height * 0.76,
      size.width * 0.76,
      size.height * 0.82,
      size.width * 0.67,
      size.height * 0.85,
    );
    circlePath.cubicTo(
      size.width * 0.58,
      size.height * 0.88,
      size.width * 0.48,
      size.height * 0.88,
      size.width * 0.39,
      size.height * 0.85,
    );
    circlePath.cubicTo(
      size.width * 0.30,
      size.height * 0.82,
      size.width * 0.22,
      size.height * 0.76,
      size.width * 0.16,
      size.height * 0.67,
    );
    circlePath.cubicTo(
      size.width * 0.10,
      size.height * 0.58,
      size.width * 0.06,
      size.height * 0.48,
      size.width * 0.06,
      size.height * 0.38,
    );
    circlePath.cubicTo(
      size.width * 0.06,
      size.height * 0.29,
      size.width * 0.10,
      size.height * 0.19,
      size.width * 0.16,
      size.height * 0.12,
    );
    circlePath.cubicTo(
      size.width * 0.22,
      size.height * 0.05,
      size.width * 0.30,
      size.height * 0.00,
      size.width * 0.39,
      size.height * -0.02,
    );
    circlePath.cubicTo(
      size.width * 0.48,
      size.height * -0.04,
      size.width * 0.58,
      size.height * -0.02,
      size.width * 0.67,
      size.height * 0.03,
    );

    canvas.drawPath(circlePath, paint);

    final checkPath = Path();
    checkPath.moveTo(size.width * 0.375, size.height * 0.46);
    checkPath.lineTo(size.width * 0.5, size.height * 0.58);
    checkPath.lineTo(size.width * 0.92, size.height * 0.17);

    canvas.drawPath(checkPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LargeCheckIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentGreen
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final circlePath = Path();
    circlePath.moveTo(size.width * 0.91, size.height * .42);
    circlePath.cubicTo(
      size.width * 0.93,
      size.height * 0.51,
      size.width * 0.91,
      size.height * 0.61,
      size.width * 0.87,
      size.height * 0.69,
    );
    circlePath.cubicTo(
      size.width * 0.83,
      size.height * 0.76,
      size.width * 0.76,
      size.height * 0.82,
      size.width * 0.67,
      size.height * 0.85,
    );
    circlePath.cubicTo(
      size.width * 0.58,
      size.height * 0.88,
      size.width * 0.48,
      size.height * 0.88,
      size.width * 0.39,
      size.height * 0.85,
    );
    circlePath.cubicTo(
      size.width * 0.30,
      size.height * 0.82,
      size.width * 0.22,
      size.height * 0.76,
      size.width * 0.16,
      size.height * 0.67,
    );
    circlePath.cubicTo(
      size.width * 0.10,
      size.height * 0.58,
      size.width * 0.06,
      size.height * 0.48,
      size.width * 0.06,
      size.height * 0.38,
    );
    circlePath.cubicTo(
      size.width * 0.06,
      size.height * 0.29,
      size.width * 0.10,
      size.height * 0.19,
      size.width * 0.16,
      size.height * 0.12,
    );
    circlePath.cubicTo(
      size.width * 0.22,
      size.height * 0.05,
      size.width * 0.30,
      size.height * 0.00,
      size.width * 0.39,
      size.height * -0.02,
    );
    circlePath.cubicTo(
      size.width * 0.48,
      size.height * -0.04,
      size.width * 0.58,
      size.height * -0.02,
      size.width * 0.67,
      size.height * 0.03,
    );

    canvas.drawPath(circlePath, paint);

    final checkPath = Path();
    checkPath.moveTo(size.width * 0.375, size.height * 0.46);
    checkPath.lineTo(size.width * 0.5, size.height * 0.58);
    checkPath.lineTo(size.width * 0.92, size.height * 0.17);

    canvas.drawPath(checkPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
