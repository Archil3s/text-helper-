import '../models/appointment_reminder.dart';
import '../models/send_log_entry.dart';
import 'contact_group_store.dart';
import 'send_log_store.dart';

class DoNotSendResult {
  const DoNotSendResult({
    required this.allowed,
    this.reason,
  });

  final bool allowed;
  final String? reason;
}

class DoNotSendService {
  DoNotSendService({
    ContactGroupStore? groupStore,
    SendLogStore? logStore,
  })  : _groupStore = groupStore ?? ContactGroupStore(),
        _logStore = logStore ?? SendLogStore();

  final ContactGroupStore _groupStore;
  final SendLogStore _logStore;

  Future<DoNotSendResult> checkReminder(AppointmentReminder reminder) async {
    if (reminder.contactId.trim().isEmpty) {
      return const DoNotSendResult(allowed: true);
    }

    final groups = await _groupStore.loadGroups();

    for (final group in groups) {
      if (!group.isBlockedGroup) {
        continue;
      }

      if (group.contactIds.contains(reminder.contactId)) {
        return DoNotSendResult(
          allowed: false,
          reason: 'Blocked: contact is in Do Not Send group "${group.name}".',
        );
      }
    }

    return const DoNotSendResult(allowed: true);
  }

  Future<void> logBlocked({
    required AppointmentReminder reminder,
    required String reason,
  }) async {
    await _logStore.addLog(
      SendLogEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        contactName: reminder.contactName,
        phoneNumber: reminder.phoneNumber,
        message: reminder.message,
        createdAt: DateTime.now(),
        status: 'blocked',
        errorMessage: reason,
        reminderId: reminder.id,
      ),
    );
  }
}
