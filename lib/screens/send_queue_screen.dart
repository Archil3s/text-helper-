import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/nz_sms_recipient.dart';
import '../services/nz_recipient_store.dart';

class SendQueueScreen extends StatefulWidget {
  const SendQueueScreen({super.key});

  @override
  State<SendQueueScreen> createState() => _SendQueueScreenState();
}

class _SendQueueScreenState extends State<SendQueueScreen> {
  final NzRecipientStore _store = NzRecipientStore();

  final TextEditingController _messageController = TextEditingController(
    text: 'Hi, this is a test from Text Helper. Reply STOP to opt out.',
  );

  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];
  final Set<String> _selectedIds = <String>{};
  final Set<String> _sentIds = <String>{};
  final Set<String> _skippedIds = <String>{};

  bool _isLoading = true;
  bool _confirmConsent = true;
  bool _confirmMessage = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final contacts = await _store.loadRecipients();

    if (!mounted) {
      return;
    }

    setState(() {
      _contacts = contacts;
      _selectedIds
        ..clear()
        ..addAll(contacts
            .where((contact) => contact.consented)
            .map((contact) => contact.id));
      _sentIds.clear();
      _skippedIds.clear();
      _isLoading = false;
    });
  }

  List<NzSmsRecipient> get _selectedContacts {
    return _contacts
        .where((contact) => _selectedIds.contains(contact.id))
        .toList();
  }

  List<NzSmsRecipient> get _pendingContacts {
    return _selectedContacts
        .where((contact) =>
            !_sentIds.contains(contact.id) && !_skippedIds.contains(contact.id))
        .toList();
  }

  NzSmsRecipient? get _nextContact {
    final pending = _pendingContacts;
    if (pending.isEmpty) {
      return null;
    }

    return pending.first;
  }

  bool get _canOpenNext {
    return _nextContact != null &&
        _nextContact!.consented &&
        _confirmConsent &&
        _confirmMessage &&
        _messageController.text.trim().isNotEmpty;
  }

  void _toggleContact(NzSmsRecipient contact, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(contact.id);
        _skippedIds.remove(contact.id);
      } else {
        _selectedIds.remove(contact.id);
        _sentIds.remove(contact.id);
        _skippedIds.remove(contact.id);
      }
    });
  }

  Future<void> _openNextSms() async {
    final contact = _nextContact;
    final message = _messageController.text.trim();

    if (contact == null || !_canOpenNext) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Queue blocked. Select approved contacts and review the message.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uri = Uri(
      scheme: 'sms',
      path: contact.number,
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
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Opened Android Messages for ${contact.name}. After sending, return and tap Mark sent.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _markNextSent() {
    final contact = _nextContact;

    if (contact == null) {
      return;
    }

    setState(() {
      _sentIds.add(contact.id);
      _skippedIds.remove(contact.id);
    });
  }

  void _skipNext() {
    final contact = _nextContact;

    if (contact == null) {
      return;
    }

    setState(() {
      _skippedIds.add(contact.id);
    });
  }

  void _resetQueue() {
    setState(() {
      _sentIds.clear();
      _skippedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final nextContact = _nextContact;
    final selectedCount = _selectedContacts.length;
    final sentCount = _sentIds.length;
    final pendingCount = _pendingContacts.length;
    final skippedCount = _skippedIds.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Send Queue'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _loadContacts,
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
                  selectedCount: selectedCount,
                  pendingCount: pendingCount,
                  sentCount: sentCount,
                  skippedCount: skippedCount,
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Message for queue'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: TextField(
                    controller: _messageController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Write message...',
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
                const _SectionTitle('Next in queue'),
                const SizedBox(height: 12),
                if (nextContact == null)
                  const _EmptyQueueCard()
                else
                  _NextContactCard(contact: nextContact),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _canOpenNext ? _openNextSms : null,
                  icon: const Icon(CupertinoIcons.paperplane_fill),
                  label: Text(
                    nextContact == null
                        ? 'Queue complete'
                        : 'Open SMS for ${nextContact.name}',
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: nextContact == null ? null : _markNextSent,
                        icon:
                            const Icon(CupertinoIcons.check_mark_circled_solid),
                        label: const Text('Mark sent'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: nextContact == null ? null : _skipNext,
                        icon: const Icon(CupertinoIcons.forward_fill),
                        label: const Text('Skip'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _resetQueue,
                  icon: const Icon(CupertinoIcons.arrow_counterclockwise),
                  label: const Text('Reset queue progress'),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Safety checks'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Column(
                    children: [
                      _CheckRow(
                        title: 'Consent confirmed',
                        subtitle:
                            'Only approved contacts are included by default.',
                        value: _confirmConsent,
                        onChanged: (value) =>
                            setState(() => _confirmConsent = value),
                      ),
                      const Divider(height: 24),
                      _CheckRow(
                        title: 'Message reviewed',
                        subtitle:
                            'Android Messages opens for each contact. You still tap Send.',
                        value: _confirmMessage,
                        onChanged: (value) =>
                            setState(() => _confirmMessage = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Contacts in queue'),
                const SizedBox(height: 12),
                if (_contacts.isEmpty)
                  const _NoContactsCard()
                else
                  ..._contacts.map(
                    (contact) => _QueueContactCard(
                      contact: contact,
                      selected: _selectedIds.contains(contact.id),
                      sent: _sentIds.contains(contact.id),
                      skipped: _skippedIds.contains(contact.id),
                      onChanged: (value) => _toggleContact(contact, value),
                    ),
                  ),
                const SizedBox(height: 20),
                const _SafetyNote(),
              ],
            ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.selectedCount,
    required this.pendingCount,
    required this.sentCount,
    required this.skippedCount,
  });

  final int selectedCount;
  final int pendingCount;
  final int sentCount;
  final int skippedCount;

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
            CupertinoIcons.list_bullet_below_rectangle,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Send Queue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$pendingCount pending - $sentCount sent - $skippedCount skipped - $selectedCount selected',
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

class _NextContactCard extends StatelessWidget {
  const _NextContactCard({required this.contact});

  final NzSmsRecipient contact;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      borderColor: const Color(0xFF0A84FF),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.person_crop_circle_badge_checkmark,
            color: Color(0xFF0A84FF),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.number,
                  style: const TextStyle(
                    color: Color(0xFF0A84FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'Next',
            style: TextStyle(
              color: Color(0xFF0A84FF),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueContactCard extends StatelessWidget {
  const _QueueContactCard({
    required this.contact,
    required this.selected,
    required this.sent,
    required this.skipped,
    required this.onChanged,
  });

  final NzSmsRecipient contact;
  final bool selected;
  final bool sent;
  final bool skipped;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final blocked = !contact.consented;

    String status;
    Color statusColor;

    if (blocked) {
      status = 'Blocked';
      statusColor = const Color(0xFFEF4444);
    } else if (sent) {
      status = 'Sent';
      statusColor = const Color(0xFF16A34A);
    } else if (skipped) {
      status = 'Skipped';
      statusColor = const Color(0xFFF97316);
    } else if (selected) {
      status = 'Queued';
      statusColor = const Color(0xFF0A84FF);
    } else {
      status = 'Off';
      statusColor = CupertinoColors.secondaryLabel;
    }

    return _SurfaceCard(
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: blocked ? null : (value) => onChanged(value ?? false),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.number,
                  style: const TextStyle(
                    color: Color(0xFF0A84FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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

class _EmptyQueueCard extends StatelessWidget {
  const _EmptyQueueCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Text(
        'Queue complete. Select more contacts or reset queue progress.',
        style: TextStyle(
          color: CupertinoColors.secondaryLabel,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NoContactsCard extends StatelessWidget {
  const _NoContactsCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Text(
        'No contacts found. Add test numbers in Contacts first.',
        style: TextStyle(
          color: CupertinoColors.secondaryLabel,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
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
              'This queue opens Android Messages one contact at a time. It does not silently bulk-send. After sending in Android Messages, return here and tap Mark sent.',
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
