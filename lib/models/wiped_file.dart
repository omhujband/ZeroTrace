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
      id: json['id'],
      fileName: json['fileName'],
      filePath: json['filePath'],
      originalSize: json['originalSize'],
      wipedAt: DateTime.parse(json['wipedAt']),
      wipeMethod: json['wipeMethod'],
      passes: json['passes'],
      status: WipedFileStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => WipedFileStatus.wipedNotDeleted,
      ),
    );
  }
}

enum WipedFileStatus {
  wipedNotDeleted, // Data destroyed, file still exists (corrupted)
  deleted, // File completely removed
}
