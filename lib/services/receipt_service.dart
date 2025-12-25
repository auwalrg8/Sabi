import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Receipt data model for generating receipts
class ReceiptData {
  final String type; // 'send' or 'receive'
  final String recipientName;
  final String recipientIdentifier;
  final int amountSats;
  final double? amountNgn;
  final int? feeSats;
  final String? memo;
  final DateTime timestamp;
  final String? transactionId;

  ReceiptData({
    required this.type,
    required this.recipientName,
    required this.recipientIdentifier,
    required this.amountSats,
    this.amountNgn,
    this.feeSats,
    this.memo,
    required this.timestamp,
    this.transactionId,
  });
}

class ReceiptService {
  /// Generate and share receipt as image
  static Future<void> shareAsImage(
    GlobalKey receiptKey, {
    String? subject,
  }) async {
    try {
      final boundary = receiptKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('❌ Could not find render boundary');
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('❌ Could not convert image to bytes');
        return;
      }

      final bytes = byteData.buffer.asUint8List();
      
      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/sabi_receipt_$timestamp.png');
      await file.writeAsBytes(bytes);

      // Share
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subject ?? 'Sabi Wallet Receipt',
      );

      debugPrint('✅ Receipt image shared successfully');
    } catch (e) {
      debugPrint('❌ Error sharing receipt as image: $e');
    }
  }

  /// Generate and share receipt as PDF
  static Future<void> shareAsPdf(ReceiptData data, {String? subject}) async {
    try {
      final pdf = pw.Document();

      final formattedDate = 
          '${data.timestamp.day}/${data.timestamp.month}/${data.timestamp.year}';
      final formattedTime = 
          '${data.timestamp.hour.toString().padLeft(2, '0')}:${data.timestamp.minute.toString().padLeft(2, '0')}';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'SABI WALLET',
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#F7931A'),
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'PAYMENT RECEIPT',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Container(
                          width: 100,
                          height: 2,
                          color: PdfColor.fromHex('#F7931A'),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  
                  // Status
                  pw.Center(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#22C55E'),
                        borderRadius: pw.BorderRadius.circular(20),
                      ),
                      child: pw.Text(
                        data.type == 'send' ? '✓ PAYMENT SENT' : '✓ PAYMENT RECEIVED',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 30),

                  // Amount
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          '${_formatNumber(data.amountSats)} sats',
                          style: pw.TextStyle(
                            fontSize: 32,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (data.amountNgn != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '≈ ₦${_formatNumber(data.amountNgn!.toInt())}',
                            style: pw.TextStyle(
                              fontSize: 16,
                              color: PdfColor.fromHex('#F7931A'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 40),

                  // Details
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Column(
                      children: [
                        _buildPdfRow('Recipient', data.recipientName),
                        pw.SizedBox(height: 12),
                        _buildPdfRow('Identifier', data.recipientIdentifier),
                        pw.SizedBox(height: 12),
                        _buildPdfRow('Date', formattedDate),
                        pw.SizedBox(height: 12),
                        _buildPdfRow('Time', formattedTime),
                        if (data.feeSats != null && data.feeSats! > 0) ...[
                          pw.SizedBox(height: 12),
                          _buildPdfRow('Network Fee', '${data.feeSats} sats'),
                        ],
                        if (data.memo != null && data.memo!.isNotEmpty) ...[
                          pw.SizedBox(height: 12),
                          _buildPdfRow('Note', data.memo!),
                        ],
                        if (data.transactionId != null) ...[
                          pw.SizedBox(height: 12),
                          _buildPdfRow(
                            'Transaction ID',
                            _truncateString(data.transactionId!, 30),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.Spacer(),

                  // Footer
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Generated by Sabi Wallet',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'www.sabiwallet.com',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColor.fromHex('#F7931A'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/sabi_receipt_$timestamp.pdf');
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);

      // Share
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subject ?? 'Sabi Wallet Receipt',
      );

      debugPrint('✅ Receipt PDF shared successfully');
    } catch (e) {
      debugPrint('❌ Error sharing receipt as PDF: $e');
    }
  }

  static pw.Widget _buildPdfRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: PdfColors.grey600,
            fontSize: 12,
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  static String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  static String _truncateString(String str, int maxLength) {
    if (str.length <= maxLength) return str;
    return '${str.substring(0, maxLength)}...';
  }
}
