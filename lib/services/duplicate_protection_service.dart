import '../models/appointment_reminder.dart';
import '../models/send_log_entry.dart';
import 'send_log_store.dart';

class DuplicateProtectionResult {
  const DuplicateProtectionResult({
    required this.allowed,
    this.reason,
  });

  final bool allowed;
  final String? reason;
}

class DuplicateProtectionService {
  DuplicateProtectionService({SendLogStore? logStore})
      : _logStore = logStore ?? SendLogStore();

  final SendLogStore _logStore;

  Future<DuplicateProtectionResult> checkReminder(
    AppointmentReminder reminder,
  ) async {
    final logs = await _logStore.loadLogs();
    final message = reminder.message.trim();
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    for (final log in logs) {
      if (log.status != 'sent') {
        continue;
      }

      if (log.reminderId == reminder.id) {
        return const DuplicateProtectionResult(
          allowed: false,
          reason: 'This reminder ID has already been sent.',
        );
      }
    }

    for (final log in logs) {
      if (log.status != 'sent') {
        continue;
      }

      final sameNumber = log.phoneNumber == reminder.phoneNumber;
      final sameMessage = log.message.trim() == message;
      final recent = log.createdAt.isAfter(cutoff);

      if (sameNumber && sameMessage && recent) {
        return const DuplicateProtectionResult(
          allowed: false,
          reason: 'Same number and message already sent in the last 24 hours.',
        );
      }
    }

    return const DuplicateProtectionResult(allowed: true);
  }

  Future<void> logBlockedDuplicate({
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
