import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/appointment_reminder.dart';
import '../models/nz_sms_recipient.dart';
import '../models/send_log_entry.dart';
import 'appointment_reminder_store.dart';
import 'nz_recipient_store.dart';
import 'send_log_store.dart';

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.recipientsRestored,
    required this.remindersRestored,
    required this.logsRestored,
  });

  final int recipientsRestored;
  final int remindersRestored;
  final int logsRestored;
}

class BackupRestoreService {
  BackupRestoreService({
    AppointmentReminderStore? reminderStore,
    NzRecipientStore? recipientStore,
    SendLogStore? logStore,
  })  : _reminderStore = reminderStore ?? AppointmentReminderStore(),
        _recipientStore = recipientStore ?? NzRecipientStore(),
        _logStore = logStore ?? SendLogStore();

  final AppointmentReminderStore _reminderStore;
  final NzRecipientStore _recipientStore;
  final SendLogStore _logStore;

  Future<String> buildBackupJson() async {
    final reminders = await _reminderStore.loadReminders();
    final recipients = await _recipientStore.loadRecipients();
    final logs = await _logStore.loadLogs();

    final data = {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'recipients': recipients.map((item) => item.toJson()).toList(),
      'reminders': reminders.map((item) => item.toJson()).toList(),
      'sendLogs': logs.map((item) => item.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> copyBackupToClipboard() async {
    final json = await buildBackupJson();
    await Clipboard.setData(ClipboardData(text: json));
  }

  Future<BackupRestoreResult> restoreFromJson(
    String rawJson, {
    bool includeLogs = true,
  }) async {
    final decoded = jsonDecode(rawJson);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup root must be a JSON object.');
    }

    final version = decoded['version'];

    if (version != 1) {
      throw FormatException('Unsupported backup version: $version');
    }

    final rawRecipients = decoded['recipients'];
    final rawReminders = decoded['reminders'];
    final rawLogs = decoded['sendLogs'];

    if (rawRecipients is! List) {
      throw const FormatException('Backup is missing recipients list.');
    }

    if (rawReminders is! List) {
      throw const FormatException('Backup is missing reminders list.');
    }

    final recipients = rawRecipients
        .whereType<Map>()
        .map((item) => NzSmsRecipient.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.id.isNotEmpty && item.number.isNotEmpty)
        .toList();

    final reminders = rawReminders
        .whereType<Map>()
        .map(
          (item) =>
              AppointmentReminder.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.id.isNotEmpty && item.phoneNumber.isNotEmpty)
        .toList();

    final logs = includeLogs && rawLogs is List
        ? rawLogs
            .whereType<Map>()
            .map(
              (item) => SendLogEntry.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((item) => item.id.isNotEmpty)
            .toList()
        : <SendLogEntry>[];

    await _recipientStore.saveRecipients(recipients);
    await _reminderStore.saveReminders(reminders);

    if (includeLogs) {
      await _logStore.saveLogs(logs);
    }

    return BackupRestoreResult(
      recipientsRestored: recipients.length,
      remindersRestored: reminders.length,
      logsRestored: includeLogs ? logs.length : 0,
    );
  }

  Future<BackupRestoreResult> restoreFromClipboard({
    bool includeLogs = true,
  }) async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';

    if (text.trim().isEmpty) {
      throw const FormatException('Clipboard is empty.');
    }

    return restoreFromJson(text, includeLogs: includeLogs);
  }
}
