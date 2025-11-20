import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import 'storage.dart';

class BackupService {
  static const String _autoBackupEnabledKey = 'auto_backup_enabled';
  static const String _autoBackupPathKey = 'auto_backup_path';
  static const String _lastBackupDateKey = 'last_backup_date';
  static const String _autoBackupFrequencyKey = 'auto_backup_frequency';

  /// Create a backup of all app data
  static Future<Map<String, dynamic>> createBackupData() async {
    final budgets = await Storage.loadBudgets();
    final prefs = await SharedPreferences.getInstance();

    return {
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'budgets': budgets.map((b) => b.toJson()).toList(),
      'preferences': {
        'checklists': _extractChecklistsFromPrefs(prefs),
        'salary_overrides': _extractSalaryOverridesFromPrefs(prefs),
        'item_overrides': _extractItemOverridesFromPrefs(prefs),
        'item_amount_overrides': _extractItemAmountOverridesFromPrefs(prefs),
      },
    };
  }

  /// Export backup to a JSON file
  static Future<String?> exportBackup({String? customPath}) async {
    try {
      final backupData = await createBackupData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final bytes = utf8.encode(jsonString);

      String? filePath;

      if (customPath != null) {
        // Use custom path for auto backup
        filePath = customPath;
        final file = File(filePath);
        await file.writeAsString(jsonString);
      } else {
        // Let user choose location for manual backup
        // For mobile platforms, we need to use getDirectoryPath and create the file manually
        if (Platform.isAndroid || Platform.isIOS) {
          final result = await FilePicker.platform.getDirectoryPath(
            dialogTitle: 'Select Backup Location',
          );

          if (result == null) return null;

          final fileName = 'sugo_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
          filePath = '$result${Platform.pathSeparator}$fileName';
          final file = File(filePath);
          await file.writeAsString(jsonString);
        } else {
          // For desktop platforms, use saveFile
          final result = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Backup File',
            fileName: 'sugo_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
            bytes: bytes,
          );

          if (result == null) return null;
          filePath = result;
        }
      }

      // Update last backup date
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupDateKey, DateTime.now().toIso8601String());

