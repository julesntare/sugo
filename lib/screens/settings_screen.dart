import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/backup_service.dart';
import '../widgets/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoBackupEnabled = false;
  String? _autoBackupPath;
  DateTime? _lastBackupDate;
  String _autoBackupFrequency = 'daily';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await BackupService.isAutoBackupEnabled();
    final path = await BackupService.getAutoBackupPath();
    final lastBackup = await BackupService.getLastBackupDate();
    final frequency = await BackupService.getAutoBackupFrequency();

    setState(() {
      _autoBackupEnabled = enabled;
      _autoBackupPath = path;
      _lastBackupDate = lastBackup;
      _autoBackupFrequency = frequency;
      _isLoading = false;
    });
  }

  Future<void> _toggleAutoBackup(bool value) async {
    if (value && _autoBackupPath == null) {
      await _selectBackupLocation();
      if (_autoBackupPath == null) return;
    }

    await BackupService.setAutoBackupEnabled(value);
    setState(() {
      _autoBackupEnabled = value;
    });

    if (value) {
      await _performAutoBackupNow();
    }
  }

  Future<void> _selectBackupLocation() async {
    final path = await BackupService.selectBackupDirectory();
    if (path != null) {
      await BackupService.setAutoBackupPath(path);
      setState(() {
        _autoBackupPath = path;
      });
    }
  }

  Future<void> _changeAutoBackupFrequency(String? frequency) async {
    if (frequency == null) return;
    await BackupService.setAutoBackupFrequency(frequency);
    setState(() {
      _autoBackupFrequency = frequency;
    });
  }

  Future<void> _performAutoBackupNow() async {
    try {
      await BackupService.performAutoBackup();
      final lastBackup = await BackupService.getLastBackupDate();
      setState(() {
        _lastBackupDate = lastBackup;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto backup completed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto backup failed: $e')),
        );
      }
    }
  }

  Future<void> _exportBackup() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final filePath = await BackupService.exportBackup();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        if (filePath != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backup exported to:\n$filePath')),
          );
          await _loadSettings();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup export cancelled')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Backup'),
        content: const Text(
          'This will replace all current data with the backup data. This action cannot be undone.\n\nAre you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final success = await BackupService.importBackup();

      if (mounted) {
        Navigator.of(context).pop();

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup imported successfully! Please restart the app.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import cancelled')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle('Backup & Restore'),
                const SizedBox(height: 8),
                _buildBackupRestoreCard(),
                const SizedBox(height: 24),
                _buildSectionTitle('Auto Backup'),
                const SizedBox(height: 8),
                _buildAutoBackupCard(),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBackupRestoreCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manual Backup',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (_lastBackupDate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Last backup: ${DateFormat('MMM dd, yyyy hh:mm a').format(_lastBackupDate!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportBackup,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Export Backup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _importBackup,
                    icon: const Icon(Icons.download),
                    label: const Text('Import Backup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Export creates a backup file you can save anywhere. Import restores data from a backup file.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoBackupCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text(
                'Enable Auto Backup',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Automatically backup your data'),
              value: _autoBackupEnabled,
              onChanged: _toggleAutoBackup,
              contentPadding: EdgeInsets.zero,
            ),
            if (_autoBackupEnabled) ...[
              const Divider(),
              const SizedBox(height: 8),
              ListTile(
              title: const Text('Backup Frequency'),
              subtitle: Text(_autoBackupFrequency.toUpperCase()),
              trailing: DropdownButton<String>(
                value: _autoBackupFrequency,
                onChanged: _changeAutoBackupFrequency,
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
              ),
              contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              ListTile(
              title: const Text('Backup Location'),
              subtitle: Text(
                _autoBackupPath ?? 'Not set',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.folder_open),
                onPressed: _selectBackupLocation,
              ),
              contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _performAutoBackupNow,
                icon: const Icon(Icons.backup),
                label: const Text('Backup Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                ),
              ),
              ),
              const SizedBox(height: 8),
              Text(
                'Backups are saved to the selected folder. Old backups are automatically cleaned up (last 10 kept).',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
