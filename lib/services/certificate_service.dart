import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/wipe_result.dart';
import '../models/certificate.dart';

class CertificateService {
  final _uuid = const Uuid();
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

  /// Generate a certificate for deleted files
  Future<WipeCertificate> generateCertificate(
    List<WipeResult> wipeResults,
    String wipeMethodName,
  ) async {
    final certificateId = 'SWC-${_uuid.v4().toUpperCase().substring(0, 8)}';
    final issuedAt = DateTime.now();

    // Create summaries of wiped files
    final wipedFiles = wipeResults
        .where((r) => r.success)
        .map(
          (r) => WipeResultSummary(
            fileName: r.fileName,
            fileSize: r.fileSize,
            wipedAt: r.endTime,
          ),
        )
        .toList();

    // Get device info
    final deviceInfo = await _getDeviceInfo();

    // Generate digital signature
    final dataToSign = jsonEncode({
      'certificateId': certificateId,
      'files': wipedFiles.map((f) => f.toJson()).toList(),
      'issuedAt': issuedAt.toIso8601String(),
      'method': wipeMethodName,
    });
    final digitalSignature = sha256.convert(utf8.encode(dataToSign)).toString();

    return WipeCertificate(
      certificateId: certificateId,
      wipedFiles: wipedFiles,
      wipeMethod: wipeMethodName,
      issuedAt: issuedAt,
      deviceInfo: deviceInfo,
      digitalSignature: digitalSignature,
    );
  }

  /// Save certificate as JSON
  Future<String> saveAsJson(WipeCertificate certificate) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath =
        '${directory.path}/certificate_${certificate.certificateId}.json';

    final file = File(filePath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(certificate.toJson()),
    );

    return filePath;
  }

  /// Generate PDF certificate
  Future<String> saveAsPdf(WipeCertificate certificate) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.green, width: 2),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Text(
                        'SECURE DATA WIPE CERTIFICATE',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Certificate of Data Destruction',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 20),

              // Certificate Info
              _buildPdfInfoRow('Certificate ID:', certificate.certificateId),
              _buildPdfInfoRow(
                'Issue Date:',
                _dateFormat.format(certificate.issuedAt),
              ),
              _buildPdfInfoRow('Wipe Method:', certificate.wipeMethod),
              _buildPdfInfoRow('Device:', certificate.deviceInfo),
              _buildPdfInfoRow(
                'Total Files Destroyed:',
                '${certificate.totalFiles}',
              ),
              _buildPdfInfoRow(
                'Total Data Destroyed:',
                _formatBytes(certificate.totalSize),
              ),

              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 15),

              // Files Section
              pw.Text(
                'FILES SECURELY DESTROYED:',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              // File table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      _tableCell('File Name', isHeader: true),
                      _tableCell('Size', isHeader: true),
                      _tableCell('Wiped At', isHeader: true),
                    ],
                  ),
                  // Data rows
                  ...certificate.wipedFiles.map(
                    (file) => pw.TableRow(
                      children: [
                        _tableCell(file.fileName),
                        _tableCell(_formatBytes(file.fileSize)),
                        _tableCell(_dateFormat.format(file.wipedAt)),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Digital Signature Section
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 10),
              pw.Text(
                'DIGITAL SIGNATURE (SHA-256):',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  certificate.digitalSignature,
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ),

              pw.SizedBox(height: 15),

              // Footer
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'This certificate confirms that the listed files have been',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'securely wiped using industry-standard methods and are unrecoverable.',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Generated by Secure Data Wipe App',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save PDF
    final directory = await getApplicationDocumentsDirectory();
    final filePath =
        '${directory.path}/certificate_${certificate.certificateId}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }

  pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  pw.Widget _tableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  Future<String> _getDeviceInfo() async {
    // In production, use device_info_plus package
    return 'Android Device';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
