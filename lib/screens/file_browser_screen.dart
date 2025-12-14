import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({super.key});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  static const String _externalRootsKey = 'zerotrace_external_roots';
  Directory? _currentDirectory;
  List<FileSystemEntity> _entities = [];
  Set<String> _selectedPaths = {};
  bool _isLoading = true;
  String? _error;

  // Storage volumes
  String? _internalRoot;
  final List<String> _externalRoots = []; // e.g. SD card roots
  bool _isLoadingVolumes = true;

  // Quick access for internal storage (paths are relative to internal root)
  final List<Map<String, String>> _internalQuickAccess = [
    {'name': 'DCIM (Camera)', 'path': '/DCIM'},
    {'name': 'Pictures', 'path': '/Pictures'},
    {'name': 'Downloads', 'path': '/Download'},
    {'name': 'Documents', 'path': '/Documents'},
    {'name': 'Movies', 'path': '/Movies'},
    {'name': 'Music', 'path': '/Music'},
  ];

  @override
  void initState() {
    super.initState();
    _initStorage();
  }

  Future<void> _initStorage() async {
    await _detectStorageVolumes(); // auto-detect internal/external if possible
    await _loadSavedExternalRoots(); // merge user-added external roots
    if (mounted) {
      _showQuickAccess();
    }
  }

  Future<void> _loadSavedExternalRoots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_externalRootsKey) ?? [];

      for (final path in saved) {
        if (!_externalRoots.contains(path)) {
          _externalRoots.add(path);
        }
      }
    } catch (_) {
      // ignore errors - not critical
    }
  }

  Future<void> _saveExternalRoots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_externalRootsKey, _externalRoots);
    } catch (_) {
      // ignore errors - not critical
    }
  }

  /// Detect internal + external (SD card) roots using path_provider
  Future<void> _detectStorageVolumes() async {
    try {
      // On Android, this returns multiple external storage directories
      // e.g.: /storage/emulated/0/Android/... and /storage/XXXX-XXXX/Android/...
      final List<Directory>? extDirs = await getExternalStorageDirectories();

      final roots = <String>{};

      if (extDirs != null) {
        for (final dir in extDirs) {
          final fullPath = dir.path;
          final segments = fullPath.split('/');

          // Try to strip everything after "/Android/" to get the volume root
          final androidIndex = segments.indexOf('Android');
          if (androidIndex > 1) {
            final root = segments.sublist(0, androidIndex).join('/');
            roots.add(root);
          } else {
            // Fallback if path does not contain "Android"
            // e.g.: /storage/1234-5678
            if (segments.length >= 3) {
              final root = '/${segments[1]}/${segments[2]}';
              roots.add(root);
            } else {
              roots.add(fullPath);
            }
          }
        }
      }

      if (roots.isEmpty) {
        _internalRoot = '/storage/emulated/0';
      } else {
        for (final root in roots) {
          if (root.contains('emulated/0')) {
            _internalRoot = root;
          } else {
            _externalRoots.add(root);
          }
        }
        _internalRoot ??= roots.first;
      }

      // Debug print to see what we actually detected
      debugPrint('Detected storage roots:');
      debugPrint('  internal: $_internalRoot');
      for (final ext in _externalRoots) {
        debugPrint('  external: $ext');
      }

      _internalRoot ??= '/storage/emulated/0';
    } catch (e) {
      debugPrint('Error detecting storage volumes: $e');
      _internalRoot ??= '/storage/emulated/0';
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVolumes = false;
        });
      }
    }
  }

  void _showQuickAccess() {
    setState(() {
      _isLoading = false;
      _currentDirectory = null;
      _error = null;
    });
  }

  Future<void> _openDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dir = Directory(path);

      if (!await dir.exists()) {
        setState(() {
          _error = 'Directory does not exist:\n$path';
          _isLoading = false;
        });
        return;
      }

      final entities = await dir.list().toList();

      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      setState(() {
        _currentDirectory = dir;
        _entities = entities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Cannot access this folder:\n${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _goBack() {
    if (_currentDirectory == null) {
      Navigator.pop(context);
      return;
    }

    final parent = _currentDirectory!.parent;
    final currentPath = _currentDirectory!.path;

    final isAtRoot =
        (_internalRoot != null && currentPath == _internalRoot) ||
        _externalRoots.contains(currentPath) ||
        parent.path == '/storage' ||
        parent.path == '/';

    if (isAtRoot) {
      _showQuickAccess();
    } else {
      _openDirectory(parent.path);
    }
  }

  void _toggleFileSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _selectAllFilesInCurrentFolder() {
    setState(() {
      for (final entity in _entities) {
        if (entity is File) {
          final name = _getFileName(entity.path);
          if (!name.startsWith('.')) {
            _selectedPaths.add(entity.path);
          }
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPaths.clear();
    });
  }

  void _confirmSelection() {
    final selectedFiles = _selectedPaths.map((path) => File(path)).toList();
    Navigator.pop(context, selectedFiles);
  }

  void _promptForExternalStorage() {
    final controller = TextEditingController();
    final outerContext = context; // use this for SnackBars

    showDialog(
      context: outerContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Wipe from External Storage'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the external storage name or path.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'Examples:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                '• BAC4-0F0F\n• /storage/BAC4-0F0F',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'External storage ID or path',
                  hintText: 'e.g. BAC4-0F0F or /storage/BAC4-0F0F',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '\nFor more info on finding the storage name visit "How to Use" guide',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final input = controller.text.trim();
                if (input.isEmpty) {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a storage name or path'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Build candidate path
                String candidatePath;
                if (input.startsWith('/')) {
                  candidatePath = input;
                } else {
                  candidatePath = '/storage/$input';
                }

                final dir = Directory(candidatePath);
                final exists = await dir.exists();

                if (!exists) {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Path not found or not accessible:\n$candidatePath',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // If it exists, add to external roots if needed and open it
                if (!_externalRoots.contains(candidatePath)) {
                  setState(() {
                    _externalRoots.add(candidatePath);
                  });

                  // Persist the external roots
                  await _saveExternalRoots();

                  // Show success SnackBar
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'External storage added to Browse Volumes:\n$candidatePath',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }

                if (mounted) {
                  Navigator.pop(dialogContext); // close dialog
                  _openDirectory(candidatePath);
                }
              },
              child: const Text('Open'),
            ),
          ],
        );
      },
    );
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData _getFileIconData(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();

    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
      case 'wmv':
      case '3gp':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
      case 'flac':
      case 'ogg':
        return Icons.audio_file;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip;
      case 'apk':
        return Icons.android;
      case 'json':
      case 'xml':
      case 'html':
      case 'css':
      case 'js':
        return Icons.code;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();

    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return Colors.blue;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
      case 'wmv':
      case '3gp':
        return Colors.purple;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
      case 'flac':
      case 'ogg':
        return Colors.orange;
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blueAccent;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.deepOrange;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.brown;
      case 'apk':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _goBack();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
          title: Text(
            _currentDirectory == null
                ? 'Select Files'
                : _getFileName(_currentDirectory!.path),
          ),
          actions: [
            if (_currentDirectory != null && _entities.any((e) => e is File))
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: 'Select All Files',
                onPressed: _selectAllFilesInCurrentFolder,
              ),
            if (_selectedPaths.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear Selection',
                onPressed: _clearSelection,
              ),
          ],
        ),
        body: _isLoading || _isLoadingVolumes
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorState()
            : _currentDirectory == null
            ? _buildQuickAccess()
            : _buildFileList(),
        bottomNavigationBar: _selectedPaths.isNotEmpty
            ? _buildBottomBar()
            : null,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _showQuickAccess,
              child: const Text('Go to Quick Access'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccess() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select a folder to browse files, or choose a storage volume below.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Quick Access (Internal Storage)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        ..._internalQuickAccess.map((item) => _buildQuickAccessItem(item)),

        const SizedBox(height: 24),

        const Text(
          'Browse Volumes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        // Internal storage
        Card(
          child: ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('Internal Storage'),
            subtitle: Text(_internalRoot ?? '/storage/emulated/0'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDirectory(_internalRoot ?? '/storage/emulated/0'),
          ),
        ),

        // External (SD card) volumes
        for (final root in _externalRoots)
          Card(
            child: ListTile(
              leading: const Icon(Icons.sd_storage),
              title: const Text('SD Card'),
              subtitle: Text(root),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final dir = Directory(root);
                if (await dir.exists()) {
                  _openDirectory(root);
                } else {
                  // Remove from browse volumes and persist change
                  setState(() {
                    _externalRoots.remove(root);
                  });
                  await _saveExternalRoots();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'External storage is no longer available and was removed:\n$root',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        // "Wipe from External Storage" manual entry card
        Card(
          child: ListTile(
            leading: const Icon(Icons.sd_storage),
            title: const Text('Wipe from External Storage'),
            subtitle: const Text(
              'Enter SD card or USB ID (e.g. BAC4-0F0F)',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _promptForExternalStorage,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessItem(Map<String, String> item) {
    if (_internalRoot == null) {
      return const SizedBox.shrink();
    }

    final relative = item['path']!;
    final displayPath = '$_internalRoot$relative';

    return FutureBuilder<bool>(
      future: Directory(displayPath).exists(),
      builder: (context, snapshot) {
        final exists = snapshot.data ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: exists
                    ? Colors.amber.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.folder,
                color: exists ? Colors.amber : Colors.grey,
              ),
            ),
            title: Text(
              item['name']!,
              style: TextStyle(color: exists ? null : Colors.grey),
            ),
            subtitle: Text(
              displayPath,
              style: const TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: exists
                ? const Icon(Icons.chevron_right)
                : const Text(
                    'Not found',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
            onTap: exists ? () => _openDirectory(displayPath) : null,
          ),
        );
      },
    );
  }

  Widget _buildFileList() {
    final visibleEntities = _entities.where((e) {
      final name = _getFileName(e.path);
      return !name.startsWith('.');
    }).toList();

    if (visibleEntities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            const Text('This folder is empty'),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_currentDirectory != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(
              context,
            ).colorScheme.surfaceVariant.withOpacity(0.4),
            child: Text(
              _currentDirectory!.path,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: visibleEntities.length,
            itemBuilder: (context, index) {
              final entity = visibleEntities[index];
              return _buildEntityItem(entity);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEntityItem(FileSystemEntity entity) {
    final isDirectory = entity is Directory;
    final name = _getFileName(entity.path);
    final isSelected = _selectedPaths.contains(entity.path);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      color: isSelected ? Colors.green.withOpacity(0.12) : null,
      child: ListTile(
        leading: isDirectory
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder, color: Colors.amber),
              )
            : Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getFileIconColor(name).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getFileIconData(name),
                  color: _getFileIconColor(name),
                ),
              ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: isDirectory
            ? const Text('Folder', style: TextStyle(fontSize: 11))
            : FutureBuilder<FileStat>(
                future: entity.stat(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(
                      _formatBytes(snapshot.data!.size),
                      style: const TextStyle(fontSize: 11),
                    );
                  }
                  return const Text('...', style: TextStyle(fontSize: 11));
                },
              ),
        trailing: isDirectory
            ? const Icon(Icons.chevron_right)
            : Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleFileSelection(entity.path),
                activeColor: Colors.green,
              ),
        onTap: isDirectory
            ? () => _openDirectory(entity.path)
            : () => _toggleFileSelection(entity.path),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_selectedPaths.length} selected',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _confirmSelection,
                icon: const Icon(Icons.check),
                label: const Text('SELECT FILES'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
