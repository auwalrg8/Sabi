import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isProcessing = false;
  bool _torchEnabled = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null && code.isNotEmpty) {
        setState(() => _isProcessing = true);

        // Return the scanned code
        Navigator.pop(context, code);
        break;
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await controller.toggleTorch();
      setState(() => _torchEnabled = !_torchEnabled);
    } catch (e) {
      debugPrint('Torch error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera view
          MobileScanner(controller: controller, onDetect: _handleBarcode),

          // Overlay
          CustomPaint(painter: ScannerOverlayPainter(), child: Container()),

          // Top bar
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28.sp,
                        ),
                      ),
                      IconButton(
                        onPressed: _toggleTorch,
                        icon: Icon(
                          _torchEnabled ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 28.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40.h),
                Text(
                  'Scan QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.h),
                  child: Text(
                    'Align the QR code within the frame to scan',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaSize = size.width * 0.7;
    final double left = (size.width - scanAreaSize) / 2.w;
    final double top = (size.height - scanAreaSize) / 2.h;
    final Rect scanArea = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    // Draw semi-transparent overlay
    final Paint backgroundPaint =
        Paint()..color = Colors.black.withValues(alpha: 0.5);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromRectAndRadius(scanArea, Radius.circular(16.r))),
      ),
      backgroundPaint,
    );

    // Draw corner brackets
    final Paint cornerPaint =
        Paint()
          ..color = AppColors.primary
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke;

    final double cornerLength = 30.h;
    final double cornerRadius = 16.r;

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(left + cornerRadius, top)
        ..lineTo(left + cornerLength, top)
        ..moveTo(left, top + cornerRadius)
        ..lineTo(left, top + cornerLength),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(left + scanAreaSize - cornerLength, top)
        ..lineTo(left + scanAreaSize - cornerRadius, top)
        ..moveTo(left + scanAreaSize, top + cornerRadius)
        ..lineTo(left + scanAreaSize, top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(left, top + scanAreaSize - cornerLength)
        ..lineTo(left, top + scanAreaSize - cornerRadius)
        ..moveTo(left + cornerRadius, top + scanAreaSize)
        ..lineTo(left + cornerLength, top + scanAreaSize),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(left + scanAreaSize, top + scanAreaSize - cornerLength)
        ..lineTo(left + scanAreaSize, top + scanAreaSize - cornerRadius)
        ..moveTo(left + scanAreaSize - cornerLength, top + scanAreaSize)
        ..lineTo(left + scanAreaSize - cornerRadius, top + scanAreaSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
