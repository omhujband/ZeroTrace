class WipeResult {
  final String id;
  final String fileName;
  final String filePath;
  final int fileSize;
  final String wipeMethod;
  final int passes;
  final DateTime startTime;
  final DateTime endTime;
  final bool success;
  final String? error;
  final List<int>? corruptedDataSample; // NEW: Sample of corrupted data

  WipeResult({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.wipeMethod,
    required this.passes,
    required this.startTime,
    required this.endTime,
    required this.success,
    this.error,
    this.corruptedDataSample,
  });

  Duration get duration => endTime.difference(startTime);

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'filePath': filePath,
    'fileSize': fileSize,
    'wipeMethod': wipeMethod,
    'passes': passes,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'success': success,
    'error': error,
  };
}

class WipeMethod {
  final String name;
  final String description;
  final int passes;
  final bool useRandom;

  const WipeMethod({
    required this.name,
    required this.description,
    required this.passes,
    required this.useRandom,
  });

  static const WipeMethod quick = WipeMethod(
    name: 'Quick Zero',
    description: 'Single pass with zeros - Fast',
    passes: 1,
    useRandom: false,
  );

  static const WipeMethod standard = WipeMethod(
    name: 'Standard Random',
    description: '3 passes with random data - Recommended',
    passes: 3,
    useRandom: true,
  );

  static const WipeMethod dod = WipeMethod(
    name: 'DoD 5220.22-M',
    description: '7 passes - Military grade',
    passes: 7,
    useRandom: true,
  );

  static List<WipeMethod> get all => [quick, standard, dod];
}
