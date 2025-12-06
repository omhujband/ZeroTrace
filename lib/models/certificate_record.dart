class CertificateRecord {
  final String id;
  final String certificateId;
  final String pdfPath;
  final String jsonPath;
  final DateTime createdAt;
  final DateTime? wipedAt; // NEW: When files were wiped
  final DateTime deletedAt; // NEW: When files were deleted
  final int filesDestroyed;
  final int totalSizeDestroyed;
  final String wipeMethod;
  final List<String> fileNames;
  final bool
  isDelayedDeletion; // NEW: Was there a delay between wipe and delete?

  CertificateRecord({
    required this.id,
    required this.certificateId,
    required this.pdfPath,
    required this.jsonPath,
    required this.createdAt,
    this.wipedAt,
    required this.deletedAt,
    required this.filesDestroyed,
    required this.totalSizeDestroyed,
    required this.wipeMethod,
    required this.fileNames,
    this.isDelayedDeletion = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'certificateId': certificateId,
    'pdfPath': pdfPath,
    'jsonPath': jsonPath,
    'createdAt': createdAt.toIso8601String(),
    'wipedAt': wipedAt?.toIso8601String(),
    'deletedAt': deletedAt.toIso8601String(),
    'filesDestroyed': filesDestroyed,
    'totalSizeDestroyed': totalSizeDestroyed,
    'wipeMethod': wipeMethod,
    'fileNames': fileNames,
    'isDelayedDeletion': isDelayedDeletion,
  };

  factory CertificateRecord.fromJson(Map<String, dynamic> json) {
    return CertificateRecord(
      id: json['id'] as String,
      certificateId: json['certificateId'] as String,
      pdfPath: json['pdfPath'] as String,
      jsonPath: json['jsonPath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      wipedAt: json['wipedAt'] != null
          ? DateTime.parse(json['wipedAt'] as String)
          : null,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : DateTime.parse(json['createdAt'] as String),
      filesDestroyed: json['filesDestroyed'] as int,
      totalSizeDestroyed: json['totalSizeDestroyed'] as int,
      wipeMethod: json['wipeMethod'] as String,
      fileNames: List<String>.from(json['fileNames'] as List),
      isDelayedDeletion: json['isDelayedDeletion'] as bool? ?? false,
    );
  }

  String get formattedCreatedDate {
    return _formatDate(createdAt);
  }

  String get formattedWipedDate {
    return wipedAt != null ? _formatDate(wipedAt!) : formattedCreatedDate;
  }

  String get formattedDeletedDate {
    return _formatDate(deletedAt);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    final bytes = totalSizeDestroyed;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get time difference between wipe and delete
  String get timeDifference {
    if (wipedAt == null) return 'Immediate';

    final diff = deletedAt.difference(wipedAt!);
    if (diff.inSeconds <= 0) return 'Immediate';

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

    return parts.join(' ');
  }
}
