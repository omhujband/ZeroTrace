class WipeCertificate {
  final String certificateId;
  final List<WipeResultSummary> wipedFiles;
  final String wipeMethod;
  final DateTime issuedAt;
  final String deviceInfo;
  final String digitalSignature;

  WipeCertificate({
    required this.certificateId,
    required this.wipedFiles,
    required this.wipeMethod,
    required this.issuedAt,
    required this.deviceInfo,
    required this.digitalSignature,
  });

  int get totalFiles => wipedFiles.length;

  int get totalSize => wipedFiles.fold(0, (sum, f) => sum + f.fileSize);

  Map<String, dynamic> toJson() => {
    'certificateId': certificateId,
    'wipedFiles': wipedFiles.map((f) => f.toJson()).toList(),
    'wipeMethod': wipeMethod,
    'issuedAt': issuedAt.toIso8601String(),
    'deviceInfo': deviceInfo,
    'digitalSignature': digitalSignature,
    'totalFiles': totalFiles,
    'totalSizeBytes': totalSize,
  };

  factory WipeCertificate.fromJson(Map<String, dynamic> json) {
    return WipeCertificate(
      certificateId: json['certificateId'] as String,
      wipedFiles: (json['wipedFiles'] as List)
          .map((e) => WipeResultSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      wipeMethod: json['wipeMethod'] as String,
      issuedAt: DateTime.parse(json['issuedAt'] as String),
      deviceInfo: json['deviceInfo'] as String,
      digitalSignature: json['digitalSignature'] as String,
    );
  }
}

class WipeResultSummary {
  final String fileName;
  final int fileSize;
  final DateTime wipedAt;

  WipeResultSummary({
    required this.fileName,
    required this.fileSize,
    required this.wipedAt,
  });

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'fileSize': fileSize,
    'wipedAt': wipedAt.toIso8601String(),
  };

  factory WipeResultSummary.fromJson(Map<String, dynamic> json) {
    return WipeResultSummary(
      fileName: json['fileName'] as String,
      fileSize: json['fileSize'] as int,
      wipedAt: DateTime.parse(json['wipedAt'] as String),
    );
  }
}
