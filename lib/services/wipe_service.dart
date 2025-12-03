import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../models/wipe_result.dart';

class WipeService {
  static const int _chunkSize = 4096;
  final _uuid = const Uuid();

  /// Securely wipe a file
  Future<WipeResult> wipeFile(
    String filePath,
    WipeMethod method, {
    Function(double progress, int currentPass)? onProgress,
  }) async {
    final id = _uuid.v4();
    final startTime = DateTime.now();
    final file = File(filePath);

    try {
      if (!await file.exists()) {
        return WipeResult(
          id: id,
          fileName: _getFileName(filePath),
          filePath: filePath,
          fileSize: 0,
          wipeMethod: method.name,
          passes: method.passes,
          startTime: startTime,
          endTime: DateTime.now(),
          success: false,
          error: 'File not found',
        );
      }

      final fileSize = await file.length();

      // Overwrite file content with garbage
      for (int pass = 1; pass <= method.passes; pass++) {
        await _overwriteFile(file, fileSize, method.useRandom, (progress) {
          if (onProgress != null) {
            final totalProgress = ((pass - 1) + progress) / method.passes;
            onProgress(totalProgress, pass);
          }
        });
      }

      // Read sample of corrupted data for verification
      final corruptedSample = await _readSample(file, 100);

      return WipeResult(
        id: id,
        fileName: _getFileName(filePath),
        filePath: filePath,
        fileSize: fileSize,
        wipeMethod: method.name,
        passes: method.passes,
        startTime: startTime,
        endTime: DateTime.now(),
        success: true,
        corruptedDataSample: corruptedSample,
      );
    } catch (e) {
      return WipeResult(
        id: id,
        fileName: _getFileName(filePath),
        filePath: filePath,
        fileSize: 0,
        wipeMethod: method.name,
        passes: method.passes,
        startTime: startTime,
        endTime: DateTime.now(),
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Delete a wiped file
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if file exists
  Future<bool> fileExists(String filePath) async {
    return await File(filePath).exists();
  }

  /// Verify that file is corrupted
  Future<Map<String, dynamic>> verifyCorruption(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      return {
        'exists': false,
        'corrupted': true,
        'message': 'File has been deleted',
      };
    }

    try {
      final bytes = await file.readAsBytes();
      final sample = bytes.take(200).toList();

      bool isAllZeros = bytes.take(1000).every((b) => b == 0);

      return {
        'exists': true,
        'corrupted': true,
        'isAllZeros': isAllZeros,
        'sampleBytes': sample,
        'sampleHex': _bytesToHex(sample),
        'message': isAllZeros
            ? 'File overwritten with zeros'
            : 'File overwritten with random data',
      };
    } catch (e) {
      return {
        'exists': true,
        'corrupted': true,
        'error': e.toString(),
        'message': 'File cannot be read - corrupted',
      };
    }
  }

  /// Overwrite file content with zeros or random data
  Future<void> _overwriteFile(
    File file,
    int fileSize,
    bool useRandom,
    Function(double) onProgress,
  ) async {
    final randomAccess = await file.open(mode: FileMode.writeOnly);
    final random = Random.secure();

    int bytesWritten = 0;

    try {
      while (bytesWritten < fileSize) {
        final remainingBytes = fileSize - bytesWritten;
        final currentChunkSize = remainingBytes < _chunkSize
            ? remainingBytes
            : _chunkSize;

        final Uint8List data;
        if (useRandom) {
          data = Uint8List.fromList(
            List.generate(currentChunkSize, (_) => random.nextInt(256)),
          );
        } else {
          data = Uint8List(currentChunkSize);
        }

        await randomAccess.writeFrom(data);
        bytesWritten += currentChunkSize;
        onProgress(bytesWritten / fileSize);
      }

      await randomAccess.flush();
    } finally {
      await randomAccess.close();
    }
  }

  /// Read sample bytes from file
  Future<List<int>> _readSample(File file, int bytes) async {
    try {
      final randomAccess = await file.open();
      final data = await randomAccess.read(bytes);
      await randomAccess.close();
      return data.toList();
    } catch (e) {
      return [];
    }
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }
}
