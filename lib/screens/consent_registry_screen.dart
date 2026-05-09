import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ConsentRegistryScreen extends StatefulWidget {
  const ConsentRegistryScreen({super.key});

  @override
  State<ConsentRegistryScreen> createState() => _ConsentRegistryScreenState();
}

class _ConsentRegistryScreenState extends State<ConsentRegistryScreen> {
  final List<_ConsentRecord> _records = [
    _ConsentRecord(
      number: '+64211234567',
      name: 'Alex Carter',
      source: 'Manual opt-in',
      hasConsent: true,
    ),
    _ConsentRecord(
      number: '+64275551234',
      name: 'Morgan Lee',
      source: 'Imported list',
      hasConsent: false,
    ),
    _ConsentRecord(
      number: '+64221234567',
      name: 'Taylor Brooks',
      source: 'Manual opt-in',
      hasConsent: true,
    ),
  ];

  int get _approvedCount {
    return _records.where((record) => record.hasConsent).length;
  }

  int get _blockedCount {
    return _records.where((record) => !record.hasConsent).length;
  }

  void _toggleConsent(int index, bool value) {
    setState(() {
      _records[index] = _records[index].copyWith(hasConsent: value);
    });
  }

  void _showExportNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Approved consent list is ready for campaign preview.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Consent Registry'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeroCard(
            approvedCount: _approvedCount,
            blockedCount: _blockedCount,
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Recipient consent'),
          const SizedBox(height: 12),
          ..._records.asMap().entries.map(
                (entry) => _ConsentCard(
                  record: entry.value,
                  onChanged: (value) => _toggleConsent(entry.key, value),
                ),
              ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _approvedCount == 0 ? null : _showExportNotice,
            icon: const Icon(CupertinoIcons.check_mark_circled_solid),
            label: Text('Use $_approvedCount approved recipients'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _ComplianceNote(),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.approvedCount,
    required this.blockedCount,
  });

  final int approvedCount;
  final int blockedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.person_crop_circle_badge_checkmark,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Consent Registry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$approvedCount approved • $blockedCount blocked',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
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

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.record,
    required this.onChanged,
  });

  final _ConsentRecord record;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          Icon(
            record.hasConsent
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.xmark_circle_fill,
            color: record.hasConsent
                ? const Color(0xFF16A34A)
                : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.number,
                  style: const TextStyle(
                    color: Color(0xFF0A84FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.source,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: record.hasConsent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ComplianceNote extends StatelessWidget {
  const _ComplianceNote();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.shield_fill, color: Color(0xFFF97316)),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Only approved recipients should move into campaigns. Keep SMS sending disabled until consent, unsubscribe, audit trail, and final review are complete.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ConsentRecord {
  const _ConsentRecord({
    required this.number,
    required this.name,
    required this.source,
    required this.hasConsent,
  });

  final String number;
  final String name;
  final String source;
  final bool hasConsent;

  _ConsentRecord copyWith({
    String? number,
    String? name,
    String? source,
    bool? hasConsent,
  }) {
    return _ConsentRecord(
      number: number ?? this.number,
      name: name ?? this.name,
      source: source ?? this.source,
      hasConsent: hasConsent ?? this.hasConsent,
    );
  }
}
