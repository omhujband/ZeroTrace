import 'dart:io';
import 'package:flutter/material.dart';
import '../models/wiped_file.dart';
import '../services/storage_service.dart';
import '../services/wipe_service.dart';
import '../services/certificate_service.dart';

class WipedFilesScreen extends StatefulWidget {
  const WipedFilesScreen({super.key});

  @override
  State<WipedFilesScreen> createState() => _WipedFilesScreenState();
}

class _WipedFilesScreenState extends State<WipedFilesScreen> {
  final StorageService _storageService = StorageService();
  final WipeService _wipeService = WipeService();
  final CertificateService _certificateService = CertificateService();

  List<WipedFile> _wipedFiles = [];
  bool _isLoading = true;
  Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadWipedFiles();
  }

  Future<void> _loadWipedFiles() async {
    setState(() => _isLoading = true);

    final files = await _storageService.getPendingWipedFiles();

    // Check if files still exist
    final validFiles = <WipedFile>[];
    for (final file in files) {
      if (await File(file.filePath).exists()) {
        validFiles.add(file);
      } else {
        // File was deleted externally, remove from storage
        await _storageService.removeWipedFile(file.id);
      }
    }

    setState(() {
      _wipedFiles = validFiles;
      _isLoading = false;
    });
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

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Files?'),
        content: Text(
          'Delete ${_selectedIds.length} corrupted file(s)?\n\n'
          'This will permanently remove them from your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Delete selected files
    for (final id in _selectedIds) {
      final file = _wipedFiles.firstWhere((f) => f.id == id);
      final deleted = await _wipeService.deleteFile(file.filePath);
      if (deleted) {
        await _storageService.removeWipedFile(id);
      }
    }

    _selectedIds.clear();
    await _loadWipedFiles();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Files deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteSingleFile(WipedFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text('Delete "${file.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final deleted = await _wipeService.deleteFile(file.filePath);
    if (deleted) {
      await _storageService.removeWipedFile(file.id);
      await _loadWipedFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${file.fileName}" deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📁 Wiped Files'),
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
          : _wipedFiles.isEmpty
          ? _buildEmptyState()
          : _buildFilesList(),
      bottomNavigationBar: _selectedIds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete_forever),
                  label: Text('DELETE ${_selectedIds.length} FILE(S)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey.shade700),
          const SizedBox(height: 16),
          const Text(
            'No Pending Wiped Files',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Files that are wiped but not deleted\nwill appear here',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
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
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'These files have been wiped (corrupted). '
                  'They still take up space but cannot be opened. '
                  'Delete them when ready.',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade300),
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
                child: ListTile(
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(file.id),
                    activeColor: Colors.red,
                  ),
                  title: Text(
                    file.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Size: ${_formatBytes(file.originalSize)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        'Wiped: ${_formatDate(file.wipedAt)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        'Method: ${file.wipeMethod}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade300,
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteSingleFile(file),
                  ),
                  onTap: () => _toggleSelection(file.id),
                  onLongPress: () => _deleteSingleFile(file),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
