import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/appointment_reminder.dart';
import '../models/message_timeline_event.dart';
import '../models/send_log_entry.dart';
import '../services/appointment_reminder_store.dart';
import '../services/message_timeline_store.dart';
import '../services/send_log_store.dart';

class MessageTimelineScreen extends StatefulWidget {
  const MessageTimelineScreen({super.key});

  @override
  State<MessageTimelineScreen> createState() => _MessageTimelineScreenState();
}

class _MessageTimelineScreenState extends State<MessageTimelineScreen> {
  final AppointmentReminderStore _reminderStore = AppointmentReminderStore();
  final SendLogStore _logStore = SendLogStore();
  final MessageTimelineStore _timelineStore = MessageTimelineStore();

  List<AppointmentReminder> _reminders = <AppointmentReminder>[];
  List<SendLogEntry> _logs = <SendLogEntry>[];
  List<MessageTimelineEvent> _events = <MessageTimelineEvent>[];

  bool _loading = true;

  String _status = 'Timeline loaded.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reminders = await _reminderStore.loadReminders();
    final logs = await _logStore.loadLogs();
    final manualEvents = await _timelineStore.loadEvents();

    final derived = <MessageTimelineEvent>[];

    for (final reminder in reminders) {
      derived.add(
        MessageTimelineEvent(
          id: 'derived-queued-${reminder.id}',
          reminderId: reminder.id,
          phoneNumber: reminder.phoneNumber,
          message: reminder.message,
          status: reminder.isSent ? 'sent' : 'queued',
          title: reminder.isSent ? 'Marked sent' : 'Queued',
          detail: reminder.isSent
              ? 'Reminder is marked sent in local storage.'
              : 'Scheduled for ${_formatDateTime(reminder.scheduledAt)}.',
          createdAt: reminder.sentAt ?? reminder.scheduledAt,
        ),
      );

      if (!reminder.isSent && !reminder.scheduledAt.isAfter(DateTime.now())) {
        derived.add(
          MessageTimelineEvent(
            id: 'derived-triggered-${reminder.id}',
            reminderId: reminder.id,
            phoneNumber: reminder.phoneNumber,
            message: reminder.message,
            status: 'triggered',
            title: 'Due / triggered',
            detail: 'Reminder time has passed and should be processed.',
            createdAt: reminder.scheduledAt,
          ),
        );
      }
    }

    for (final log in logs) {
      derived.add(
        MessageTimelineEvent(
          id: 'derived-log-${log.id}',
          reminderId: log.reminderId,
          phoneNumber: log.phoneNumber,
          message: log.message,
          status: log.status,
          title: switch (log.status) {
            'sent' => 'Sent to Android SMS service',
            'failed' => 'Failed',
            'blocked' => 'Blocked',
            _ => 'Log event',
          },
          detail: log.errorMessage ?? log.status,
          createdAt: log.createdAt,
        ),
      );
    }

    final allEvents = [...manualEvents, ...derived]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) {
      return;
    }

    setState(() {
      _reminders = reminders;
      _logs = logs;
      _events = allEvents;
      _loading = false;
      _status = 'Timeline showing ${allEvents.length} event(s).';
    });
  }

  Future<void> _clearManualTimeline() async {
    await _timelineStore.clearEvents();
    await _load();

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Manual timeline events cleared. Derived logs remain visible.';
    });
  }

  int get _queuedCount {
    return _events.where((event) => event.status == 'queued').length;
  }

  int get _syncedCount {
    return _events.where((event) => event.status == 'background_synced').length;
  }

  int get _sentCount {
    return _events.where((event) => event.status == 'sent').length;
  }

  int get _failedCount {
    return _events.where((event) => event.status == 'failed').length;
  }

  int get _blockedCount {
    return _events.where((event) => event.status == 'blocked').length;
  }

  String _formatDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    return switch (status) {
      'queued' => const Color(0xFF0A84FF),
      'background_synced' => const Color(0xFF6366F1),
      'triggered' => const Color(0xFFF97316),
      'sent' => const Color(0xFF16A34A),
      'failed' => const Color(0xFFEF4444),
      'blocked' => const Color(0xFFF97316),
      _ => const Color(0xFF6B7280),
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'queued' => CupertinoIcons.tray_fill,
      'background_synced' => CupertinoIcons.cloud_upload_fill,
      'triggered' => CupertinoIcons.bell_fill,
      'sent' => CupertinoIcons.check_mark_circled_solid,
      'failed' => CupertinoIcons.xmark_circle_fill,
      'blocked' => CupertinoIcons.shield_fill,
      _ => CupertinoIcons.info_circle_fill,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Message Timeline'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(CupertinoIcons.refresh),
          ),
          IconButton(
            onPressed: _clearManualTimeline,
            icon: const Icon(CupertinoIcons.trash),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _TimelineHero(
                  total: _events.length,
                  queued: _queuedCount,
                  synced: _syncedCount,
                  sent: _sentCount,
                  failed: _failedCount,
                  blocked: _blockedCount,
                ),
                const SizedBox(height: 20),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Text(
                    'This screen combines stored timeline events, reminders, and send logs. It uses “Sent to Android SMS service” unless real carrier delivery receipts are added later.',
                    style: const TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Events',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (_events.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No timeline events yet.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ..._events.map(
                    (event) => _TimelineEventCard(
                      event: event,
                      color: _statusColor(event.status),
                      icon: _statusIcon(event.status),
                      dateTime: _formatDateTime(event.createdAt),
                    ),
                  ),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Text(
                    'Data sources: ${_reminders.length} reminder(s), ${_logs.length} send log(s), and stored sync/trigger events.',
                    style: const TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _TimelineHero extends StatelessWidget {
  const _TimelineHero({
    required this.total,
    required this.queued,
    required this.synced,
    required this.sent,
    required this.failed,
    required this.blocked,
  });

  final int total;
  final int queued;
  final int synced;
  final int sent;
  final int failed;
  final int blocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF111827),
            Color(0xFF1D4ED8),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.timeline_selection,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'Message timeline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Trace queued, synced, triggered, sent, failed, and blocked states.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetric(value: '$total', label: 'total'),
              _HeroMetric(value: '$queued', label: 'queued'),
              _HeroMetric(value: '$synced', label: 'synced'),
              _HeroMetric(value: '$sent', label: 'sent'),
              _HeroMetric(value: '$failed', label: 'failed'),
              _HeroMetric(value: '$blocked', label: 'blocked'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEventCard extends StatelessWidget {
  const _TimelineEventCard({
    required this.event,
    required this.color,
    required this.icon,
    required this.dateTime,
  });

  final MessageTimelineEvent event;
  final Color color;
  final IconData icon;
  final String dateTime;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      borderColor:
          event.status == 'failed' || event.status == 'blocked' ? color : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateTime,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  event.phoneNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  event.detail,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  event.message,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            event.status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.info_circle_fill,
            color: Color(0xFF0A84FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status,
              style: const TextStyle(
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.borderColor,
  });

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
