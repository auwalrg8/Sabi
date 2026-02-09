import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/hodl_hodl/hodl_hodl.dart';

/// Trade Success Screen
/// Shows confetti celebration, receipt details, and strong haptics
class TradeSuccessScreen extends StatefulWidget {
  final HodlHodlContract contract;

  const TradeSuccessScreen({
    Key? key,
    required this.contract,
  }) : super(key: key);

  @override
  State<TradeSuccessScreen> createState() => _TradeSuccessScreenState();
}

class _TradeSuccessScreenState extends State<TradeSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final List<ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    
    // Strong haptic feedback
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () => HapticFeedback.heavyImpact());
    Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.heavyImpact());
    
    // Initialize confetti
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    // Generate particles
    _generateParticles();
    
    // Start animations
    _confettiController.forward();
    _scaleController.forward();
    _fadeController.forward();
    
    // Repeat confetti
    _confettiController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _particles.clear();
        _generateParticles();
        _confettiController.reset();
        _confettiController.forward();
      }
    });
  }

  void _generateParticles() {
    final colors = [
      AppColors.accentGreen,
      AppColors.primary,
      const Color(0xFF9333EA),
      Colors.white,
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
    ];
    
    for (int i = 0; i < 100; i++) {
      _particles.add(ConfettiParticle(
        x: _random.nextDouble() * 400 - 50,
        y: -_random.nextDouble() * 200 - 50,
        vx: _random.nextDouble() * 4 - 2,
        vy: _random.nextDouble() * 4 + 2,
        rotation: _random.nextDouble() * 360,
        rotationSpeed: _random.nextDouble() * 10 - 5,
        color: colors[_random.nextInt(colors.length)],
        size: _random.nextDouble() * 10 + 5,
        shape: _random.nextInt(3),
      ));
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Confetti layer
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, _) {
              return CustomPaint(
                painter: ConfettiPainter(
                  particles: _particles,
                  progress: _confettiController.value,
                  screenHeight: MediaQuery.of(context).size.height,
                ),
                size: Size.infinite,
              );
            },
          ),
          
          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  SizedBox(height: 60.h),
                  
                  // Success icon
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 120.w,
                      height: 120.h,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accentGreen.withOpacity(0.3),
                            AppColors.accentGreen.withOpacity(0.0),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 80.w,
                          height: 80.h,
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.accentGreen,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.check,
                            color: AppColors.accentGreen,
                            size: 48.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 32.h),
                  
                  // Title
                  Text(
                    'Trade Complete! 🎉',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  
                  SizedBox(height: 12.h),
                  
                  Text(
                    'Your P2P trade was successful',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16.sp,
                    ),
                  ),
                  
                  SizedBox(height: 48.h),
                  
                  // Receipt card
                  _buildReceiptCard(),
                  
                  const Spacer(),
                  
                  // Action buttons
                  Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56.h,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                            child: Text(
                              'Done',
                              style: TextStyle(
                                color: AppColors.background,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        TextButton(
                          onPressed: () {
                            // Share receipt
                            HapticFeedback.lightImpact();
                            _shareReceipt();
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.share, color: Colors.white54, size: 18.sp),
                              SizedBox(width: 8.w),
                              Text(
                                'Share Receipt',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard() {
    final contract = widget.contract;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          // BTC amount
          Text(
            '${contract.volume} BTC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '${_getCurrencySymbol(contract.currencyCode)} ${contract.value}',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18.sp,
            ),
          ),
          
          SizedBox(height: 24.h),
          Divider(color: Colors.white.withOpacity(0.1)),
          SizedBox(height: 16.h),
          
          // Receipt details
          _buildReceiptRow('Contract ID', contract.id),
          _buildReceiptRow(
            'Type',
            contract.yourRole == 'buyer' ? 'Buy Bitcoin' : 'Sell Bitcoin',
          ),
          _buildReceiptRow('Counterparty', '@${contract.counterparty.login}'),
          _buildReceiptRow(
            'Price',
            '${_getCurrencySymbol(contract.currencyCode)} ${contract.price}',
          ),
          _buildReceiptRow('Status', 'Completed ✓'),
          _buildReceiptRow('Date', _formatDate(DateTime.now())),
          
          SizedBox(height: 16.h),
          
          // Escrow badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.security, color: AppColors.accentGreen, size: 16.sp),
                SizedBox(width: 8.w),
                Text(
                  'Secured by Hodl Hodl Escrow',
                  style: TextStyle(
                    color: AppColors.accentGreen,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13.sp,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrencySymbol(String code) {
    switch (code) {
      case 'NGN':
        return '₦';
      case 'USD':
        return '\$';
      default:
        return code;
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _shareReceipt() {
    final contract = widget.contract;
    final text = '''
🎉 P2P Trade Complete!

Amount: ${contract.volume} BTC
Value: ${_getCurrencySymbol(contract.currencyCode)} ${contract.value}
Counterparty: @${contract.counterparty.login}
Contract: ${contract.id}

Powered by Hodl Hodl 🔒
''';
    
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Receipt copied to clipboard'),
        backgroundColor: AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }
}

/// Confetti particle data
class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double rotation;
  double rotationSpeed;
  Color color;
  double size;
  int shape; // 0 = circle, 1 = square, 2 = triangle

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.size,
    required this.shape,
  });
}

/// Custom painter for confetti
class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;
  final double screenHeight;

  ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.screenHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      // Update position based on progress
      final newY = particle.y + (screenHeight * 1.5 * progress) + particle.vy * progress * 100;
      final newX = particle.x + particle.vx * progress * 50 + size.width / 2;
      final newRotation = particle.rotation + particle.rotationSpeed * progress * 360;
      
      // Fade out at bottom
      final opacity = (1 - (newY / screenHeight).clamp(0.0, 1.0)).clamp(0.0, 1.0);
      
      if (opacity <= 0) continue;
      
      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;
      
      canvas.save();
      canvas.translate(newX, newY);
      canvas.rotate(newRotation * pi / 180);
      
      switch (particle.shape) {
        case 0: // Circle
          canvas.drawCircle(Offset.zero, particle.size / 2, paint);
          break;
        case 1: // Square
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: particle.size, height: particle.size),
            paint,
          );
          break;
        case 2: // Triangle
          final path = Path()
            ..moveTo(0, -particle.size / 2)
            ..lineTo(particle.size / 2, particle.size / 2)
            ..lineTo(-particle.size / 2, particle.size / 2)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
