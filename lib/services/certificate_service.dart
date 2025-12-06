import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/wipe_result.dart';
import '../models/wiped_file.dart';
import '../models/certificate.dart';
import '../models/certificate_record.dart';
import 'certificate_storage_service.dart';

class CertificateService {
  final _uuid = const Uuid();
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
  final _certificateStorageService = CertificateStorageService();

  /// Generate a certificate for deleted files (immediate deletion)
  Future<WipeCertificate> generateCertificate(
    List<WipeResult> wipeResults,
    String wipeMethodName,
  ) async {
    final certificateId = 'ZT-${_uuid.v4().toUpperCase().substring(0, 8)}';
    final issuedAt = DateTime.now();

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

    final deviceInfo = await _getDeviceInfo();

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

  /// Generate certificate for delayed deletion (wiped files deleted later)
  Future<WipeCertificate> generateDelayedCertificate(
    List<WipedFile> wipedFiles,
    String wipeMethodName,
  ) async {
    final certificateId = 'ZT-${_uuid.v4().toUpperCase().substring(0, 8)}';
    final issuedAt = DateTime.now();

    final files = wipedFiles
        .map(
          (f) => WipeResultSummary(
            fileName: f.fileName,
            fileSize: f.originalSize,
            wipedAt: f.wipedAt,
          ),
        )
        .toList();

    final deviceInfo = await _getDeviceInfo();

    final dataToSign = jsonEncode({
      'certificateId': certificateId,
      'files': files.map((f) => f.toJson()).toList(),
      'issuedAt': issuedAt.toIso8601String(),
      'method': wipeMethodName,
      'delayedDeletion': true,
    });
    final digitalSignature = sha256.convert(utf8.encode(dataToSign)).toString();

    return WipeCertificate(
      certificateId: certificateId,
      wipedFiles: files,
      wipeMethod: wipeMethodName,
      issuedAt: issuedAt,
      deviceInfo: deviceInfo,
      digitalSignature: digitalSignature,
    );
  }

  /// Save certificate as JSON
  Future<String> saveAsJson(WipeCertificate certificate) async {
    final directory = await _getCertificatesDirectory();
    final filePath =
        '${directory.path}/certificate_${certificate.certificateId}.json';

    final file = File(filePath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(certificate.toJson()),
    );

    return filePath;
  }

  /// Generate PDF certificate (standard - immediate deletion)
  Future<String> saveAsPdf(WipeCertificate certificate) async {
    return await _generatePdf(
      certificate: certificate,
      isDelayedDeletion: false,
      wipedAt: null,
      deletedAt: certificate.issuedAt,
    );
  }

  /// Generate PDF certificate (delayed deletion - with time difference)
  Future<String> saveAsDelayedPdf(
    WipeCertificate certificate,
    DateTime wipedAt,
    DateTime deletedAt,
  ) async {
    return await _generatePdf(
      certificate: certificate,
      isDelayedDeletion: true,
      wipedAt: wipedAt,
      deletedAt: deletedAt,
    );
  }

  Future<String> _generatePdf({
    required WipeCertificate certificate,
    required bool isDelayedDeletion,
    DateTime? wipedAt,
    required DateTime deletedAt,
  }) async {
    final pdf = pw.Document();

    // Calculate time difference for delayed deletion
    String? timeDifference;
    if (isDelayedDeletion && wipedAt != null) {
      final diff = deletedAt.difference(wipedAt);
      if (diff.inSeconds > 0) {
        final totalSeconds = diff.inSeconds;
        final days = totalSeconds ~/ 86400;
        final hours = (totalSeconds % 86400) ~/ 3600;
        final minutes = (totalSeconds % 3600) ~/ 60;
        final seconds = totalSeconds % 60;

        final parts = <String>[];

        if (days > 0) {
          parts.add('$days day${days > 1 ? 's' : ''}');
        }
        if (hours > 0) {
          parts.add('$hours hour${hours > 1 ? 's' : ''}');
        }
        if (minutes > 0) {
          parts.add('$minutes minute${minutes > 1 ? 's' : ''}');
        }
        if (seconds > 0) {
          parts.add('$seconds second${seconds > 1 ? 's' : ''}');
        }

        timeDifference = parts.join(' ');
      } else {
        timeDifference = 'Immediate';
      }
    }

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
                        border: pw.Border.all(color: PdfColors.red, width: 2),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Text(
                        'ZEROTRACE',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'CERTIFICATE OF DATA DESTRUCTION',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Secure Data Wiping Verification',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 20),

              // Certificate Info
              _buildPdfInfoRow('Certificate ID:', certificate.certificateId),

              // Show different dates for delayed deletion
              if (isDelayedDeletion && wipedAt != null) ...[
                _buildPdfInfoRow('Data Wiped At:', _dateFormat.format(wipedAt)),
                _buildPdfInfoRow(
                  'Data Deleted At:',
                  _dateFormat.format(deletedAt),
                ),
                _buildPdfInfoRow(
                  'Time Between Wipe & Delete:',
                  timeDifference ?? 'N/A',
                ),
              ] else ...[
                _buildPdfInfoRow(
                  'Issue Date:',
                  _dateFormat.format(certificate.issuedAt),
                ),
              ],

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
                      'Generated by ZeroTrace - Secure Data Wiping App',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red,
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

    final directory = await _getCertificatesDirectory();
    final filePath =
        '${directory.path}/certificate_${certificate.certificateId}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }

  /// Save certificate and create record (immediate deletion)
  Future<CertificateRecord?> saveAndRecordCertificate(
    WipeCertificate certificate,
    String pdfPath,
    String jsonPath,
    List<WipeResult> deletedFiles,
  ) async {
    try {
      final now = DateTime.now();
      final record = CertificateRecord(
        id: _uuid.v4(),
        certificateId: certificate.certificateId,
        pdfPath: pdfPath,
        jsonPath: jsonPath,
        createdAt: certificate.issuedAt,
        wipedAt: null,
        deletedAt: now,
        filesDestroyed: certificate.totalFiles,
        totalSizeDestroyed: certificate.totalSize,
        wipeMethod: certificate.wipeMethod,
        fileNames: deletedFiles.map((f) => f.fileName).toList(),
        isDelayedDeletion: false,
      );

      await _certificateStorageService.addCertificateRecord(record);
      return record;
    } catch (e) {
      return null;
    }
  }

  /// Save certificate and create record (delayed deletion)
  Future<CertificateRecord?> saveAndRecordDelayedCertificate(
    WipeCertificate certificate,
    String pdfPath,
    String jsonPath,
    List<WipedFile> wipedFiles,
    DateTime wipedAt,
    DateTime deletedAt,
  ) async {
    try {
      final record = CertificateRecord(
        id: _uuid.v4(),
        certificateId: certificate.certificateId,
        pdfPath: pdfPath,
        jsonPath: jsonPath,
        createdAt: certificate.issuedAt,
        wipedAt: wipedAt,
        deletedAt: deletedAt,
        filesDestroyed: certificate.totalFiles,
        totalSizeDestroyed: certificate.totalSize,
        wipeMethod: certificate.wipeMethod,
        fileNames: wipedFiles.map((f) => f.fileName).toList(),
        isDelayedDeletion: true,
      );

      await _certificateStorageService.addCertificateRecord(record);
      return record;
    } catch (e) {
      return null;
    }
  }

  Future<Directory> _getCertificatesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final certDir = Directory('${appDir.path}/certificates');

    if (!await certDir.exists()) {
      await certDir.create(recursive: true);
    }

    return certDir;
  }

  pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 160,
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
