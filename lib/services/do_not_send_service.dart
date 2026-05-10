import '../models/appointment_reminder.dart';
import '../models/nz_sms_recipient.dart';
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

    return checkContactId(
      contactId: reminder.contactId,
      phoneNumber: reminder.phoneNumber,
    );
  }

  Future<DoNotSendResult> checkContact(NzSmsRecipient contact) async {
    return checkContactId(
      contactId: contact.id,
      phoneNumber: contact.number,
      contactName: contact.name,
    );
  }

  Future<DoNotSendResult> checkContactId({
    required String contactId,
    String? phoneNumber,
    String? contactName,
  }) async {
    final id = contactId.trim();

    if (id.isEmpty) {
      return const DoNotSendResult(allowed: true);
    }

    final groups = await _groupStore.loadGroups();

    for (final group in groups) {
      if (!group.isBlockedGroup) {
        continue;
      }

      if (group.contactIds.contains(id)) {
        final who = contactName == null || contactName.trim().isEmpty
            ? phoneNumber ?? id
            : contactName;

        return DoNotSendResult(
          allowed: false,
          reason: 'Blocked: $who is in Do Not Send group "${group.name}".',
        );
      }
    }

    return const DoNotSendResult(allowed: true);
  }

  Future<DoNotSendResult> checkContacts(List<NzSmsRecipient> contacts) async {
    for (final contact in contacts) {
      final result = await checkContact(contact);

      if (!result.allowed) {
        return result;
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

  Future<void> logBlockedContact({
    required NzSmsRecipient contact,
    required String message,
    required String reason,
    String? reminderId,
  }) async {
    await _logStore.addLog(
      SendLogEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        contactName: contact.name,
        phoneNumber: contact.number,
        message: message,
        createdAt: DateTime.now(),
        status: 'blocked',
        errorMessage: reason,
        reminderId: reminderId,
      ),
    );
  }
}
