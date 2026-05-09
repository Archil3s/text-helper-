import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/recipient_audit_item.dart';
import '../services/recipient_audit_service.dart';

class RecipientAuditPreviewScreen extends StatefulWidget {
  const RecipientAuditPreviewScreen({super.key});

  @override
  State<RecipientAuditPreviewScreen> createState() =>
      _RecipientAuditPreviewScreenState();
}

class _RecipientAuditPreviewScreenState
    extends State<RecipientAuditPreviewScreen> {
  final RecipientAuditService _auditService = RecipientAuditService();

  List<RecipientAuditItem> _items = <RecipientAuditItem>[];

  bool _loading = true;

  String _status = 'Loading recipient audit preview...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _auditService.buildAuditItems();

    if (!mounted) {
      return;
    }

    setState(() {
      _items = items;
      _loading = false;
      _status = 'Audit loaded: ${items.length} queued recipient(s).';
    });
  }

  int get _warningCount {
    return _items.where((item) => item.hasWarnings).length;
  }

  int get _blockedCount {
    return _items.where((item) => item.isBlocked).length;
  }

  int get _normalizationCount {
    return _items.where((item) => item.hasNormalizationChange).length;
  }

  int get _testCount {
    return _items.where((item) => item.testState == 'TEST NUMBER').length;
  }

  int get _liveCount {
    return _items.where((item) => item.testState != 'TEST NUMBER').length;
  }

  Color _riskColor(RecipientAuditItem item) {
    if (item.isBlocked) {
      return const Color(0xFFEF4444);
    }

    if (item.hasWarnings) {
      return const Color(0xFFF97316);
    }

    return const Color(0xFF16A34A);
  }

  String _riskLabel(RecipientAuditItem item) {
    if (item.isBlocked) {
      return 'BLOCK';
    }

    if (item.hasWarnings) {
      return 'CHECK';
    }

    return 'OK';
  }

  @override
  Widget build(BuildContext context) {
    final ready = _items.isNotEmpty && _blockedCount == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Recipient Audit'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _AuditHero(
                  total: _items.length,
                  warnings: _warningCount,
                  blocked: _blockedCount,
                  normalization: _normalizationCount,
                  test: _testCount,
                  live: _liveCount,
                  ready: ready,
                ),
                const SizedBox(height: 20),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                const _SurfaceCard(
                  child: Text(
                    'Use this screen before queueing or sending. It shows each pending recipient, contact name, phone number, test/live state, group label, final message, and warnings for suspicious numbers or country-code normalization.',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Queued recipients',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (_items.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No queued recipients to audit.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ..._items.map(
                    (item) => _AuditItemCard(
                      item: item,
                      color: _riskColor(item),
                      riskLabel: _riskLabel(item),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _AuditHero extends StatelessWidget {
  const _AuditHero({
    required this.total,
    required this.warnings,
    required this.blocked,
    required this.normalization,
    required this.test,
    required this.live,
    required this.ready,
  });

  final int total;
  final int warnings;
  final int blocked;
  final int normalization;
  final int test;
  final int live;
  final bool ready;

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
            CupertinoIcons.person_crop_circle_badge_checkmark,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'Recipient audit preview',
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
                ? 'No blocking recipient issues found.'
                : 'Review warnings before sending or syncing background alarms.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetric(value: '$total', label: 'total'),
              _HeroMetric(value: '$warnings', label: 'warnings'),
              _HeroMetric(value: '$blocked', label: 'blocked'),
              _HeroMetric(value: '$normalization', label: 'normalized'),
              _HeroMetric(value: '$test', label: 'test'),
              _HeroMetric(value: '$live', label: 'live'),
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
      width: 92,
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

class _AuditItemCard extends StatelessWidget {
  const _AuditItemCard({
    required this.item,
    required this.color,
    required this.riskLabel,
  });

  final RecipientAuditItem item;
  final Color color;
  final String riskLabel;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      borderColor: item.hasWarnings ? color : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.isBlocked
                    ? CupertinoIcons.xmark_circle_fill
                    : item.hasWarnings
                        ? CupertinoIcons.exclamationmark_triangle_fill
                        : CupertinoIcons.check_mark_circled_solid,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.contactName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                riskLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AuditLine(label: 'Phone', value: item.phoneNumber),
          _AuditLine(label: 'Normalized', value: item.normalizedPhoneNumber),
          _AuditLine(label: 'Group', value: item.groupLabel),
          _AuditLine(label: 'State', value: item.testState),
          _AuditLine(label: 'Scheduled', value: item.scheduledAtLabel),
          const SizedBox(height: 10),
          const Text(
            'Final message',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            item.message,
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (item.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Warnings',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            ...item.warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_triangle_fill,
                      color: color,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: TextStyle(
                          color: color,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AuditLine extends StatelessWidget {
  const _AuditLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w800),
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
