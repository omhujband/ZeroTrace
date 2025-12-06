import 'dart:io';
import 'package:flutter/material.dart';
import '../models/wiped_file.dart';
import '../models/certificate.dart';
import '../services/storage_service.dart';
import '../services/wipe_service.dart';
import '../services/certificate_service.dart';

class UndeletedFilesScreen extends StatefulWidget {
  const UndeletedFilesScreen({super.key});

  @override
  State<UndeletedFilesScreen> createState() => _UndeletedFilesScreenState();
}

class _UndeletedFilesScreenState extends State<UndeletedFilesScreen> {
  final StorageService _storageService = StorageService();
  final WipeService _wipeService = WipeService();
  final CertificateService _certificateService = CertificateService();

  List<WipedFile> _wipedFiles = [];
  Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadWipedFiles();
  }

  Future<void> _loadWipedFiles() async {
    setState(() => _isLoading = true);

    try {
      final files = await _storageService.getPendingWipedFiles();

      // Verify files still exist
      final validFiles = <WipedFile>[];
      for (final file in files) {
        if (await File(file.filePath).exists()) {
          validFiles.add(file);
        } else {
          await _storageService.removeWipedFile(file.id);
        }
      }

      setState(() {
        _wipedFiles = validFiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading files: $e', isError: true);
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds = _wipedFiles.map((f) => f.id).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelectedAndGenerateCertificate() async {
    if (_selectedIds.isEmpty) return;

    // Get selected files
    final selectedFiles = _wipedFiles
        .where((f) => _selectedIds.contains(f.id))
        .toList();

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever, size: 48, color: Colors.red),
        title: const Text('Delete & Generate Certificate?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete ${selectedFiles.length} file(s) and generate a destruction certificate?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A certificate will be generated showing the time difference between wiping and deletion.',
                      style: TextStyle(fontSize: 12),
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
            child: const Text('Delete & Generate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      // Find earliest wipe time
      final earliestWipe = selectedFiles
          .map((f) => f.wipedAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);

      final now = DateTime.now();

      // Delete files
      for (final file in selectedFiles) {
        await _wipeService.deleteFile(file.filePath);
        await _storageService.removeWipedFile(file.id);
      }

      // Generate certificate
      final certificate = await _certificateService.generateDelayedCertificate(
        selectedFiles,
        selectedFiles.first.wipeMethod,
      );

      final pdfPath = await _certificateService.saveAsDelayedPdf(
        certificate,
        earliestWipe,
        now,
      );

      final jsonPath = await _certificateService.saveAsJson(certificate);

      // Save certificate record
      await _certificateService.saveAndRecordDelayedCertificate(
        certificate,
        pdfPath,
        jsonPath,
        selectedFiles,
        earliestWipe,
        now,
      );

      _selectedIds.clear();
      await _loadWipedFiles();

      if (mounted) {
        _showSuccessDialog(certificate, selectedFiles.length);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog(WipeCertificate certificate, int fileCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, size: 48, color: Colors.green),
        title: const Text('Certificate Generated!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$fileCount file(s) deleted successfully.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _infoRow('Certificate ID', certificate.certificateId),
                  _infoRow('Files Destroyed', '${certificate.totalFiles}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You can view the certificate from the Certificates section in the menu.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
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

  Future<void> _deleteSingleFile(WipedFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete, size: 48, color: Colors.red),
        title: const Text('Delete File?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete "${file.fileName}" and generate certificate?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _detailRow('Wiped', file.formattedWipedDate),
                  _detailRow('Time since wipe', file.timeSinceWiped),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();

      // Delete file
      await _wipeService.deleteFile(file.filePath);
      await _storageService.removeWipedFile(file.id);

      // Generate certificate
      final certificate = await _certificateService.generateDelayedCertificate([
        file,
      ], file.wipeMethod);

      final pdfPath = await _certificateService.saveAsDelayedPdf(
        certificate,
        file.wipedAt,
        now,
      );

      final jsonPath = await _certificateService.saveAsJson(certificate);

      await _certificateService.saveAndRecordDelayedCertificate(
        certificate,
        pdfPath,
        jsonPath,
        [file],
        file.wipedAt,
        now,
      );

      await _loadWipedFiles();

      _showSnackBar('File deleted, certificate generated');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
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
        title: const Text('Undeleted Files'),
        actions: [
          if (_wipedFiles.isNotEmpty && _selectedIds.isEmpty)
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select All',
              onPressed: _selectAll,
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear Selection',
              onPressed: _clearSelection,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isProcessing
          ? _buildProcessingState()
          : _wipedFiles.isEmpty
          ? _buildEmptyState()
          : _buildFilesList(),
      bottomNavigationBar: _selectedIds.isNotEmpty ? _buildBottomBar() : null,
    );
  }

  Widget _buildProcessingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Processing...'),
          SizedBox(height: 8),
          Text(
            'Deleting files and generating certificate',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey.shade600),
            const SizedBox(height: 24),
            const Text(
              'No Undeleted Files',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Files that are wiped but not deleted will appear here. You can delete them later and generate a certificate.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesList() {
    return Column(
      children: [
        // Info Banner
        Container(
          margin: const EdgeInsets.all(16),
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
                  'These files have been wiped (corrupted) but not deleted. '
                  'Select files to delete and generate a certificate.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Files List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _wipedFiles.length,
            itemBuilder: (context, index) {
              final file = _wipedFiles[index];
              final isSelected = _selectedIds.contains(file.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isSelected ? Colors.red.withOpacity(0.1) : null,
                child: InkWell(
                  onTap: () => _toggleSelection(file.id),
                  onLongPress: () => _deleteSingleFile(file),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Checkbox
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(file.id),
                          activeColor: Colors.red,
                        ),

                        // File Icon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.insert_drive_file,
                            color: Colors.orange,
                            size: 24,
                          ),
                        ),

                        const SizedBox(width: 12),

                        // File Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.fileName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                file.formattedSize,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Wiped ${file.timeSinceWiped}',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Delete Button
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () => _deleteSingleFile(file),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selection Count
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedIds.length} file(s) selected',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Delete & Generate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _deleteSelectedAndGenerateCertificate,
                icon: const Icon(Icons.delete_forever),
                label: const Text('DELETE & GENERATE CERTIFICATE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
