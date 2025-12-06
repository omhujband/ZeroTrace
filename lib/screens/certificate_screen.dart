import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../models/wipe_result.dart';
import '../models/certificate.dart';
import '../services/certificate_service.dart';

class CertificateScreen extends StatefulWidget {
  final List<WipeResult> deletedFiles;
  final List<WipeResult> keptFiles;
  final String wipeMethodName;

  const CertificateScreen({
    super.key,
    required this.deletedFiles,
    required this.keptFiles,
    required this.wipeMethodName,
  });

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final CertificateService _certificateService = CertificateService();

  WipeCertificate? _certificate;
  String? _pdfPath;
  String? _jsonPath;
  bool _isGenerating = true;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _generateCertificate();
  }

  Future<void> _generateCertificate() async {
    try {
      if (widget.deletedFiles.isNotEmpty) {
        final certificate = await _certificateService.generateCertificate(
          widget.deletedFiles,
          widget.wipeMethodName,
        );

        final pdfPath = await _certificateService.saveAsPdf(certificate);
        final jsonPath = await _certificateService.saveAsJson(certificate);

        setState(() {
          _certificate = certificate;
          _pdfPath = pdfPath;
          _jsonPath = jsonPath;
        });
      }

      setState(() {
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      _showSnackBar('Error generating certificate: $e', isError: true);
    }
  }

  Future<void> _saveCertificateRecord() async {
    if (_certificate == null ||
        _pdfPath == null ||
        _jsonPath == null ||
        _isSaved) {
      return;
    }

    try {
      await _certificateService.saveAndRecordCertificate(
        _certificate!,
        _pdfPath!,
        _jsonPath!,
        widget.deletedFiles,
      );
      setState(() {
        _isSaved = true;
      });
    } catch (e) {
      debugPrint('Error saving certificate record: $e');
    }
  }

  void _openPdf() {
    if (_pdfPath != null) {
      OpenFile.open(_pdfPath!);
    }
  }

  void _shareCertificate() {
    if (_pdfPath != null) {
      Share.shareXFiles(
        [XFile(_pdfPath!)],
        subject: 'ZeroTrace Certificate - ${_certificate?.certificateId}',
        text:
            'Data Destruction Certificate\n'
            'Certificate ID: ${_certificate?.certificateId}\n'
            'Files Destroyed: ${_certificate?.totalFiles}\n'
            'Method: ${_certificate?.wipeMethod}',
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _goHome() async {
    // Save certificate record before going home
    await _saveCertificateRecord();

    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} '
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificate'),
        automaticallyImplyLeading: false,
      ),
      body: _isGenerating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Generating Certificate...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _summaryCard(
                          icon: Icons.delete_forever,
                          title: 'Deleted',
                          count: widget.deletedFiles.length,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _summaryCard(
                          icon: Icons.folder,
                          title: 'Kept',
                          count: widget.keptFiles.length,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Certificate Card
                  if (_certificate != null) ...[
                    _buildCertificateCard(),
                    const SizedBox(height: 20),
                  ],

                  // Deleted Files Section
                  if (widget.deletedFiles.isNotEmpty) ...[
                    _sectionTitle('🗑️ Deleted Files (Certificate Issued)'),
                    const SizedBox(height: 8),
                    ...widget.deletedFiles.map(
                      (file) => _fileCard(file, isDeleted: true),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Kept Files Section
                  if (widget.keptFiles.isNotEmpty) ...[
                    _sectionTitle(
                      '📁 Kept Files (Corrupted, Pending Deletion)',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'These files are corrupted but not deleted. '
                              'You can delete them later from the menu.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...widget.keptFiles.map(
                      (file) => _fileCard(file, isDeleted: false),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // No files deleted message
                  if (widget.deletedFiles.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 40),
                          SizedBox(height: 12),
                          Text(
                            'No Certificate Generated',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Certificates are only generated for files '
                            'that have been both wiped AND deleted.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Action Buttons
                  if (_certificate != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openPdf,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('View PDF'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _shareCertificate,
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Auto-save notice
                  if (_certificate != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Certificate will be saved automatically when you tap DONE.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Done Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _goHome,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        'DONE',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildCertificateCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade700, width: 2),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade900.withOpacity(0.3),
              Colors.green.shade800.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified, color: Colors.green.shade400, size: 30),
                const SizedBox(width: 8),
                const Text(
                  'CERTIFICATE OF DATA DESTRUCTION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            _certificateRow('Certificate ID', _certificate!.certificateId),
            _certificateRow('Issue Date', _formatDate(_certificate!.issuedAt)),
            _certificateRow('Wipe Method', _certificate!.wipeMethod),
            _certificateRow('Files Destroyed', '${_certificate!.totalFiles}'),
            _certificateRow(
              'Data Destroyed',
              _formatBytes(_certificate!.totalSize),
            ),
            const Divider(height: 30),
            const Text(
              'DIGITAL SIGNATURE (SHA-256)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _certificate!.digitalSignature,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 8,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _certificateRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _fileCard(WipeResult file, {required bool isDeleted}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDeleted
                ? Colors.green.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDeleted ? Icons.check : Icons.folder,
            color: isDeleted ? Colors.green : Colors.blue,
            size: 20,
          ),
        ),
        title: Text(
          file.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_formatBytes(file.fileSize)} • ${file.wipeMethod}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDeleted
                ? Colors.green.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isDeleted ? 'DELETED' : 'KEPT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDeleted ? Colors.green : Colors.blue,
            ),
          ),
        ),
      ),
    );
  }
}
