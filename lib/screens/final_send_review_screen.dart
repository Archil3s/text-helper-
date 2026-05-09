import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FinalSendReviewScreen extends StatefulWidget {
  const FinalSendReviewScreen({super.key});

  @override
  State<FinalSendReviewScreen> createState() => _FinalSendReviewScreenState();
}

class _FinalSendReviewScreenState extends State<FinalSendReviewScreen> {
  bool _recipientConsentConfirmed = true;
  bool _messageReviewed = true;
  bool _unsubscribeIncluded = true;
  bool _auditTrailEnabled = true;
  bool _finalApproval = false;

  static const String _campaignName = 'NZ Reminder Campaign';
  static const String _message =
      'Hi, this is a reminder from Text Helper. Reply STOP to opt out.';

  static const List<String> _recipients = [
    '+64211234567',
    '+64275551234',
    '+64221234567',
  ];

  bool get _readyForSend {
    return _recipientConsentConfirmed &&
        _messageReviewed &&
        _unsubscribeIncluded &&
        _auditTrailEnabled &&
        _finalApproval;
  }

  int get _completedChecks {
    return [
      _recipientConsentConfirmed,
      _messageReviewed,
      _unsubscribeIncluded,
      _auditTrailEnabled,
      _finalApproval,
    ].where((value) => value).length;
  }

  void _showDisabledSendNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Send is still disabled. Add a real SMS provider only after compliance is finished.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _saveReviewSnapshot() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Final review snapshot saved locally.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _readyForSend
        ? 'Ready for future SMS integration'
        : 'Review required before SMS integration';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Final Send Review'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeroCard(
            completedChecks: _completedChecks,
            totalChecks: 5,
            statusText: statusText,
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Campaign'),
          const SizedBox(height: 12),
          const _CampaignCard(
            campaignName: _campaignName,
            message: _message,
            recipientCount: _recipients.length,
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Approved recipients'),
          const SizedBox(height: 12),
          ..._recipients.map((recipient) => _RecipientCard(number: recipient)),
          const SizedBox(height: 20),
          const _SectionTitle('Required review checks'),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: Column(
              children: [
                _CheckSwitch(
                  title: 'Consent confirmed',
                  subtitle: 'All recipients are approved for this campaign.',
                  value: _recipientConsentConfirmed,
                  onChanged: (value) {
                    setState(() => _recipientConsentConfirmed = value);
                  },
                ),
                const Divider(height: 24),
                _CheckSwitch(
                  title: 'Message reviewed',
                  subtitle: 'Final text content has been checked.',
                  value: _messageReviewed,
                  onChanged: (value) {
                    setState(() => _messageReviewed = value);
                  },
                ),
                const Divider(height: 24),
                _CheckSwitch(
                  title: 'Unsubscribe included',
                  subtitle: 'Message contains STOP opt-out wording.',
                  value: _unsubscribeIncluded,
                  onChanged: (value) {
                    setState(() => _unsubscribeIncluded = value);
                  },
                ),
                const Divider(height: 24),
                _CheckSwitch(
                  title: 'Audit trail enabled',
                  subtitle: 'Review action will be stored locally.',
                  value: _auditTrailEnabled,
                  onChanged: (value) {
                    setState(() => _auditTrailEnabled = value);
                  },
                ),
                const Divider(height: 24),
                _CheckSwitch(
                  title: 'Final approval',
                  subtitle: 'Explicit approval before future send integration.',
                  value: _finalApproval,
                  onChanged: (value) {
                    setState(() => _finalApproval = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saveReviewSnapshot,
            icon: const Icon(CupertinoIcons.doc_checkmark_fill),
            label: const Text('Save review snapshot'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showDisabledSendNotice,
            icon: const Icon(CupertinoIcons.paperplane_fill),
            label: Text(
              _readyForSend ? 'Send SMS disabled' : 'Send blocked',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.completedChecks,
    required this.totalChecks,
    required this.statusText,
  });

  final int completedChecks;
  final int totalChecks;
  final String statusText;

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
            CupertinoIcons.shield_lefthalf_fill,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Final Send Review',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$completedChecks/$totalChecks checks complete • $statusText',
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

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({
    required this.campaignName,
    required this.message,
    required this.recipientCount,
  });

  final String campaignName;
  final String message;
  final int recipientCount;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campaignName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$recipientCount approved recipients',
            style: const TextStyle(
              color: Color(0xFF0A84FF),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.check_mark_circled_solid,
            color: Color(0xFF16A34A),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF0A84FF),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Text(
            'Approved',
            style: TextStyle(
              color: Color(0xFF16A34A),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckSwitch extends StatelessWidget {
  const _CheckSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          value
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.xmark_circle_fill,
          color: value ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: CupertinoColors.secondaryLabel,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
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
