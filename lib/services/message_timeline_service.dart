import '../models/appointment_reminder.dart';
import '../models/message_timeline_event.dart';
import '../models/send_log_entry.dart';
import 'message_timeline_store.dart';

class MessageTimelineService {
  MessageTimelineService({MessageTimelineStore? store})
      : _store = store ?? MessageTimelineStore();

  final MessageTimelineStore _store;

  Future<void> logQueued(AppointmentReminder reminder) {
    return _add(
      reminder: reminder,
      status: 'queued',
      title: 'Queued',
      detail: 'Message queued for ${reminder.scheduledAt.toIso8601String()}',
    );
  }

  Future<void> logBackgroundSynced(AppointmentReminder reminder) {
    return _add(
      reminder: reminder,
      status: 'background_synced',
      title: 'Background alarm synced',
      detail: 'Message synced to Android background scheduler.',
    );
  }

  Future<void> logTriggered(AppointmentReminder reminder) {
    return _add(
      reminder: reminder,
      status: 'triggered',
      title: 'Triggered',
      detail: 'Send attempt started.',
    );
  }

  Future<void> logSent(AppointmentReminder reminder) {
    return _add(
      reminder: reminder,
      status: 'sent',
      title: 'Sent to Android SMS service',
      detail: 'Android SMS service accepted the send request.',
    );
  }

  Future<void> logFailed(AppointmentReminder reminder, String? error) {
    return _add(
      reminder: reminder,
      status: 'failed',
      title: 'Failed',
      detail: error == null || error.trim().isEmpty
          ? 'Send failed.'
          : 'Send failed: $error',
    );
  }

  Future<void> logBlocked(AppointmentReminder reminder, String? reason) {
    return _add(
      reminder: reminder,
      status: 'blocked',
      title: 'Blocked',
      detail: reason == null || reason.trim().isEmpty
          ? 'Send was blocked.'
          : reason,
    );
  }

  Future<void> logFromSendLog(SendLogEntry log) async {
    final title = switch (log.status) {
      'sent' => 'Sent to Android SMS service',
      'failed' => 'Failed',
      'blocked' => 'Blocked',
      _ => 'Log event',
    };

    await _store.addEvent(
      MessageTimelineEvent(
        id: 'log-${DateTime.now().microsecondsSinceEpoch}-${log.id}',
        reminderId: log.reminderId,
        phoneNumber: log.phoneNumber,
        message: log.message,
        status: log.status,
        title: title,
        detail: log.errorMessage ?? title,
        createdAt: log.createdAt,
      ),
    );
  }

  Future<void> _add({
    required AppointmentReminder reminder,
    required String status,
    required String title,
    required String detail,
  }) async {
    await _store.addEvent(
      MessageTimelineEvent(
        id: '${DateTime.now().microsecondsSinceEpoch}-${reminder.id}-$status',
        reminderId: reminder.id,
        phoneNumber: reminder.phoneNumber,
        message: reminder.message,
        status: status,
        title: title,
        detail: detail,
        createdAt: DateTime.now(),
      ),
    );
  }
}
