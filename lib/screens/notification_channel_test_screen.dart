import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/notification_channel_service.dart';

class NotificationChannelTestScreen extends StatefulWidget {
  const NotificationChannelTestScreen({super.key});

  @override
  State<NotificationChannelTestScreen> createState() =>
      _NotificationChannelTestScreenState();
}

class _NotificationChannelTestScreenState
    extends State<NotificationChannelTestScreen> {
  final NotificationChannelService _service = NotificationChannelService();

  NotificationChannelDiagnostics _diagnostics =
      NotificationChannelDiagnostics.unavailable();

  bool _loading = true;
  bool _busy = false;
  String _status =
      'Check reminder notification sound, vibration, and Android channel state.';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _status = 'Checking notification permission and channel status...';
    });

    final diagnostics = await _service.getDiagnostics();

    if (!mounted) {
      return;
    }

    setState(() {
      _diagnostics = diagnostics;
      _loading = false;
      _busy = false;
      _status = diagnostics.ready
          ? 'Reminder notifications are enabled and the channel is available.'
          : 'Notification setup needs attention before reminder popups are reliable.';
    });
  }

  Future<void> _createChannel() async {
    setState(() {
      _busy = true;
      _status = 'Creating reminder notification channel...';
    });

    final diagnostics = await _service.createReminderChannel();

    if (!mounted) {
      return;
    }

    setState(() {
      _diagnostics = diagnostics;
      _busy = false;
      _status = diagnostics.channelCreated
          ? 'Reminder notification channel is ready.'
          : 'Could not confirm reminder notification channel creation.';
    });
  }

  Future<void> _requestPermission() async {
    setState(() {
      _busy = true;
      _status = 'Requesting Android notification permission...';
    });

    final granted = await _service.requestPostNotificationsPermission();
    final diagnostics = await _service.getDiagnostics();

    if (!mounted) {
      return;
    }

    setState(() {
      _diagnostics = diagnostics;
      _busy = false;
      _status = granted
          ? 'Notification permission is granted.'
          : 'Notification permission is still blocked. Open Android notification settings.';
    });
  }

  Future<void> _sendTestNotification() async {
    setState(() {
      _busy = true;
      _status = 'Sending test reminder notification...';
    });

    final sent = await _service.sendTestReminderNotification();
    final diagnostics = await _service.getDiagnostics();

    if (!mounted) {
      return;
    }

    setState(() {
      _diagnostics = diagnostics;
      _busy = false;
      _status = sent
          ? 'Test sent. Confirm that you heard a sound or felt vibration.'
          : 'Test was blocked. Check app notifications, channel sound, vibration, and Android permission.';
    });
  }

  Future<void> _openNotificationSettings() async {
    await _service.openNotificationSettings();

    if (!mounted) {
      return;
    }

    setState(() {
      _status =
          'Return here and tap Refresh after changing app notification settings.';
    });
  }

  Future<void> _openChannelSettings() async {
    await _service.openReminderNotificationChannelSettings();

    if (!mounted) {
      return;
    }

    setState(() {
      _status =
          'Return here and tap Refresh after changing reminder channel settings.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready = _diagnostics.ready;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Notification Sound Test'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _NotificationHero(
                  ready: ready,
                  diagnostics: _diagnostics,
                ),
                const SizedBox(height: 20),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                _CheckCard(
                  title: 'Notification permission',
                  subtitle: _diagnostics.permissionGranted
                      ? 'Android notification permission is granted.'
                      : 'Android may block reminder notifications until permission is granted.',
                  passed: _diagnostics.permissionGranted,
                ),
                _CheckCard(
                  title: 'App notifications',
                  subtitle: _diagnostics.notificationsEnabled
                      ? 'Android reports app notifications are enabled.'
                      : 'App-level notifications are blocked in Android settings.',
                  passed: _diagnostics.notificationsEnabled,
                ),
                _CheckCard(
                  title: 'Reminder channel',
                  subtitle: _diagnostics.channelCreated
                      ? 'Reminder notification channel exists.'
                      : 'Reminder notification channel has not been created yet.',
                  passed: _diagnostics.channelCreated,
                ),
                _CheckCard(
                  title: 'Channel sound and vibration',
                  subtitle: _diagnostics.channelEnabled
                      ? 'Channel is active with importance: ${_diagnostics.channelImportance}.'
                      : 'Channel is blocked or unavailable. Sound/vibration may not fire.',
                  passed: _diagnostics.channelEnabled,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _sendTestNotification,
                  icon: const Icon(CupertinoIcons.speaker_2_fill),
                  label: const Text('Send sound/vibration test'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _requestPermission,
                  icon: const Icon(CupertinoIcons.bell_fill),
                  label: const Text('Request notification permission'),
                  style: _buttonStyle(),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _createChannel,
                  icon: const Icon(CupertinoIcons.plus_circle),
                  label: const Text('Create reminder channel'),
                  style: _buttonStyle(),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _openChannelSettings,
                  icon: const Icon(CupertinoIcons.slider_horizontal_3),
                  label: const Text('Open reminder channel settings'),
                  style: _buttonStyle(),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _openNotificationSettings,
                  icon: const Icon(CupertinoIcons.settings_solid),
                  label: const Text('Open app notification settings'),
                  style: _buttonStyle(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'What to verify',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const _SurfaceCard(
                  child: Text(
                    'Tap Send sound/vibration test. The phone should show a Text Helper reminder notification and play the channel sound or vibration.',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const _SurfaceCard(
                  child: Text(
                    'If there is no sound, open Reminder Channel Settings and confirm the channel is not silent, blocked, muted, or set to low importance.',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const _SurfaceCard(
                  child: Text(
                    'If Android updates or restores phone settings, repeat this test before relying on reminder popups.',
                    style: TextStyle(
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

  ButtonStyle _buttonStyle() {
    return OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _NotificationHero extends StatelessWidget {
  const _NotificationHero({
    required this.ready,
    required this.diagnostics,
  });

  final bool ready;
  final NotificationChannelDiagnostics diagnostics;

  @override
  Widget build(BuildContext context) {
    final color = ready ? const Color(0xFF16A34A) : const Color(0xFFF97316);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            const Color(0xFF111827),
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
            CupertinoIcons.bell_circle_fill,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 16),
          const Text(
            'Notification sound test',
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
            ready
                ? 'Reminder alerts are ready for sound and vibration testing.'
                : 'Check notification permission, app status, and reminder channel settings.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(
                value: diagnostics.permissionGranted ? 'OK' : 'BLOCK',
                label: 'permission',
              ),
              const SizedBox(width: 10),
              _HeroMetric(
                value: diagnostics.channelImportance.toUpperCase(),
                label: 'channel',
              ),
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
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

class _CheckCard extends StatelessWidget {
  const _CheckCard({
    required this.title,
    required this.subtitle,
    required this.passed,
  });

  final String title;
  final String subtitle;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final color = passed ? const Color(0xFF16A34A) : const Color(0xFFF97316);

    return _SurfaceCard(
      borderColor: passed ? null : color,
      child: Row(
        children: [
          Icon(
            passed
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.exclamationmark_triangle_fill,
            color: color,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
