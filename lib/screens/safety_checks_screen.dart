import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SafetyChecksScreen extends StatefulWidget {
  const SafetyChecksScreen({super.key});

  @override
  State<SafetyChecksScreen> createState() => _SafetyChecksScreenState();
}

class _SafetyChecksScreenState extends State<SafetyChecksScreen> {
  bool _recipientReview = true;
  bool _messagePreview = true;
  bool _finalConfirmation = true;

  int get _enabledChecks {
    return [_recipientReview, _messagePreview, _finalConfirmation]
        .where((value) => value)
        .length;
  }

  void _runCheck() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Local safety check passed. No SMS was sent.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Safety Checks'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeroCard(enabledChecks: _enabledChecks),
          const SizedBox(height: 20),
          _SurfaceCard(
            child: Column(
              children: [
                _SwitchRow(
                  title: 'Recipient review',
                  subtitle: 'Show selected group before any send action.',
                  value: _recipientReview,
                  onChanged: (value) =>
                      setState(() => _recipientReview = value),
                ),
                const Divider(height: 24),
                _SwitchRow(
                  title: 'Message preview',
                  subtitle: 'Display final message before confirmation.',
                  value: _messagePreview,
                  onChanged: (value) => setState(() => _messagePreview = value),
                ),
                const Divider(height: 24),
                _SwitchRow(
                  title: 'Final confirmation',
                  subtitle: 'Require explicit approval before sending.',
                  value: _finalConfirmation,
                  onChanged: (value) =>
                      setState(() => _finalConfirmation = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _runCheck,
            icon: const Icon(CupertinoIcons.check_mark),
            label: const Text('Run local safety check'),
            style: FilledButton.styleFrom(
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
  const _HeroCard({required this.enabledChecks});

  final int enabledChecks;

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
          const Icon(CupertinoIcons.shield_fill, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '$enabledChecks safety checks active',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
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
