import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/appointment_reminder.dart';
import '../models/nz_sms_recipient.dart';
import '../models/send_log_entry.dart';
import '../services/appointment_reminder_store.dart';
import '../services/backup_restore_service.dart';
import '../services/nz_recipient_store.dart';
import '../services/send_log_store.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupRestoreService _backupService = BackupRestoreService();
  final NzRecipientStore _recipientStore = NzRecipientStore();
  final AppointmentReminderStore _reminderStore = AppointmentReminderStore();
  final SendLogStore _logStore = SendLogStore();

  List<NzSmsRecipient> _recipients = <NzSmsRecipient>[];
  List<AppointmentReminder> _reminders = <AppointmentReminder>[];
  List<SendLogEntry> _logs = <SendLogEntry>[];

  bool _loading = true;
  bool _busy = false;
  bool _includeLogsOnRestore = true;

  String _status = 'Backup tools ready.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recipients = await _recipientStore.loadRecipients();
    final reminders = await _reminderStore.loadReminders();
    final logs = await _logStore.loadLogs();

    if (!mounted) {
      return;
    }

    setState(() {
      _recipients = recipients;
      _reminders = reminders;
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _exportBackup() async {
    setState(() {
      _busy = true;
      _status = 'Creating backup...';
    });

    try {
      await _backupService.copyBackupToClipboard();

      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            'Backup copied to clipboard. Save it somewhere safe before changing phones or reinstalling.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup JSON copied to clipboard.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _status = 'Backup export failed: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copyPreview() async {
    final backup = await _backupService.buildBackupJson();
    await Clipboard.setData(ClipboardData(text: backup));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Current backup copied to clipboard.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _restoreFromClipboard() async {
    await _confirmRestore(
      title: 'Restore from clipboard?',
      body:
          'This will replace current contacts, reminders, and optionally send logs with the backup JSON currently copied to your clipboard.',
      onConfirm: () async {
        final result = await _backupService.restoreFromClipboard(
          includeLogs: _includeLogsOnRestore,
        );

        return result;
      },
    );
  }

  Future<void> _showPasteRestoreSheet() async {
    final controller = TextEditingController();

    final rawJson = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF2F2F7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey3,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Paste backup JSON',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Paste a Text Helper backup JSON export below. Restore will validate the backup version before replacing data.',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: 'Backup JSON',
                      filled: true,
                      fillColor: Colors.white,
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(controller.text);
                    },
                    icon: const Icon(CupertinoIcons.arrow_down_doc_fill),
                    label: const Text('Validate and restore'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (rawJson == null || rawJson.trim().isEmpty) {
      return;
    }

    await _confirmRestore(
      title: 'Restore pasted backup?',
      body:
          'This will replace current contacts, reminders, and optionally send logs with the pasted backup.',
      onConfirm: () {
        return _backupService.restoreFromJson(
          rawJson,
          includeLogs: _includeLogsOnRestore,
        );
      },
    );
  }

  Future<void> _confirmRestore({
    required String title,
    required String body,
    required Future<BackupRestoreResult> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Restoring backup...';
    });

    try {
      final result = await onConfirm();
      await _load();

      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            'Restore complete. Contacts: ${result.recipientsRestored}. Reminders: ${result.remindersRestored}. Logs: ${result.logsRestored}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _status = 'Restore failed: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _reminders.where((item) => !item.isSent).length;
    final sent = _logs.where((item) => item.status == 'sent').length;
    final failed = _logs.where((item) => item.status == 'failed').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _BackupHero(
                  contacts: _recipients.length,
                  reminders: _reminders.length,
                  logs: _logs.length,
                ),
                const SizedBox(height: 20),
                _SurfaceCard(
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.info_circle_fill,
                        color: Color(0xFF0A84FF),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _status,
                          style: const TextStyle(
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _exportBackup,
                  icon: const Icon(CupertinoIcons.doc_on_clipboard),
                  label: const Text('Export backup to clipboard'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _copyPreview,
                  icon: const Icon(CupertinoIcons.eye),
                  label: const Text('Copy backup JSON'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Restore',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: SwitchListTile(
                    value: _includeLogsOnRestore,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Restore send logs',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: const Text(
                      'Turn off to restore contacts and reminders only.',
                    ),
                    onChanged: _busy
                        ? null
                        : (value) {
                            setState(() => _includeLogsOnRestore = value);
                          },
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _restoreFromClipboard,
                        icon: const Icon(CupertinoIcons.doc_on_clipboard),
                        label: const Text('From clipboard'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _showPasteRestoreSheet,
                        icon: const Icon(CupertinoIcons.text_badge_plus),
                        label: const Text('Paste JSON'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Current data',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _MetricGrid(
                  contacts: _recipients.length,
                  reminders: _reminders.length,
                  pending: pending,
                  logs: _logs.length,
                  sent: sent,
                  failed: failed,
                ),
                const SizedBox(height: 12),
                const _SurfaceCard(
                  child: Text(
                    'Backups are local JSON text. Keep backups private because they include phone numbers, messages, reminder times, and send logs. Contact names are stored only in contacts.',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _BackupHero extends StatelessWidget {
  const _BackupHero({
    required this.contacts,
    required this.reminders,
    required this.logs,
  });

  final int contacts;
  final int reminders;
  final int logs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF111827),
            Color(0xFF1D4ED8),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.archivebox_fill,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'Backup & restore',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Protect contacts, reminders, queue data, and send history.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(value: '$contacts', label: 'contacts'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$reminders', label: 'reminders'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$logs', label: 'logs'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.contacts,
    required this.reminders,
    required this.pending,
    required this.logs,
    required this.sent,
    required this.failed,
  });

  final int contacts;
  final int reminders;
  final int pending;
  final int logs;
  final int sent;
  final int failed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _MetricCard(value: '$contacts', label: 'Contacts'),
            const SizedBox(width: 12),
            _MetricCard(value: '$reminders', label: 'Reminders'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _MetricCard(value: '$pending', label: 'Pending'),
            const SizedBox(width: 12),
            _MetricCard(value: '$logs', label: 'Logs'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _MetricCard(value: '$sent', label: 'Sent logs'),
            const SizedBox(width: 12),
            _MetricCard(value: '$failed', label: 'Failed logs'),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _SurfaceCard(
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.borderColor,
  });

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
