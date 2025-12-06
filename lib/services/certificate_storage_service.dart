import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/certificate_record.dart';

class CertificateStorageService {
  static const String _certificatesKey = 'certificate_records';
  static const int _secureDeletePasses = 3; // Triple pass for secure deletion

  /// Save certificate records to local storage
  Future<void> saveCertificateRecords(List<CertificateRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = records.map((r) => r.toJson()).toList();
    await prefs.setString(_certificatesKey, jsonEncode(jsonList));
  }

  /// Load certificate records from local storage
  Future<List<CertificateRecord>> loadCertificateRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_certificatesKey);

    if (jsonString == null) return [];

    try {
      final jsonList = jsonDecode(jsonString) as List;
      final records = jsonList
          .map(
            (json) => CertificateRecord.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      final validRecords = <CertificateRecord>[];
      for (final record in records) {
        if (await File(record.pdfPath).exists()) {
          validRecords.add(record);
        }
      }

      if (validRecords.length != records.length) {
        await saveCertificateRecords(validRecords);
      }

      return validRecords;
    } catch (e) {
      return [];
    }
  }

  /// Add a new certificate record
  Future<void> addCertificateRecord(CertificateRecord record) async {
    final records = await loadCertificateRecords();
    records.insert(0, record);
    await saveCertificateRecords(records);
  }

  /// Delete a certificate record with SECURE WIPING (triple pass)
  Future<bool> deleteCertificateRecordSecurely(String id) async {
    final records = await loadCertificateRecords();
    final recordIndex = records.indexWhere((r) => r.id == id);

    if (recordIndex == -1) return false;

    final record = records[recordIndex];

    // Securely wipe PDF file with triple pass
    try {
      final pdfFile = File(record.pdfPath);
      if (await pdfFile.exists()) {
        await _secureWipeFile(pdfFile);
        await pdfFile.delete();
      }
    } catch (e) {
      // Ignore file deletion errors
    }

    // Securely wipe JSON file with triple pass
    try {
      final jsonFile = File(record.jsonPath);
      if (await jsonFile.exists()) {
        await _secureWipeFile(jsonFile);
        await jsonFile.delete();
      }
    } catch (e) {
      // Ignore file deletion errors
    }

    // Remove from records
    records.removeAt(recordIndex);
    await saveCertificateRecords(records);

    return true;
  }

  /// Securely wipe a file with multiple passes
  Future<void> _secureWipeFile(File file) async {
    try {
      final fileSize = await file.length();
      if (fileSize == 0) return;

      final random = Random.secure();
      const chunkSize = 4096;

      for (int pass = 0; pass < _secureDeletePasses; pass++) {
        final randomAccess = await file.open(mode: FileMode.writeOnly);

        int bytesWritten = 0;
        while (bytesWritten < fileSize) {
          final remainingBytes = fileSize - bytesWritten;
          final currentChunkSize = remainingBytes < chunkSize
              ? remainingBytes
              : chunkSize;

          // Generate random data for each pass
          final data = Uint8List.fromList(
            List.generate(currentChunkSize, (_) => random.nextInt(256)),
          );

          await randomAccess.writeFrom(data);
          bytesWritten += currentChunkSize;
        }

        await randomAccess.flush();
        await randomAccess.close();
      }
    } catch (e) {
      // Best effort - continue even if wiping fails
    }
  }

  /// Get certificate record by ID
  Future<CertificateRecord?> getCertificateRecord(String id) async {
    final records = await loadCertificateRecords();
    try {
      return records.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get total certificate count
  Future<int> getCertificateCount() async {
    final records = await loadCertificateRecords();
    return records.length;
  }

  /// Clear all certificate records securely
  Future<void> clearAllRecordsSecurely() async {
    final records = await loadCertificateRecords();

    for (final record in records) {
      try {
        final pdfFile = File(record.pdfPath);
        if (await pdfFile.exists()) {
          await _secureWipeFile(pdfFile);
          await pdfFile.delete();
        }
        final jsonFile = File(record.jsonPath);
        if (await jsonFile.exists()) {
          await _secureWipeFile(jsonFile);
          await jsonFile.delete();
        }
      } catch (e) {
        // Ignore
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_certificatesKey);
  }
}
