import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wiped_file.dart';

class StorageService {
  static const String _wipedFilesKey = 'wiped_files';

  /// Save wiped files to local storage
  Future<void> saveWipedFiles(List<WipedFile> files) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = files.map((f) => f.toJson()).toList();
    await prefs.setString(_wipedFilesKey, jsonEncode(jsonList));
  }

  /// Load wiped files from local storage
  Future<List<WipedFile>> loadWipedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_wipedFilesKey);

    if (jsonString == null) return [];

    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => WipedFile.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Add a wiped file to storage
  Future<void> addWipedFile(WipedFile file) async {
    final files = await loadWipedFiles();
    files.add(file);
    await saveWipedFiles(files);
  }

  /// Remove a wiped file from storage (after deletion)
  Future<void> removeWipedFile(String id) async {
    final files = await loadWipedFiles();
    files.removeWhere((f) => f.id == id);
    await saveWipedFiles(files);
  }

  /// Update wiped file status
  Future<void> updateWipedFileStatus(String id, WipedFileStatus status) async {
    final files = await loadWipedFiles();
    final index = files.indexWhere((f) => f.id == id);

    if (index != -1) {
      files[index] = files[index].copyWith(status: status);
      await saveWipedFiles(files);
    }
  }

  /// Get only pending (not deleted) wiped files
  Future<List<WipedFile>> getPendingWipedFiles() async {
    final files = await loadWipedFiles();
    return files
        .where((f) => f.status == WipedFileStatus.wipedNotDeleted)
        .toList();
  }

  /// Clear all wiped files history
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wipedFilesKey);
  }
}
