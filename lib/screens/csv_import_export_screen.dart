import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/appointment_reminder.dart';
import '../models/nz_sms_recipient.dart';
import '../models/send_log_entry.dart';
import '../services/appointment_reminder_store.dart';
import '../services/csv_import_export_service.dart';
import '../services/nz_recipient_store.dart';
import '../services/send_log_store.dart';

class CsvImportExportScreen extends StatefulWidget {
  const CsvImportExportScreen({super.key});

  @override
  State<CsvImportExportScreen> createState() => _CsvImportExportScreenState();
}

class _CsvImportExportScreenState extends State<CsvImportExportScreen> {
  final CsvImportExportService _csvService = CsvImportExportService();
  final NzRecipientStore _recipientStore = NzRecipientStore();
  final AppointmentReminderStore _reminderStore = AppointmentReminderStore();
  final SendLogStore _logStore = SendLogStore();

  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];
  List<AppointmentReminder> _reminders = <AppointmentReminder>[];
  List<SendLogEntry> _logs = <SendLogEntry>[];

  bool _loading = true;
  bool _busy = false;
  bool _mergeImports = true;

  String _status = 'CSV tools ready.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contacts = await _recipientStore.loadRecipients();
    final reminders = await _reminderStore.loadReminders();
    final logs = await _logStore.loadLogs();

    if (!mounted) {
      return;
    }

    setState(() {
      _contacts = contacts;
      _reminders = reminders;
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _exportContacts() async {
    await _runExport(
      label: 'Contacts CSV copied to clipboard.',
      action: _csvService.copyContactsCsvToClipboard,
    );
  }

  Future<void> _exportReminders() async {
    await _runExport(
      label: 'Reminders CSV copied to clipboard.',
      action: _csvService.copyRemindersCsvToClipboard,
    );
  }

  Future<void> _exportLogs() async {
    await _runExport(
      label: 'Send logs CSV copied to clipboard.',
      action: _csvService.copyLogsCsvToClipboard,
    );
  }

  Future<void> _runExport({
    required String label,
    required Future<void> Function() action,
  }) async {
    setState(() {
      _busy = true;
      _status = 'Exporting CSV...';
    });

    try {
      await action();

      if (!mounted) {
        return;
      }

      setState(() => _status = label);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(label),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _status = 'CSV export failed: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _importContactsFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    await _importContacts(data?.text ?? '');
  }

  Future<void> _importRemindersFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    await _importReminders(data?.text ?? '');
  }

  Future<void> _pasteContactsCsv() async {
    final csv = await _showPasteSheet(
      title: 'Paste contacts CSV',
      hint:
          'id,name,number,consented,isTestNumber,note\n1,Test,+64211234567,true,true,My test number',
    );

    if (csv == null) {
      return;
    }

    await _importContacts(csv);
  }

  Future<void> _pasteRemindersCsv() async {
    final csv = await _showPasteSheet(
      title: 'Paste reminders CSV',
      hint:
          'id,contactId,phoneNumber,appointmentTitle,location,message,scheduledAt,isSent,recurrenceRule,templateName,notes\n1,contact-1,+64211234567,Appointment,Clinic,Reminder text,2026-01-01T09:00:00,false,once,CSV Import,Imported',
    );

    if (csv == null) {
      return;
    }

    await _importReminders(csv);
  }

  Future<String?> _showPasteSheet({
    required String title,
    required String hint,
  }) {
    final controller = TextEditingController();

    return showModalBottomSheet<String>(
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 12,
                    decoration: InputDecoration(
                      labelText: 'CSV text',
                      hintText: hint,
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
                    onPressed: () => Navigator.of(context).pop(controller.text),
                    icon: const Icon(CupertinoIcons.arrow_down_doc_fill),
                    label: const Text('Import CSV'),
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
  }

  Future<void> _importContacts(String csv) async {
    if (csv.trim().isEmpty) {
      setState(() => _status = 'Contacts CSV is empty.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Importing contacts CSV...';
    });

    try {
      final result = await _csvService.importContactsCsv(
        csv,
        merge: _mergeImports,
      );

      await _load();

      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            'Contacts import complete. Imported: ${result.imported}. Skipped: ${result.skipped}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _status = 'Contacts import failed: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _importReminders(String csv) async {
    if (csv.trim().isEmpty) {
      setState(() => _status = 'Reminders CSV is empty.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Importing reminders CSV...';
    });

    try {
      final result = await _csvService.importRemindersCsv(
        csv,
        merge: _mergeImports,
      );

      await _load();

      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            'Reminders import complete. Imported: ${result.imported}. Skipped: ${result.skipped}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _status = 'Reminders import failed: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copyContactsSample() async {
    await Clipboard.setData(
      const ClipboardData(
        text:
            'id,name,number,consented,isTestNumber,note\ncontact-1,My Test,+64211234567,true,true,Test number',
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() => _status = 'Contacts CSV sample copied.');
  }

  Future<void> _copyRemindersSample() async {
    await Clipboard.setData(
      const ClipboardData(
        text:
            'id,contactId,phoneNumber,appointmentTitle,location,message,scheduledAt,isSent,recurrenceRule,templateName,notes\nreminder-1,contact-1,+64211234567,Appointment,Clinic,Hi reminder text,2026-01-01T09:00:00,false,once,CSV Import,Imported appointment',
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() => _status = 'Reminders CSV sample copied.');
  }

  @override
  Widget build(BuildContext context) {
    final pending = _reminders.where((item) => !item.isSent).length;
    final sentLogs = _logs.where((item) => item.status == 'sent').length;
    final failedLogs = _logs.where((item) => item.status == 'failed').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('CSV Import / Export'),
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
                _CsvHero(
                  contacts: _contacts.length,
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
                _SurfaceCard(
                  child: SwitchListTile(
                    value: _mergeImports,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Merge imports',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: const Text(
                      'On: update/add rows by ID. Off: replace that dataset.',
                    ),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _mergeImports = value),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Export',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _ActionGrid(
                  left: _ActionButton(
                    icon: CupertinoIcons.person_2_fill,
                    label: 'Export contacts',
                    onPressed: _busy ? null : _exportContacts,
                  ),
                  right: _ActionButton(
                    icon: CupertinoIcons.calendar,
                    label: 'Export reminders',
                    onPressed: _busy ? null : _exportReminders,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _exportLogs,
                  icon: const Icon(CupertinoIcons.doc_text_search),
                  label: const Text('Export send logs'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Import',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _ActionGrid(
                  left: _ActionButton(
                    icon: CupertinoIcons.doc_on_clipboard,
                    label: 'Contacts clipboard',
                    onPressed: _busy ? null : _importContactsFromClipboard,
                  ),
                  right: _ActionButton(
                    icon: CupertinoIcons.text_badge_plus,
                    label: 'Paste contacts',
                    onPressed: _busy ? null : _pasteContactsCsv,
                  ),
                ),
                const SizedBox(height: 12),
                _ActionGrid(
                  left: _ActionButton(
                    icon: CupertinoIcons.doc_on_clipboard,
                    label: 'Reminders clipboard',
                    onPressed: _busy ? null : _importRemindersFromClipboard,
                  ),
                  right: _ActionButton(
                    icon: CupertinoIcons.text_badge_plus,
                    label: 'Paste reminders',
                    onPressed: _busy ? null : _pasteRemindersCsv,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Samples',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _ActionGrid(
                  left: _ActionButton(
                    icon: CupertinoIcons.doc_plaintext,
                    label: 'Contacts sample',
                    onPressed: _copyContactsSample,
                  ),
                  right: _ActionButton(
                    icon: CupertinoIcons.doc_plaintext,
                    label: 'Reminders sample',
                    onPressed: _copyRemindersSample,
                  ),
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
                  contacts: _contacts.length,
                  reminders: _reminders.length,
                  pending: pending,
                  logs: _logs.length,
                  sentLogs: sentLogs,
                  failedLogs: failedLogs,
                ),
                const SizedBox(height: 12),
                const _SurfaceCard(
                  child: Text(
                    'CSV exports are plain text. Keep them private because they may include phone numbers, messages, appointment times, and send logs.',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CsvHero extends StatelessWidget {
  const _CsvHero({
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
            Icons.table_chart_outlined,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'CSV import/export',
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
            'Move contacts, reminders, appointments, and logs through spreadsheet-friendly CSV.',
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

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.left,
    required this.right,
  });

  final _ActionButton left;
  final _ActionButton right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
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
    required this.sentLogs,
    required this.failedLogs,
  });

  final int contacts;
  final int reminders;
  final int pending;
  final int logs;
  final int sentLogs;
  final int failedLogs;

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
            _MetricCard(value: '$sentLogs', label: 'Sent logs'),
            const SizedBox(width: 12),
            _MetricCard(value: '$failedLogs', label: 'Failed logs'),
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
