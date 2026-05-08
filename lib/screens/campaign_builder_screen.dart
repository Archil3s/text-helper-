import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CampaignBuilderScreen extends StatefulWidget {
  const CampaignBuilderScreen({super.key});

  @override
  State<CampaignBuilderScreen> createState() => _CampaignBuilderScreenState();
}

class _CampaignBuilderScreenState extends State<CampaignBuilderScreen> {
  final TextEditingController _campaignNameController = TextEditingController(
    text: 'NZ Reminder Campaign',
  );

  final TextEditingController _messageController = TextEditingController(
    text: 'Hi, this is a reminder from Text Helper. Please reply STOP to opt out.',
  );

  bool _requireConsent = true;
  bool _includeUnsubscribe = true;
  bool _safetyCheckPassed = false;

  final List<String> _validNzNumbers = const [
    '+64211234567',
    '+64275551234',
    '+64221234567',
  ];

  @override
  void dispose() {
    _campaignNameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String get _finalMessage {
    final message = _messageController.text.trim();

    if (!_includeUnsubscribe) {
      return message;
    }

    if (message.toLowerCase().contains('stop')) {
      return message;
    }

    return '$message Reply STOP to opt out.';
  }

  void _runSafetyCheck() {
    final hasCampaignName = _campaignNameController.text.trim().isNotEmpty;
    final hasMessage = _messageController.text.trim().isNotEmpty;
    final hasRecipients = _validNzNumbers.isNotEmpty;
    final hasUnsubscribe = !_includeUnsubscribe ||
        _finalMessage.toLowerCase().contains('stop');

    final passed = hasCampaignName &&
        hasMessage &&
        hasRecipients &&
        _requireConsent &&
        hasUnsubscribe;

    setState(() => _safetyCheckPassed = passed);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          passed
              ? 'Campaign safety check passed. Sending is still disabled.'
              : 'Campaign needs a name, message, recipients, consent, and unsubscribe text.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _saveDraft() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Campaign draft saved locally in preview mode.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPreview = _campaignNameController.text.trim().isNotEmpty &&
        _messageController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Campaign Builder'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeroCard(
            recipientCount: _validNzNumbers.length,
            safetyCheckPassed: _safetyCheckPassed,
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Campaign details'),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: Column(
              children: [
                TextField(
                  controller: _campaignNameController,
                  decoration: InputDecoration(
                    labelText: 'Campaign name',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    hintText: 'Write your text message...',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Compliance checks'),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: Column(
              children: [
                _SwitchRow(
                  title: 'Require consent',
                  subtitle: 'Only send to recipients who have opted in.',
                  value: _requireConsent,
                  onChanged: (value) {
                    setState(() {
                      _requireConsent = value;
                      _safetyCheckPassed = false;
                    });
                  },
                ),
                const Divider(height: 24),
                _SwitchRow(
                  title: 'Include unsubscribe text',
                  subtitle: 'Add STOP opt-out wording to the message.',
                  value: _includeUnsubscribe,
                  onChanged: (value) {
                    setState(() {
                      _includeUnsubscribe = value;
                      _safetyCheckPassed = false;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Recipient preview'),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_validNzNumbers.length} validated NZ recipients',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ..._validNzNumbers.map(
                  (number) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.check_mark_circled_solid,
                          color: Color(0xFF16A34A),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          number,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Final preview'),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: canPreview
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _campaignNameController.text.trim(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _finalMessage,
                        style: const TextStyle(
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _safetyCheckPassed
                            ? 'Safety check passed. Sending remains disabled.'
                            : 'Run safety check before final send integration.',
                        style: TextStyle(
                          color: _safetyCheckPassed
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFF97316),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Add a campaign name and message to preview.',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _runSafetyCheck,
            icon: const Icon(CupertinoIcons.shield_fill),
            label: const Text('Run campaign safety check'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saveDraft,
            icon: const Icon(CupertinoIcons.tray_arrow_down_fill),
            label: const Text('Save campaign draft'),
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
    required this.recipientCount,
    required this.safetyCheckPassed,
  });

  final int recipientCount;
  final bool safetyCheckPassed;

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
            CupertinoIcons.chat_bubble_2_fill,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Campaign Builder',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$recipientCount NZ recipients • ${safetyCheckPassed ? 'safety passed' : 'safety pending'}',
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

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
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
        const Icon(
          CupertinoIcons.check_mark_circled_solid,
          color: Color(0xFF0A84FF),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
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
