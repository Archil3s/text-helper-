import 'package:flutter/services.dart';

import '../models/appointment_reminder.dart';
import '../models/nz_sms_recipient.dart';
import '../models/send_log_entry.dart';
import 'appointment_reminder_store.dart';
import 'nz_recipient_store.dart';
import 'send_log_store.dart';

class CsvImportResult {
  const CsvImportResult({
    required this.imported,
    required this.skipped,
  });

  final int imported;
  final int skipped;
}

class CsvImportExportService {
  CsvImportExportService({
    NzRecipientStore? recipientStore,
    AppointmentReminderStore? reminderStore,
    SendLogStore? logStore,
  })  : _recipientStore = recipientStore ?? NzRecipientStore(),
        _reminderStore = reminderStore ?? AppointmentReminderStore(),
        _logStore = logStore ?? SendLogStore();

  final NzRecipientStore _recipientStore;
  final AppointmentReminderStore _reminderStore;
  final SendLogStore _logStore;

  Future<String> exportContactsCsv() async {
    final recipients = await _recipientStore.loadRecipients();

    return _encode([
      [
        'id',
        'name',
        'number',
        'consented',
        'isTestNumber',
        'note',
      ],
      ...recipients.map(
        (item) => [
          item.id,
          item.name,
          item.number,
          item.consented.toString(),
          item.isTestNumber.toString(),
          item.note ?? '',
        ],
      ),
    ]);
  }

  Future<String> exportRemindersCsv() async {
    final reminders = await _reminderStore.loadReminders();

    return _encode([
      [
        'id',
        'contactId',
        'phoneNumber',
        'appointmentTitle',
        'location',
        'message',
        'scheduledAt',
        'isSent',
        'recurrenceRule',
        'templateName',
        'sentAt',
        'notes',
      ],
      ...reminders.map(
        (item) => [
          item.id,
          item.contactId,
          item.phoneNumber,
          item.appointmentTitle,
          item.location,
          item.message,
          item.scheduledAt.toIso8601String(),
          item.isSent.toString(),
          item.recurrenceRule,
          item.templateName,
          item.sentAt?.toIso8601String() ?? '',
          item.notes ?? '',
        ],
      ),
    ]);
  }

  Future<String> exportLogsCsv() async {
    final logs = await _logStore.loadLogs();

    return _encode([
      [
        'id',
        'phoneNumber',
        'message',
        'createdAt',
        'status',
        'errorMessage',
        'reminderId',
      ],
      ...logs.map(
        (item) => [
          item.id,
          item.phoneNumber,
          item.message,
          item.createdAt.toIso8601String(),
          item.status,
          item.errorMessage ?? '',
          item.reminderId ?? '',
        ],
      ),
    ]);
  }

  Future<void> copyContactsCsvToClipboard() async {
    await Clipboard.setData(ClipboardData(text: await exportContactsCsv()));
  }

  Future<void> copyRemindersCsvToClipboard() async {
    await Clipboard.setData(ClipboardData(text: await exportRemindersCsv()));
  }

  Future<void> copyLogsCsvToClipboard() async {
    await Clipboard.setData(ClipboardData(text: await exportLogsCsv()));
  }

  Future<CsvImportResult> importContactsCsv(
    String rawCsv, {
    required bool merge,
  }) async {
    final rows = _parse(rawCsv);

    if (rows.length < 2) {
      throw const FormatException('Contacts CSV needs a header row and data.');
    }

    final headers = rows.first;
    final imported = <NzSmsRecipient>[];
    var skipped = 0;

    for (final row in rows.skip(1)) {
      if (row.every((cell) => cell.trim().isEmpty)) {
        continue;
      }

      final map = _rowMap(headers, row);
      final number =
          _first(map, ['number', 'phonenumber', 'phone', 'mobile']).trim();

      if (number.isEmpty) {
        skipped += 1;
        continue;
      }

      final id = _first(map, ['id']).trim().isEmpty
          ? 'contact-${DateTime.now().microsecondsSinceEpoch}-${imported.length}'
          : _first(map, ['id']).trim();

      imported.add(
        NzSmsRecipient(
          id: id,
          name: _first(map, ['name']).trim().isEmpty
              ? number
              : _first(map, ['name']).trim(),
          number: number,
          consented: _parseBool(_first(map, ['consented', 'consent']), true),
          isTestNumber:
              _parseBool(_first(map, ['istestnumber', 'testnumber']), false),
          note: _first(map, ['note', 'notes']).trim().isEmpty
              ? null
              : _first(map, ['note', 'notes']).trim(),
        ),
      );
    }

    if (merge) {
      final existing = await _recipientStore.loadRecipients();
      final merged = <String, NzSmsRecipient>{};

      for (final item in existing) {
        merged[item.id] = item;
      }

      for (final item in imported) {
        merged[item.id] = item;
      }

      await _recipientStore.saveRecipients(merged.values.toList());
    } else {
      await _recipientStore.saveRecipients(imported);
    }

    return CsvImportResult(imported: imported.length, skipped: skipped);
  }