      return filePath;
    } catch (e) {
      throw Exception('Failed to export backup: $e');
    }
  }

  /// Import backup from a JSON file
  static Future<bool> importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select Backup File',
      );

      if (result == null || result.files.isEmpty) return false;

      final file = File(result.files.first.path!);
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      await restoreBackupData(backupData);
      return true;
    } catch (e) {
      throw Exception('Failed to import backup: $e');
    }
  }

  /// Restore data from backup
  static Future<void> restoreBackupData(Map<String, dynamic> backupData) async {
    try {
      final version = backupData['version'] as int;
      if (version != 1) {
        throw Exception('Unsupported backup version: $version');
      }

      // Clear existing data
      final existingBudgets = await Storage.loadBudgets();
      for (final budget in existingBudgets) {
        await Storage.deleteBudget(budget.id);
      }

      // Restore budgets
      final budgetsJson = backupData['budgets'] as List<dynamic>;
      final budgets = budgetsJson
          .map((json) => Budget.fromJson(json as Map<String, dynamic>))
          .toList();

      for (final budget in budgets) {
        await Storage.saveBudget(budget);
      }

      // Restore preferences
      final prefs = await SharedPreferences.getInstance();
      final prefsData = backupData['preferences'] as Map<String, dynamic>?;

      if (prefsData != null) {
        // Restore checklists
        final checklists = prefsData['checklists'] as Map<String, dynamic>?;
        if (checklists != null) {
          for (final entry in checklists.entries) {
            await prefs.setString(entry.key, jsonEncode(entry.value));
          }
        }

        // Restore salary overrides
        final salaryOverrides = prefsData['salary_overrides'] as Map<String, dynamic>?;
        if (salaryOverrides != null) {
          for (final entry in salaryOverrides.entries) {
            await prefs.setString(entry.key, jsonEncode(entry.value));
          }
        }

        // Restore item overrides
        final itemOverrides = prefsData['item_overrides'] as Map<String, dynamic>?;
        if (itemOverrides != null) {
          for (final entry in itemOverrides.entries) {
            await prefs.setString(entry.key, jsonEncode(entry.value));
          }
        }

        // Restore item amount overrides
        final itemAmountOverrides = prefsData['item_amount_overrides'] as Map<String, dynamic>?;
        if (itemAmountOverrides != null) {
          for (final entry in itemAmountOverrides.entries) {
            await prefs.setString(entry.key, jsonEncode(entry.value));
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to restore backup: $e');
    }
  }

  /// Extract all checklist data from SharedPreferences
  static Map<String, dynamic> _extractChecklistsFromPrefs(SharedPreferences prefs) {
    final result = <String, dynamic>{};
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith('sugo_checklists_v1_')) {
        final value = prefs.getString(key);
        if (value != null) {
          try {
            result[key] = jsonDecode(value);
          } catch (_) {}
        }
      }
    }

    return result;
  }

  /// Extract all salary override data from SharedPreferences
  static Map<String, dynamic> _extractSalaryOverridesFromPrefs(SharedPreferences prefs) {
    final result = <String, dynamic>{};
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith('sugo_salary_overrides_v1_') &&
          !key.contains('_items_') &&
          !key.contains('_item_amounts_')) {
        final value = prefs.getString(key);
        if (value != null) {
          try {
            result[key] = jsonDecode(value);
          } catch (_) {}
        }
      }
    }

    return result;
  }

  /// Extract all item override data from SharedPreferences
  static Map<String, dynamic> _extractItemOverridesFromPrefs(SharedPreferences prefs) {
    final result = <String, dynamic>{};
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.contains('_items_')) {
        final value = prefs.getString(key);
        if (value != null) {
          try {
            result[key] = jsonDecode(value);
          } catch (_) {}
        }
      }
    }

    return result;
  }

  /// Extract all item amount override data from SharedPreferences
  static Map<String, dynamic> _extractItemAmountOverridesFromPrefs(SharedPreferences prefs) {
    final result = <String, dynamic>{};
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.contains('_item_amounts_')) {
        final value = prefs.getString(key);
        if (value != null) {
          try {
            result[key] = jsonDecode(value);
          } catch (_) {}
        }
      }
    }

    return result;
  }

  /// Auto backup settings
  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupEnabledKey) ?? false;
  }

  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupEnabledKey, enabled);
  }

  static Future<String?> getAutoBackupPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_autoBackupPathKey);
  }

  static Future<void> setAutoBackupPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString(_autoBackupPathKey, path);
    } else {
      await prefs.remove(_autoBackupPathKey);
    }
  }

  static Future<DateTime?> getLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_lastBackupDateKey);
    return dateStr != null ? DateTime.parse(dateStr) : null;
  }

  static Future<String> getAutoBackupFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_autoBackupFrequencyKey) ?? 'daily';
  }

  static Future<void> setAutoBackupFrequency(String frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_autoBackupFrequencyKey, frequency);
  }

  /// Check if auto backup should run based on frequency
  static Future<bool> shouldRunAutoBackup() async {
    final enabled = await isAutoBackupEnabled();
    if (!enabled) return false;

    final lastBackup = await getLastBackupDate();
    if (lastBackup == null) return true;

    final frequency = await getAutoBackupFrequency();
    final now = DateTime.now();

    switch (frequency) {
      case 'daily':
        return now.difference(lastBackup).inHours >= 24;
      case 'weekly':
        return now.difference(lastBackup).inDays >= 7;
      case 'monthly':
        return now.difference(lastBackup).inDays >= 30;
      default:
        return false;
    }
  }

  /// Perform auto backup
  static Future<void> performAutoBackup() async {
    try {
      final path = await getAutoBackupPath();
      if (path == null) return;

      // Create backup file with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'sugo_auto_backup_$timestamp.json';
      final directory = Directory(path);

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final filePath = '$path${Platform.pathSeparator}$fileName';
      await exportBackup(customPath: filePath);

      // Clean up old backups (keep last 10)
      await _cleanupOldBackups(path);
    } catch (e) {
      // Silently fail auto backup to not disrupt user experience
      // Log error for debugging purposes
      rethrow;
    }
  }

  /// Clean up old backup files, keeping only the most recent ones
  static Future<void> _cleanupOldBackups(String directoryPath, {int keepCount = 10}) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) return;

      final files = await directory
          .list()
          .where((entity) => entity is File && entity.path.contains('sugo_auto_backup_'))
          .cast<File>()
          .toList();

      if (files.length <= keepCount) return;

      // Sort by modification date (newest first)
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // Delete old backups
      for (int i = keepCount; i < files.length; i++) {
        await files[i].delete();
      }
    } catch (e) {
      // Failed to clean up old backups, ignore error
    }
  }

  /// Select directory for auto backup
  static Future<String?> selectBackupDirectory() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Auto Backup Folder',
      );
      return result;
    } catch (e) {
      // Failed to select directory
      return null;
    }
  }
}
