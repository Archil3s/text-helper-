import 'package:shared_preferences/shared_preferences.dart';

import 'appointment_reminder_store.dart';
import 'backup_restore_service.dart';
import 'nz_recipient_store.dart';

class UpdateSafeMigrationReport {
  const UpdateSafeMigrationReport({
    required this.schemaVersion,
    required this.lastAppVersion,
    required this.currentAppVersion,
    required this.firstRunAfterUpdate,
    required this.contactsCount,
    required this.remindersCount,
    required this.unsentRemindersCount,
    required this.backupRecommended,
    required this.restorePromptRecommended,
    required this.warnings,
  });

  final int schemaVersion;
  final String lastAppVersion;
  final String currentAppVersion;
  final bool firstRunAfterUpdate;
  final int contactsCount;
  final int remindersCount;
  final int unsentRemindersCount;
  final bool backupRecommended;
  final bool restorePromptRecommended;
  final List<String> warnings;
}

class UpdateSafeMigrationService {
  UpdateSafeMigrationService({
    AppointmentReminderStore? reminderStore,
    NzRecipientStore? recipientStore,
    BackupRestoreService? backupService,
  })  : _reminderStore = reminderStore ?? AppointmentReminderStore(),
        _recipientStore = recipientStore ?? NzRecipientStore(),
        _backupService = backupService ?? BackupRestoreService();

  static const int currentSchemaVersion = 1;
  static const String _schemaKey = 'text_helper_schema_version';
  static const String _lastAppVersionKey = 'text_helper_last_app_version';
  static const String _lastBackupPromptKey = 'text_helper_last_backup_prompt';
  static const String _lastKnownContactsKey = 'text_helper_last_known_contacts';
  static const String _lastKnownRemindersKey =
      'text_helper_last_known_reminders';

  final AppointmentReminderStore _reminderStore;
  final NzRecipientStore _recipientStore;
  final BackupRestoreService _backupService;

  Future<UpdateSafeMigrationReport> buildReport({
    required String currentAppVersion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final schemaVersion = prefs.getInt(_schemaKey) ?? 0;
    final lastAppVersion = prefs.getString(_lastAppVersionKey) ?? 'none';
    final lastKnownContacts = prefs.getInt(_lastKnownContactsKey) ?? 0;
    final lastKnownReminders = prefs.getInt(_lastKnownRemindersKey) ?? 0;

    final contacts = await _recipientStore.loadRecipients();
    final reminders = await _reminderStore.loadReminders();
    final unsentReminders = reminders.where((item) => !item.isSent).length;

    final firstRunAfterUpdate =
        lastAppVersion != 'none' && lastAppVersion != currentAppVersion;

    final warnings = <String>[];

    if (schemaVersion < currentSchemaVersion) {
      warnings.add(
        'Local data schema is older than the current app schema. Run migration check.',
      );
    }

    if (firstRunAfterUpdate) {
      warnings.add(
        'This looks like the first run after an app version change.',
      );
    }

    if (lastKnownContacts > 0 && contacts.isEmpty) {
      warnings.add(
        'Contacts were previously detected but are now empty. Restore may be needed.',
      );
    }

    if (lastKnownReminders > 0 && reminders.isEmpty) {
      warnings.add(
        'Reminders were previously detected but are now empty. Restore may be needed.',
      );
    }

    if (unsentReminders > 0) {
      warnings.add(
        'Unsent reminders exist. Export a backup before updating or reinstalling.',
      );
    }

    final backupRecommended =
        firstRunAfterUpdate || unsentReminders > 0 || reminders.isNotEmpty;

    final restorePromptRecommended =
        (lastKnownContacts > 0 && contacts.isEmpty) ||
            (lastKnownReminders > 0 && reminders.isEmpty);

    return UpdateSafeMigrationReport(
      schemaVersion: schemaVersion,
      lastAppVersion: lastAppVersion,
      currentAppVersion: currentAppVersion,
      firstRunAfterUpdate: firstRunAfterUpdate,
      contactsCount: contacts.length,
      remindersCount: reminders.length,
      unsentRemindersCount: unsentReminders,
      backupRecommended: backupRecommended,
      restorePromptRecommended: restorePromptRecommended,
      warnings: warnings,
    );
  }

  Future<void> recordCurrentState({required String currentAppVersion}) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = await _recipientStore.loadRecipients();
    final reminders = await _reminderStore.loadReminders();

    await prefs.setInt(_schemaKey, currentSchemaVersion);
    await prefs.setString(_lastAppVersionKey, currentAppVersion);
    await prefs.setInt(_lastKnownContactsKey, contacts.length);
    await prefs.setInt(_lastKnownRemindersKey, reminders.length);
  }

  Future<String> buildBackupJsonAndRecordPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastBackupPromptKey,
      DateTime.now().toIso8601String(),
    );

    return _backupService.buildBackupJson();
  }
}
