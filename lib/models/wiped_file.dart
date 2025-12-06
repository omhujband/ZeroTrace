class WipedFile {
  final String id;
  final String fileName;
  final String filePath;
  final int originalSize;
  final DateTime wipedAt;
  final String wipeMethod;
  final int passes;
  final WipedFileStatus status;

  WipedFile({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.originalSize,
    required this.wipedAt,
    required this.wipeMethod,
    required this.passes,
    required this.status,
  });

  WipedFile copyWith({WipedFileStatus? status}) {
    return WipedFile(
      id: id,
      fileName: fileName,
      filePath: filePath,
      originalSize: originalSize,
      wipedAt: wipedAt,
      wipeMethod: wipeMethod,
      passes: passes,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'filePath': filePath,
    'originalSize': originalSize,
    'wipedAt': wipedAt.toIso8601String(),
    'wipeMethod': wipeMethod,
    'passes': passes,
    'status': status.name,
  };

  factory WipedFile.fromJson(Map<String, dynamic> json) {
    return WipedFile(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      filePath: json['filePath'] as String,
      originalSize: json['originalSize'] as int,
      wipedAt: DateTime.parse(json['wipedAt'] as String),
      wipeMethod: json['wipeMethod'] as String,
      passes: json['passes'] as int,
      status: WipedFileStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => WipedFileStatus.wipedNotDeleted,
      ),
    );
  }

  /// Format wiped date
  String get formattedWipedDate {
    return '${wipedAt.day.toString().padLeft(2, '0')}/'
        '${wipedAt.month.toString().padLeft(2, '0')}/'
        '${wipedAt.year} '
        '${wipedAt.hour.toString().padLeft(2, '0')}:'
        '${wipedAt.minute.toString().padLeft(2, '0')}';
  }

  /// Format file size
  String get formattedSize {
    final bytes = originalSize;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get time since wiped
  String get timeSinceWiped {
    final now = DateTime.now();
    final difference = now.difference(wipedAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}

enum WipedFileStatus {
  wipedNotDeleted, // Data destroyed, file still exists (corrupted)
  deleted, // File completely removed
}
