import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/send_log_store.dart';

class SendHistoryScreen extends StatefulWidget {
  const SendHistoryScreen({super.key});

  @override
  State<SendHistoryScreen> createState() => _SendHistoryScreenState();
}

class _SendHistoryScreenState extends State<SendHistoryScreen> {
  final SendLogStore _store = SendLogStore();

  var _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await _store.loadLogs();

    if (!mounted) {
      return;
    }

    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    await _store.clearLogs();
    await _load();
  }

  String _format(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Color _color(String status) {
    return switch (status) {
      'sent' => const Color(0xFF16A34A),
      'blocked' => const Color(0xFFF97316),
      'failed' => const Color(0xFFEF4444),
      _ => const Color(0xFF0A84FF),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Send History'),
        actions: [
          IconButton(
            onPressed: _clear,
            icon: const Icon(CupertinoIcons.trash),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Text(
                    '${_logs.length} send logs',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_logs.isEmpty)
                  const _SurfaceCard(child: Text('No logs yet.'))
                else
                  ..._logs.map(
                    (log) => _SurfaceCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            log.status == 'sent'
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.xmark_circle_fill,
                            color: _color(log.status),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.contactName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  log.phoneNumber,
                                  style: const TextStyle(
                                    color: Color(0xFF0A84FF),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _format(log.createdAt),
                                  style: const TextStyle(
                                    color: CupertinoColors.secondaryLabel,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  log.message,
                                  style: const TextStyle(
                                    color: CupertinoColors.secondaryLabel,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (log.errorMessage != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    log.errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            log.status.toUpperCase(),
                            style: TextStyle(
                              color: _color(log.status),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
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
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}
