import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/wipe_result.dart';
import '../models/wiped_file.dart';
import '../services/wipe_service.dart';
import '../services/storage_service.dart';
import 'certificate_screen.dart';

class DecisionScreen extends StatefulWidget {
  final List<WipeResult> wipeResults;
  final WipeMethod wipeMethod;

  const DecisionScreen({
    super.key,
    required this.wipeResults,
    required this.wipeMethod,
  });

  @override
  State<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends State<DecisionScreen> {
  final WipeService _wipeService = WipeService();
  final StorageService _storageService = StorageService();
  final _uuid = const Uuid();

  // Track decision for each file: true = delete, false = keep
  late Map<String, bool> _decisions;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Default: all files set to delete
    _decisions = {
      for (var r in widget.wipeResults.where((r) => r.success))
        r.filePath: true,
    };
  }

  void _toggleDecision(String filePath) {
    setState(() {
      _decisions[filePath] = !(_decisions[filePath] ?? true);
    });
  }

  void _setAllDelete() {
    setState(() {
      for (var key in _decisions.keys) {
        _decisions[key] = true;
      }
    });
  }

  void _setAllKeep() {
    setState(() {
      for (var key in _decisions.keys) {
        _decisions[key] = false;
      }
    });
  }

  Future<void> _processDecisions() async {
    setState(() => _isProcessing = true);

    final deletedFiles = <WipeResult>[];
    final keptFiles = <WipeResult>[];

    for (final result in widget.wipeResults.where((r) => r.success)) {
      final shouldDelete = _decisions[result.filePath] ?? true;

      if (shouldDelete) {
        // Delete the file
        final deleted = await _wipeService.deleteFile(result.filePath);
        if (deleted) {
          deletedFiles.add(result);
        }
      } else {
        // Keep the file - save to storage for later management
        final wipedFile = WipedFile(
          id: _uuid.v4(),
          fileName: result.fileName,
          filePath: result.filePath,
          originalSize: result.fileSize,
          wipedAt: result.endTime,
          wipeMethod: result.wipeMethod,
          passes: result.passes,
          status: WipedFileStatus.wipedNotDeleted,
        );
        await _storageService.addWipedFile(wipedFile);
        keptFiles.add(result);
      }
    }

    setState(() => _isProcessing = false);

    // Navigate to certificate screen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CertificateScreen(
            deletedFiles: deletedFiles,
            keptFiles: keptFiles,
            wipeMethodName: widget.wipeMethod.name,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deleteCount = _decisions.values.where((v) => v).length;
    final keepCount = _decisions.values.where((v) => !v).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete or Keep'),
        automaticallyImplyLeading: false,
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing your choices...'),
                ],
              ),
            )
          : Column(
              children: [
                // Explanation
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.help_outline,
                        size: 40,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'What would you like to do?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The data in these files has been destroyed. '
                        'Choose whether to delete each file completely '
                        'or keep the corrupted file on your device.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Quick Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _setAllDelete,
                          icon: const Icon(Icons.delete_forever, size: 18),
                          label: const Text('Delete All'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _setAllKeep,
                          icon: const Icon(Icons.folder, size: 18),
                          label: const Text('Keep All'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Files List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.wipeResults
                        .where((r) => r.success)
                        .length,
                    itemBuilder: (context, index) {
                      final result = widget.wipeResults
                          .where((r) => r.success)
                          .toList()[index];
                      final willDelete = _decisions[result.filePath] ?? true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: willDelete
                            ? Colors.red.withOpacity(0.05)
                            : Colors.blue.withOpacity(0.05),
                        child: ListTile(
                          leading: Icon(
                            willDelete ? Icons.delete : Icons.folder,
                            color: willDelete ? Colors.red : Colors.blue,
                          ),
                          title: Text(
                            result.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            willDelete
                                ? 'Will be DELETED'
                                : 'Will be KEPT (corrupted)',
                            style: TextStyle(
                              fontSize: 12,
                              color: willDelete
                                  ? Colors.red.shade300
                                  : Colors.blue.shade300,
                            ),
                          ),
                          trailing: Switch(
                            value: willDelete,
                            activeColor: Colors.red,
                            inactiveThumbColor: Colors.blue,
                            onChanged: (_) => _toggleDecision(result.filePath),
                          ),
                          onTap: () => _toggleDecision(result.filePath),
                        ),
                      );
                    },
                  ),
                ),

                // Summary & Confirm Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  child: Column(
                    children: [
                      // Summary
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _summaryChip(
                            icon: Icons.delete,
                            label: 'Delete',
                            count: deleteCount,
                            color: Colors.red,
                          ),
                          _summaryChip(
                            icon: Icons.folder,
                            label: 'Keep',
                            count: keepCount,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Confirm Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _processDecisions,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Colors.green,
                          ),
                          child: const Text(
                            'CONFIRM & GENERATE CERTIFICATE',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      // Note about kept files
                      if (keepCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '💡 Kept files can be deleted later from the app',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: $count',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
