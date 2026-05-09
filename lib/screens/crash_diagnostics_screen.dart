import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/crash_diagnostics_service.dart';

class CrashDiagnosticsScreen extends StatefulWidget {
  const CrashDiagnosticsScreen({super.key});

  @override
  State<CrashDiagnosticsScreen> createState() => _CrashDiagnosticsScreenState();
}

class _CrashDiagnosticsScreenState extends State<CrashDiagnosticsScreen> {
  static const String _notesKey = 'text_helper_crash_diagnostics_notes';

  final CrashDiagnosticsService _service = CrashDiagnosticsService();
  final TextEditingController _notesController = TextEditingController();

  CrashDiagnosticsReport? _report;
  bool _loading = true;
  bool _busy = false;
  String _status = 'Build a local diagnostic report for support and testing.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _notesController.text = prefs.getString(_notesKey) ?? '';
    await _refreshReport();
  }

  Future<void> _refreshReport() async {
    setState(() {
      _busy = true;
      _status = 'Collecting device, queue, log, and background health data...';
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notesKey, _notesController.text);

    final report = await _service.buildReport(notes: _notesController.text);

    if (!mounted) {
      return;
    }

    setState(() {
      _report = report;
      _loading = false;
      _busy = false;
      _status = 'Diagnostics report refreshed.';
    });
  }

  Future<void> _copyReport() async {
    final report = _report ??
        await _service.buildReport(
          notes: _notesController.text,
        );

    await Clipboard.setData(ClipboardData(text: report.toPrettyJson()));

    if (!mounted) {
      return;
    }

    setState(() {
      _report = report;
      _status = 'Diagnostic report copied to clipboard.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Crash Diagnostics'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _busy ? null : _refreshReport,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: _loading || report == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _DiagnosticsHero(report: report),
                const SizedBox(height: 20),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                _MetricGrid(report: report),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Local crash / freeze notes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        minLines: 4,
                        maxLines: 8,
                        decoration: InputDecoration(
                          hintText:
                              'Example: App froze after tapping Sync Background Alarms. Phone was in battery saver.',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _copyReport,
                  icon: const Icon(CupertinoIcons.doc_on_clipboard),
                  label: const Text('Copy diagnostic report'),
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
                  onPressed: _busy ? null : _refreshReport,
                  icon: const Icon(CupertinoIcons.arrow_clockwise),
                  label: const Text('Refresh report'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Recent failed or blocked sends',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (report.recentFailures.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No recent failed or blocked sends are stored.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ...report.recentFailures.map(_FailureCard.new),
              ],
            ),
    );
  }
}

class _DiagnosticsHero extends StatelessWidget {
  const _DiagnosticsHero({required this.report});

  final CrashDiagnosticsReport report;

  @override
  Widget build(BuildContext context) {
    final native = report.nativeDiagnostics;
    final model = '${native['manufacturer'] ?? 'Unknown'} '
        '${native['model'] ?? 'device'}';
    final androidRelease = native['androidRelease'] ?? 'unknown';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7C3AED),
            Color(0xFF111827),
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
            CupertinoIcons.wrench_fill,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 16),
          const Text(
            'Crash diagnostics',
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
            '$model • Android $androidRelease',
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
                value: '${report.failedLogs}',
                label: 'failed',
              ),
              const SizedBox(width: 10),
              _HeroMetric(
                value: '${report.blockedLogs}',
                label: 'blocked',
              ),
              const SizedBox(width: 10),
              _HeroMetric(
                value: '${report.unsentReminders}',
                label: 'queued',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.report});

  final CrashDiagnosticsReport report;

  @override
  Widget build(BuildContext context) {
    final native = report.nativeDiagnostics;
    final batteryPercent = native['batteryPercent'];
    final smsPermission = native['smsPermissionGranted'] == true ? 'Yes' : 'No';
    final notificationsPermission =
        native['notificationsPermissionGranted'] == true ? 'Yes' : 'No';

    return Column(
      children: [
        _InfoCard(
          title: 'Device',
          value:
              '${native['manufacturer'] ?? 'Unknown'} ${native['model'] ?? ''}',
          icon: Icons.phone_android_outlined,
        ),
        _InfoCard(
          title: 'Android',
          value:
              '${native['androidRelease'] ?? 'unknown'} / API ${native['apiLevel'] ?? 0}',
          icon: CupertinoIcons.device_phone_portrait,
        ),
        _InfoCard(
          title: 'Battery',
          value:
              '$batteryPercent% • charging: ${native['batteryCharging'] == true ? 'yes' : 'no'}',
          icon: CupertinoIcons.battery_25,
        ),
        _InfoCard(
          title: 'Permissions',
          value:
              'SMS: $smsPermission • Notifications: $notificationsPermission',
          icon: CupertinoIcons.lock_shield,
        ),
        _InfoCard(
          title: 'Background health',
          value:
              'Exact alarms: ${report.exactAlarmsAllowed ? 'yes' : 'no'} • Battery unrestricted: ${report.batteryUnrestricted ? 'yes' : 'no'}',
          icon: CupertinoIcons.clock_fill,
        ),
        _InfoCard(
          title: 'Queue and logs',
          value:
              '${report.unsentReminders} queued • ${report.failedLogs} failed • ${report.blockedLogs} blocked',
          icon: CupertinoIcons.list_bullet,
        ),
      ],
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard(this.failure);

  final Map<String, dynamic> failure;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${failure['status'] ?? 'unknown'} • ${failure['phoneNumber'] ?? ''}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            failure['createdAt']?.toString() ?? '',
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            failure['errorMessage']?.toString().isEmpty ?? true
                ? 'No error message stored.'
                : failure['errorMessage'].toString(),
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF7C3AED)),
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
                  value,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
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
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
