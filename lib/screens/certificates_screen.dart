import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../models/certificate_record.dart';
import '../services/certificate_storage_service.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final CertificateStorageService _storageService = CertificateStorageService();

  List<CertificateRecord> _certificates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    setState(() => _isLoading = true);

    try {
      final certificates = await _storageService.loadCertificateRecords();
      setState(() {
        _certificates = certificates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading certificates: $e', isError: true);
    }
  }

  Future<void> _openCertificate(CertificateRecord record) async {
    final file = File(record.pdfPath);
    if (!await file.exists()) {
      _showSnackBar('Certificate file not found', isError: true);
      await _loadCertificates();
      return;
    }

    if (mounted) {
      _showCertificateDetails(record);
    }
  }

  void _showCertificateDetails(CertificateRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCertificateDetailsSheet(record),
    );
  }

  Widget _buildCertificateDetailsSheet(CertificateRecord record) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.verified,
                              color: Colors.green,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Certificate',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  record.certificateId,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Details Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.grey.shade900
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _detailRow('Created', record.formattedCreatedDate),
                            const Divider(height: 20),
                            _detailRow(
                              'Files Destroyed',
                              '${record.filesDestroyed}',
                            ),
                            const Divider(height: 20),
                            _detailRow('Data Destroyed', record.formattedSize),
                            const Divider(height: 20),
                            _detailRow('Wipe Method', record.wipeMethod),

                            // Delayed deletion info
                            if (record.isDelayedDeletion &&
                                record.wipedAt != null) ...[
                              const Divider(height: 20),
                              _detailRow('Wiped At', record.formattedWipedDate),
                              const Divider(height: 20),
                              _detailRow(
                                'Deleted At',
                                record.formattedDeletedDate,
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Time Difference',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      record.timeDifference,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Files List
                      const Text(
                        'Destroyed Files:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.grey.shade900
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: record.fileNames
                              .map(
                                (name) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 16,
                                        color: Colors.green.shade400,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _viewPdf(record),
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('View PDF'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(14),
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _shareCertificate(record),
                              icon: const Icon(Icons.share),
                              label: const Text('Share'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(14),
                                foregroundColor: Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmDelete(record),
                              icon: const Icon(Icons.delete),
                              label: const Text('Delete'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(14),
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _viewPdf(CertificateRecord record) async {
    Navigator.pop(context);
    try {
      await OpenFile.open(record.pdfPath);
    } catch (e) {
      _showSnackBar('Error opening PDF: $e', isError: true);
    }
  }

  Future<void> _shareCertificate(CertificateRecord record) async {
    Navigator.pop(context);
    try {
      await Share.shareXFiles(
        [XFile(record.pdfPath)],
        subject: 'ZeroTrace Certificate - ${record.certificateId}',
        text:
            'Data Destruction Certificate\n'
            'Certificate ID: ${record.certificateId}\n'
            'Created: ${record.formattedCreatedDate}\n'
            'Files Destroyed: ${record.filesDestroyed}\n'
            'Data Destroyed: ${record.formattedSize}',
      );
    } catch (e) {
      _showSnackBar('Error sharing certificate: $e', isError: true);
    }
  }

  Future<void> _confirmDelete(CertificateRecord record) async {
    Navigator.pop(context); // Close bottom sheet

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever, size: 48, color: Colors.red),
        title: const Text('Securely Delete Certificate?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will permanently delete this certificate.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The certificate will be securely wiped using triple-pass overwriting before deletion to ensure it cannot be recovered.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Certificate: ${record.certificateId}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Securely Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteCertificate(record);
    }
  }

  Future<void> _deleteCertificate(CertificateRecord record) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Securely deleting...'),
          ],
        ),
      ),
    );

    final success = await _storageService.deleteCertificateRecordSecurely(
      record.id,
    );

    if (mounted) Navigator.pop(context); // Close loading dialog

    if (success) {
      _showSnackBar('Certificate securely deleted');
      await _loadCertificates();
    } else {
      _showSnackBar('Error deleting certificate', isError: true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificates'),
        actions: [
          if (_certificates.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Info',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('About Certificates'),
                    content: const Text(
                      'Certificates are generated when you wipe and delete files. '
                      'They serve as proof of data destruction and can be shared '
                      'for compliance or personal records.'
                      '\n\n'
                      'Deleted certificates are securely wiped with a triple-pass '
                      'overwrite before removal to prevent recovery.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _certificates.isEmpty
          ? _buildEmptyState()
          : _buildCertificatesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_outlined,
              size: 80,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 24),
            const Text(
              'No Certificates Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'When you wipe and delete files, certificates will be automatically saved here as proof of data destruction.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificatesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _certificates.length,
      itemBuilder: (context, index) {
        final record = _certificates[index];
        return _buildCertificateCard(record);
      },
    );
  }

  Widget _buildCertificateCard(CertificateRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openCertificate(record),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified,
                  color: Colors.green,
                  size: 28,
                ),
              ),

              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.certificateId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.formattedCreatedDate,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _infoChip(
                          Icons.insert_drive_file,
                          '${record.filesDestroyed} files',
                        ),
                        _infoChip(Icons.data_usage, record.formattedSize),
                        if (record.isDelayedDeletion)
                          _infoChip(Icons.timer, record.timeDifference),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
