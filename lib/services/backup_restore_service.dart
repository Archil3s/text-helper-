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
    this.recipientsSkippedDuplicate = 0,
    this.remindersSkippedDuplicate = 0,
    this.logsSkippedDuplicate = 0,
    this.rejectedItems = 0,
    this.schemaVersion = BackupRestoreService.currentSchemaVersion,
  });

  final int recipientsRestored;
  final int remindersRestored;
  final int logsRestored;
  final int recipientsSkippedDuplicate;
  final int remindersSkippedDuplicate;
  final int logsSkippedDuplicate;
  final int rejectedItems;
  final int schemaVersion;

  int get totalRestored {
    return recipientsRestored + remindersRestored + logsRestored;
  }

  int get totalSkippedDuplicates {
    return recipientsSkippedDuplicate +
        remindersSkippedDuplicate +
        logsSkippedDuplicate;
  }
}

class BackupRestoreService {
  BackupRestoreService({
    AppointmentReminderStore? reminderStore,
    NzRecipientStore? recipientStore,
    SendLogStore? logStore,
  })  : _reminderStore = reminderStore ?? AppointmentReminderStore(),
        _recipientStore = recipientStore ?? NzRecipientStore(),
        _logStore = logStore ?? SendLogStore();

  static const int currentSchemaVersion = 2;
  static const int oldestSupportedSchemaVersion = 1;

  final AppointmentReminderStore _reminderStore;
  final NzRecipientStore _recipientStore;
  final SendLogStore _logStore;

  Future<String> buildBackupJson() async {
    final reminders = await _reminderStore.loadReminders();
    final recipients = await _recipientStore.loadRecipients();
    final logs = await _logStore.loadLogs();

    final data = {
      'version': currentSchemaVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'schema': {
        'name': 'text_helper_backup',
        'minimumSupportedVersion': oldestSupportedSchemaVersion,
        'currentVersion': currentSchemaVersion,
      },
      'counts': {
        'recipients': recipients.length,
        'reminders': reminders.length,
        'sendLogs': logs.length,
      },
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

    if (version is! int) {
      throw const FormatException('Backup version must be a number.');
    }

    if (version < oldestSupportedSchemaVersion ||
        version > currentSchemaVersion) {
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

    if (includeLogs && rawLogs != null && rawLogs is! List) {
      throw const FormatException('Backup sendLogs must be a list.');
    }

    final existingRecipients = await _recipientStore.loadRecipients();
    final existingReminders = await _reminderStore.loadReminders();
    final existingLogs = await _logStore.loadLogs();

    final recipientIds = existingRecipients.map((item) => item.id).toSet();
    final reminderIds = existingReminders.map((item) => item.id).toSet();
    final logIds = existingLogs.map((item) => item.id).toSet();

    final importedRecipients = <NzSmsRecipient>[];
    final importedReminders = <AppointmentReminder>[];
    final importedLogs = <SendLogEntry>[];

    var duplicateRecipients = 0;
    var duplicateReminders = 0;
    var duplicateLogs = 0;
    var rejected = 0;

    for (final rawItem in rawRecipients) {
      if (rawItem is! Map) {
        rejected += 1;
        continue;
      }

      try {
        final item = NzSmsRecipient.fromJson(
          Map<String, dynamic>.from(rawItem),
        );

        if (item.id.trim().isEmpty || item.number.trim().isEmpty) {
          rejected += 1;
          continue;
        }

        if (recipientIds.contains(item.id)) {
          duplicateRecipients += 1;
          continue;
        }

        recipientIds.add(item.id);
        importedRecipients.add(item);
      } catch (_) {
        rejected += 1;
      }
    }

    for (final rawItem in rawReminders) {
      if (rawItem is! Map) {
        rejected += 1;
        continue;
      }

      try {
        final map = Map<String, dynamic>.from(rawItem);
        final scheduledAt = DateTime.tryParse(
          map['scheduledAt'] as String? ?? '',
        );

        final item = AppointmentReminder.fromJson(map);

        if (item.id.trim().isEmpty ||
            item.phoneNumber.trim().isEmpty ||
            item.message.trim().isEmpty ||
            scheduledAt == null) {
          rejected += 1;
          continue;
        }

        if (reminderIds.contains(item.id)) {
          duplicateReminders += 1;
          continue;
        }

        reminderIds.add(item.id);
        importedReminders.add(item);
      } catch (_) {
        rejected += 1;
      }
    }

    if (includeLogs && rawLogs is List) {
      for (final rawItem in rawLogs) {
        if (rawItem is! Map) {
          rejected += 1;
          continue;
        }

        try {
          final map = Map<String, dynamic>.from(rawItem);
          final createdAt = DateTime.tryParse(
            map['createdAt'] as String? ?? '',
          );

          final item = SendLogEntry.fromJson(map);

          if (item.id.trim().isEmpty ||
              item.phoneNumber.trim().isEmpty ||
              item.message.trim().isEmpty ||
              createdAt == null) {
            rejected += 1;
            continue;
          }

          if (logIds.contains(item.id)) {
            duplicateLogs += 1;
            continue;
          }

          logIds.add(item.id);
          importedLogs.add(item);
        } catch (_) {
          rejected += 1;
        }
      }
    }

    await _recipientStore.saveRecipients([
      ...importedRecipients,
      ...existingRecipients,
    ]);

    await _reminderStore.saveReminders([
      ...importedReminders,
      ...existingReminders,
    ]);

    if (includeLogs) {
      await _logStore.saveLogs([
        ...importedLogs,
        ...existingLogs,
      ]);
    }

    return BackupRestoreResult(
      recipientsRestored: importedRecipients.length,
      remindersRestored: importedReminders.length,
      logsRestored: includeLogs ? importedLogs.length : 0,
      recipientsSkippedDuplicate: duplicateRecipients,
      remindersSkippedDuplicate: duplicateReminders,
      logsSkippedDuplicate: includeLogs ? duplicateLogs : 0,
      rejectedItems: rejected,
      schemaVersion: version,
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