  Future<CsvImportResult> importRemindersCsv(
    String rawCsv, {
    required bool merge,
  }) async {
    final rows = _parse(rawCsv);

    if (rows.length < 2) {
      throw const FormatException('Reminders CSV needs a header row and data.');
    }

    final headers = rows.first;
    final imported = <AppointmentReminder>[];
    var skipped = 0;

    for (final row in rows.skip(1)) {
      if (row.every((cell) => cell.trim().isEmpty)) {
        continue;
      }

      final map = _rowMap(headers, row);
      final phoneNumber =
          _first(map, ['phonenumber', 'number', 'phone', 'mobile']).trim();
      final message = _first(map, ['message', 'text']).trim();
      final scheduledAtRaw =
          _first(map, ['scheduledat', 'date', 'datetime', 'time']).trim();
      final scheduledAt = DateTime.tryParse(scheduledAtRaw);

      if (phoneNumber.isEmpty || message.isEmpty || scheduledAt == null) {
        skipped += 1;
        continue;
      }

      final id = _first(map, ['id']).trim().isEmpty
          ? 'reminder-${DateTime.now().microsecondsSinceEpoch}-${imported.length}'
          : _first(map, ['id']).trim();

      imported.add(
        AppointmentReminder(
          id: id,
          contactId: _first(map, ['contactid']).trim(),
          phoneNumber: phoneNumber,
          appointmentTitle:
              _first(map, ['appointmenttitle', 'appointment', 'title'])
                      .trim()
                      .isEmpty
                  ? 'Imported appointment'
                  : _first(
                      map,
                      ['appointmenttitle', 'appointment', 'title'],
                    ).trim(),
          location: _first(map, ['location']).trim(),
          message: message,
          scheduledAt: scheduledAt,
          isSent: _parseBool(_first(map, ['issent']), false),
          recurrenceRule:
              _first(map, ['recurrencerule', 'repeat']).trim().isEmpty
                  ? 'once'
                  : _first(map, ['recurrencerule', 'repeat']).trim(),
          templateName: _first(map, ['templatename', 'template']).trim().isEmpty
              ? 'CSV Import'
              : _first(map, ['templatename', 'template']).trim(),
          sentAt: DateTime.tryParse(_first(map, ['sentat']).trim()),
          notes: _first(map, ['notes', 'note']).trim().isEmpty
              ? 'Imported from CSV'
              : _first(map, ['notes', 'note']).trim(),
        ),
      );
    }

    if (merge) {
      final existing = await _reminderStore.loadReminders();
      final merged = <String, AppointmentReminder>{};

      for (final item in existing) {
        merged[item.id] = item;
      }

      for (final item in imported) {
        merged[item.id] = item;
      }

      await _reminderStore.saveReminders(merged.values.toList());
    } else {
      await _reminderStore.saveReminders(imported);
    }

    return CsvImportResult(imported: imported.length, skipped: skipped);
  }

  String _encode(List<List<String>> rows) {
    return rows.map((row) => row.map(_escape).join(',')).join('\n');
  }

  String _escape(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n');

    final escaped = value.replaceAll('"', '""');

    return needsQuotes ? '"$escaped"' : escaped;
  }

  List<List<String>> _parse(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < input.length; index++) {
      final char = input[index];

      if (char == '"') {
        final nextIsQuote = index + 1 < input.length && input[index + 1] == '"';

        if (inQuotes && nextIsQuote) {
          field.write('"');
          index += 1;
        } else {
          inQuotes = !inQuotes;
        }

        continue;
      }

      if (char == ',' && !inQuotes) {
        row.add(field.toString());
        field.clear();
        continue;
      }

      if (char == '\n' && !inQuotes) {
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
        continue;
      }

      if (char == '\r') {
        continue;
      }

      field.write(char);
    }

    row.add(field.toString());

    if (row.any((cell) => cell.trim().isNotEmpty)) {
      rows.add(row);
    }

    return rows;
  }

  Map<String, String> _rowMap(List<String> headers, List<String> row) {
    final map = <String, String>{};

    for (var index = 0; index < headers.length; index++) {
      final key = _normalize(headers[index]);
      final value = index < row.length ? row[index] : '';
      map[key] = value;
    }

    return map;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _first(Map<String, String> map, List<String> keys) {
    for (final key in keys) {
      final value = map[_normalize(key)];

      if (value != null) {
        return value;
      }
    }

    return '';
  }

  bool _parseBool(String value, bool fallback) {
    final normalized = value.trim().toLowerCase();

    if (normalized.isEmpty) {
      return fallback;
    }

    return normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'y' ||
        normalized == '1';
  }
}
