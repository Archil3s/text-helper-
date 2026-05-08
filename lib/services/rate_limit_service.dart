import '../models/appointment_reminder.dart';
import '../models/send_log_entry.dart';
import 'send_log_store.dart';

class RateLimitResult {
  const RateLimitResult({
    required this.allowed,
    this.reason,
  });

  final bool allowed;
  final String? reason;
}

class RateLimitService {
  RateLimitService({SendLogStore? logStore})
      : _logStore = logStore ?? SendLogStore();

  final SendLogStore _logStore;

  static const int maxPerMinute = 3;
  static const int maxPerHour = 30;
  static const int maxPerDay = 100;

  Future<RateLimitResult> check(AppointmentReminder reminder) async {
    final logs = await _logStore.loadLogs();
    final sent = logs.where((log) => log.status == 'sent').toList();

    final now = DateTime.now();
    final oneMinute = now.subtract(const Duration(minutes: 1));
    final oneHour = now.subtract(const Duration(hours: 1));
    final oneDay = now.subtract(const Duration(days: 1));

    final sentMinute =
        sent.where((log) => log.createdAt.isAfter(oneMinute)).length;
    final sentHour = sent.where((log) => log.createdAt.isAfter(oneHour)).length;
    final sentDay = sent.where((log) => log.createdAt.isAfter(oneDay)).length;

    if (sentMinute >= maxPerMinute) {
      return const RateLimitResult(
        allowed: false,
        reason: 'Rate limit hit: too many sends in the last minute.',
      );
    }

    if (sentHour >= maxPerHour) {
      return const RateLimitResult(
        allowed: false,
        reason: 'Rate limit hit: too many sends in the last hour.',
      );
    }

    if (sentDay >= maxPerDay) {
      return const RateLimitResult(
        allowed: false,
        reason: 'Rate limit hit: too many sends in the last day.',
      );
    }

    return const RateLimitResult(allowed: true);
  }

  Future<void> logBlockedRateLimit({
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
