import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../models/wipe_result.dart';
import '../services/storage_service.dart';
import 'wipe_progress_screen.dart';
import 'wiped_files_screen.dart';
import 'file_browser_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<File> _selectedFiles = [];
  WipeMethod _selectedMethod = WipeMethod.standard;

  bool _hasPermission = false;
  bool _isCheckingPermission = true;
  int _pendingWipedFilesCount = 0;
  String _statusMessage = '';

  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
    _loadPendingCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _loadPendingCount() async {
    try {
      final pending = await _storageService.getPendingWipedFiles();
      setState(() {
        _pendingWipedFilesCount = pending.length;
      });
    } catch (e) {
      debugPrint('Error loading pending count: $e');
    }
  }

  Future<void> _checkPermission() async {
    setState(() {
      _isCheckingPermission = true;
      _statusMessage = 'Checking permissions...';
    });

    try {
      bool granted = false;

      if (await Permission.manageExternalStorage.isGranted) {
        granted = true;
      } else if (await Permission.storage.isGranted) {
        granted = true;
      }

      if (granted) {
        granted = await _testDirectoryAccess();
      }

      setState(() {
        _hasPermission = granted;
        _isCheckingPermission = false;
        _statusMessage = granted ? 'Permission granted' : 'Permission needed';
      });
    } catch (e) {
      debugPrint('Permission check error: $e');
      setState(() {
        _hasPermission = false;
        _isCheckingPermission = false;
        _statusMessage = 'Error checking permissions';
      });
    }
  }

  Future<bool> _testDirectoryAccess() async {
    try {
      final testPaths = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Pictures',
      ];

      for (final path in testPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          try {
            await dir.list().first;
            return true;
          } catch (e) {
            continue;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _requestPermission() async {
    setState(() {
      _statusMessage = 'Requesting permission...';
    });

    try {
      final status = await Permission.manageExternalStorage.request();

      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) {
          final shouldOpen = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.folder_open, size: 48, color: Colors.blue),
              title: const Text('Storage Access Required'),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ZeroTrace needs "All Files Access" to browse and wipe files.',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '1. Tap "Open Settings"\n'
                    '2. Find "ZeroTrace"\n'
                    '3. Enable "Allow access to manage all files"\n'
                    '4. Return to this app',
                    style: TextStyle(fontSize: 13),
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
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );

          if (shouldOpen == true) {
            await openAppSettings();
          }
        }
      }

      await Permission.storage.request();
      await _checkPermission();
    } catch (e) {
      debugPrint('Permission request error: $e');
      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _pickFiles() async {
    if (!_hasPermission) {
      _showSnackBar('Please grant storage permission first', isError: true);
      return;
    }

    final result = await Navigator.push<List<File>>(
      context,
      MaterialPageRoute(builder: (context) => const FileBrowserScreen()),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _selectedFiles = result;
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _startWipe() {
    if (_selectedFiles.isEmpty) {
      _showSnackBar('Please select files to wipe', isError: true);
      return;
    }

    _showConfirmDialog();
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          size: 50,
          color: Colors.orange,
        ),
        title: const Text('Confirm Data Wipe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will PERMANENTLY destroy the data!',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _infoRow('Files to wipe:', '${_selectedFiles.length}'),
            _infoRow('Wipe method:', _selectedMethod.name),
            _infoRow('Passes:', '${_selectedMethod.passes}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _navigateToWipeScreen();
            },
            child: const Text('WIPE DATA'),
          ),
        ],
      ),
    );
  }

  void _navigateToWipeScreen() {
    final filePaths = _selectedFiles.map((f) => f.path).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WipeProgressScreen(
          filePaths: filePaths,
          wipeMethod: _selectedMethod,
        ),
      ),
    ).then((_) {
      setState(() {
        _selectedFiles = [];
      });
      _loadPendingCount();
    });
  }

  void _navigateToWipedFiles() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WipedFilesScreen()),
    ).then((_) => _loadPendingCount());
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _toggleTheme() {
    final appState = ZeroTraceApp.of(context);
    appState?.themeProvider.toggleTheme();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield, size: 24),
            SizedBox(width: 8),
            Text('ZeroTrace'),
          ],
        ),
        actions: [
          // Theme Toggle Button
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDarkMode
                ? 'Switch to Light Mode'
                : 'Switch to Dark Mode',
            onPressed: _toggleTheme,
          ),

          // Wiped Files Badge
          if (_pendingWipedFilesCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.folder_delete),
                  tooltip: 'Wiped Files',
                  onPressed: _navigateToWipedFiles,
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_pendingWipedFilesCount',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isCheckingPermission
          ? _buildLoadingState()
          : !_hasPermission
          ? _buildPermissionRequest()
          : _buildMainContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(_statusMessage, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPermissionRequest() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.folder_off, size: 64, color: Colors.orange),
          ),

          const SizedBox(height: 24),

          const Text(
            'Storage Access Required',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          const Text(
            'ZeroTrace needs "All Files Access" permission to browse and securely wipe files from your device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _requestPermission,
              icon: const Icon(Icons.security),
              label: const Text('GRANT PERMISSION'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings),
              label: const Text('Open App Settings'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),

          const SizedBox(height: 12),

          TextButton.icon(
            onPressed: _checkPermission,
            icon: const Icon(Icons.refresh),
            label: const Text('Check Again'),
          ),

          const SizedBox(height: 24),

          Text(
            'Status: $_statusMessage',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.settings, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Wipe Method',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...WipeMethod.all.map(
                    (method) => RadioListTile<WipeMethod>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(method.name),
                      subtitle: Text(
                        method.description,
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: method,
                      groupValue: _selectedMethod,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedMethod = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.folder_open),
              label: const Text('BROWSE & SELECT FILES'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: _selectedFiles.isEmpty
              ? _buildEmptyState()
              : _buildFilesList(),
        ),

        if (_selectedFiles.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startWipe,
                icon: const Icon(Icons.delete_forever),
                label: Text(
                  'WIPE ${_selectedFiles.length} FILE(S)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.file_present, size: 64, color: Colors.grey.shade700),
          const SizedBox(height: 16),
          const Text(
            'No files selected',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap "Browse & Select Files" to choose files',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _selectedFiles.length,
      itemBuilder: (context, index) {
        final file = _selectedFiles[index];
        final fileName = file.path.split('/').last;

        return Card(
          child: ListTile(
            leading: _getFileIcon(fileName),
            title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: FutureBuilder<int>(
              future: file.length(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(_formatBytes(snapshot.data!));
                }
                return const Text('...');
              },
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _removeFile(index),
            ),
          ),
        );
      },
    );
  }

  Widget _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    IconData icon;
    Color color;

    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        icon = Icons.image;
        color = Colors.blue;
        break;
      case 'mp4':
      case 'avi':
      case 'mov':
        icon = Icons.video_file;
        color = Colors.purple;
        break;
      case 'mp3':
      case 'wav':
        icon = Icons.audio_file;
        color = Colors.orange;
        break;
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
