import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/nz_sms_recipient.dart';
import '../services/nz_recipient_store.dart';

class AndroidSmsIntentScreen extends StatefulWidget {
  const AndroidSmsIntentScreen({super.key});

  @override
  State<AndroidSmsIntentScreen> createState() => _AndroidSmsIntentScreenState();
}

class _AndroidSmsIntentScreenState extends State<AndroidSmsIntentScreen> {
  final NzRecipientStore _store = NzRecipientStore();

  final TextEditingController _messageController = TextEditingController(
    text: 'Hi, this is a test from Text Helper. Reply STOP to opt out.',
  );

  List<NzSmsRecipient> _recipients = <NzSmsRecipient>[];
  NzSmsRecipient? _selectedRecipient;

  bool _confirmConsent = true;
  bool _confirmMessage = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipients() async {
    final recipients = await _store.loadRecipients();

    if (!mounted) {
      return;
    }

    setState(() {
      _recipients = recipients;
      _selectedRecipient = recipients.isEmpty ? null : recipients.first;
      _isLoading = false;
    });
  }

  bool get _canOpenSms {
    final recipient = _selectedRecipient;

    if (recipient == null) {
      return false;
    }

    return recipient.consented &&
        _confirmConsent &&
        _confirmMessage &&
        _messageController.text.trim().isNotEmpty;
  }

  Future<void> _openSmsApp() async {
    final recipient = _selectedRecipient;
    final message = _messageController.text.trim();

    if (recipient == null || !_canOpenSms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Blocked. Select an approved contact, confirm consent, and review the message.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uri = Uri(
      scheme: 'sms',
      path: recipient.number,
      queryParameters: {'body': message},
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!mounted) {
      return;
    }

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Android Messages on this device.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _selectRecipient(NzSmsRecipient recipient) {
    setState(() => _selectedRecipient = recipient);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedRecipient;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Send SMS'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _loadRecipients,
            icon: const Icon(CupertinoIcons.refresh),
            tooltip: 'Reload contacts',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _HeroCard(
                  selected: selected,
                  canOpenSms: _canOpenSms,
                  count: _recipients.length,
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Choose contact'),
                const SizedBox(height: 12),
                if (_recipients.isEmpty)
                  const _EmptyContactsCard()
                else
                  ..._recipients.map(
                    (recipient) => _RecipientCard(
                      recipient: recipient,
                      isSelected: selected?.id == recipient.id,
                      onTap: () => _selectRecipient(recipient),
                    ),
                  ),
                const SizedBox(height: 20),
                const _SectionTitle('Message'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: TextField(
                    controller: _messageController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Write SMS message...',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Safety checks'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Column(
                    children: [
                      _CheckRow(
                        title: 'Consent confirmed',
                        subtitle: 'Only text people who agreed to receive it.',
                        value: _confirmConsent,
                        onChanged: (value) {
                          setState(() => _confirmConsent = value);
                        },
                      ),
                      const Divider(height: 24),
                      _CheckRow(
                        title: 'Message reviewed',
                        subtitle:
                            'Android Messages will open. You still tap Send there.',
                        value: _confirmMessage,
                        onChanged: (value) {
                          setState(() => _confirmMessage = value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _canOpenSms ? _openSmsApp : null,
                  icon: const Icon(CupertinoIcons.paperplane_fill),
                  label: Text(
                    selected == null
                        ? 'Select contact first'
                        : 'Text ${selected.name}',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _SafetyNote(),
              ],
            ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.selected,
    required this.canOpenSms,
    required this.count,
  });

  final NzSmsRecipient? selected;
  final bool canOpenSms;
  final int count;

  @override
  Widget build(BuildContext context) {
    final status = selected == null
        ? '$count contacts loaded'
        : canOpenSms
            ? 'Ready to text ${selected!.number}'
            : 'Selected: ${selected!.name}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.paperplane_fill,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Send SMS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  status,
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

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({
    required this.recipient,
    required this.isSelected,
    required this.onTap,
  });

  final NzSmsRecipient recipient;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBlocked = !recipient.consented;

    return GestureDetector(
      onTap: onTap,
      child: _SurfaceCard(
        borderColor: isSelected ? const Color(0xFF0A84FF) : null,
        child: Row(
          children: [
            Icon(
              isSelected
                  ? CupertinoIcons.check_mark_circled_solid
                  : isBlocked
                      ? CupertinoIcons.xmark_circle_fill
                      : CupertinoIcons.person_fill,
              color: isSelected
                  ? const Color(0xFF0A84FF)
                  : isBlocked
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF16A34A),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipient.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipient.number,
                    style: const TextStyle(
                      color: Color(0xFF0A84FF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipient.consented
                        ? 'Approved to text'
                        : 'Blocked: consent missing',
                    style: const TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Text(
                'Selected',
                style: TextStyle(
                  color: Color(0xFF0A84FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyContactsCard extends StatelessWidget {
  const _EmptyContactsCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Text(
        'No contacts found. Go to Contacts and add a test number first.',
        style: TextStyle(
          color: CupertinoColors.secondaryLabel,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
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

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

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
              'This app opens Android Messages with the selected contact and message prefilled. You review and tap Send in Android Messages.',
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
        borderRadius: BorderRadius.circular(22),
        border: borderColor == null
            ? null
            : Border.all(
                color: borderColor!,
                width: 2,
              ),
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
