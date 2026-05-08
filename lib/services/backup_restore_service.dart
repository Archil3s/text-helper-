import 'dart:convert';

import 'package:flutter/services.dart';

import 'appointment_reminder_store.dart';
import 'nz_recipient_store.dart';
import 'send_log_store.dart';

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
}
