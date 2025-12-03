import 'dart:io';
import 'package:flutter/material.dart';

class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({super.key});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  Directory? _currentDirectory;
  List<FileSystemEntity> _entities = [];
  Set<String> _selectedPaths = {};
  bool _isLoading = true;
  String? _error;

  // Common storage directories
  final List<Map<String, String>> _quickAccess = [
    {'name': 'DCIM (Camera)', 'path': '/storage/emulated/0/DCIM'},
    {'name': 'Pictures', 'path': '/storage/emulated/0/Pictures'},
    {'name': 'Downloads', 'path': '/storage/emulated/0/Download'},
    {'name': 'Documents', 'path': '/storage/emulated/0/Documents'},
    {'name': 'Movies', 'path': '/storage/emulated/0/Movies'},
    {'name': 'Music', 'path': '/storage/emulated/0/Music'},
    {'name': 'WhatsApp Media', 'path': '/storage/emulated/0/WhatsApp/Media'},
  ];

  @override
  void initState() {
    super.initState();
    _loadQuickAccess();
  }

  void _loadQuickAccess() {
    setState(() {
      _isLoading = false;
      _currentDirectory = null;
    });
  }

  Future<void> _openDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        final entities = await dir.list().toList();

        // Sort: directories first, then files
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
      } else {
        setState(() {
          _error = 'Directory not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Cannot access: ${e.toString()}';
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

    // Check if we're at root of accessible storage
    if (_currentDirectory!.path == '/storage/emulated/0' ||
        parent.path == '/storage/emulated' ||
        parent.path == '/storage') {
      _loadQuickAccess();
    } else {
      _openDirectory(parent.path);
    }
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _confirmSelection() {
    final selectedFiles = _selectedPaths.map((p) => File(p)).toList();
    Navigator.pop(context, selectedFiles);
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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
            if (_selectedPaths.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedPaths.clear();
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorState()
            : _currentDirectory == null
            ? _buildQuickAccess()
            : _buildFileList(),
        bottomNavigationBar: _selectedPaths.isNotEmpty
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: SafeArea(
                  child: ElevatedButton.icon(
                    onPressed: _confirmSelection,
                    icon: const Icon(Icons.check),
                    label: Text('SELECT ${_selectedPaths.length} FILE(S)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _error ?? 'An error occurred',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadQuickAccess,
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccess() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Quick Access',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ..._quickAccess.map(
          (item) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder, color: Colors.blue),
              ),
              title: Text(item['name']!),
              subtitle: Text(
                item['path']!,
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openDirectory(item['path']!),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Or browse from root:',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('Internal Storage'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDirectory('/storage/emulated/0'),
          ),
        ),
      ],
    );
  }

  Widget _buildFileList() {
    if (_entities.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('This folder is empty'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _entities.length,
      itemBuilder: (context, index) {
        final entity = _entities[index];
        final isDirectory = entity is Directory;
        final name = _getFileName(entity.path);
        final isSelected = _selectedPaths.contains(entity.path);

        // Skip hidden files
        if (name.startsWith('.')) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          color: isSelected ? Colors.green.withOpacity(0.1) : null,
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
                : _getFileIcon(name),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: isDirectory
                ? const Text('Folder')
                : FutureBuilder<FileStat>(
                    future: entity.stat(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(_formatBytes(snapshot.data!.size));
                      }
                      return const Text('...');
                    },
                  ),
            trailing: isDirectory
                ? const Icon(Icons.chevron_right)
                : Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(entity.path),
                    activeColor: Colors.green,
                  ),
            onTap: isDirectory
                ? () => _openDirectory(entity.path)
                : () => _toggleSelection(entity.path),
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
      case 'webp':
        icon = Icons.image;
        color = Colors.blue;
        break;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        icon = Icons.video_file;
        color = Colors.purple;
        break;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
        icon = Icons.audio_file;
        color = Colors.orange;
        break;
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case 'xls':
      case 'xlsx':
        icon = Icons.table_chart;
        color = Colors.green;
        break;
      case 'zip':
      case 'rar':
      case '7z':
        icon = Icons.folder_zip;
        color = Colors.brown;
        break;
      case 'apk':
        icon = Icons.android;
        color = Colors.green;
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
}
