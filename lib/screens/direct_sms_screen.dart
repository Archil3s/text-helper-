import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/nz_sms_recipient.dart';
import '../models/send_log_entry.dart';
import '../services/message_timeline_service.dart';
import '../services/native_sms_service.dart';
import '../services/nz_recipient_store.dart';
import '../services/send_log_store.dart';
import 'recurring_texts_screen.dart';

class DirectSmsScreen extends StatefulWidget {
  const DirectSmsScreen({super.key});

  @override
  State<DirectSmsScreen> createState() => _DirectSmsScreenState();
}

class _DirectSmsScreenState extends State<DirectSmsScreen> {
  final NativeSmsService _smsService = NativeSmsService();
  final NzRecipientStore _store = NzRecipientStore();
  final SendLogStore _sendLogStore = SendLogStore();
  final MessageTimelineService _timelineService = MessageTimelineService();

  final TextEditingController _messageController = TextEditingController(
    text: 'Test from Text Helper.',
  );

  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];
  NzSmsRecipient? _selectedContact;

  bool _isLoading = true;
  bool _isSending = false;

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
    final approved = contacts.where((contact) => contact.consented).toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _contacts = approved;
      _selectedContact = approved.isEmpty ? null : approved.first;
      _isLoading = false;
    });
  }

  bool get _canSend {
    return !_isSending &&
        _selectedContact != null &&
        _messageController.text.trim().isNotEmpty;
  }

  Future<void> _recordSendLog({
    required String id,
    required NzSmsRecipient contact,
    required String message,
    required String status,
    String? detail,
  }) async {
    final log = SendLogEntry(
      id: id,
      phoneNumber: contact.number,
      message: message,
      createdAt: DateTime.now(),
      status: status,
      errorMessage: detail,
      reminderId: id,
    );

    await _sendLogStore.addLog(log);
    await _timelineService.logFromSendLog(log);
  }

  Future<void> _sendNow() async {
    final contact = _selectedContact;
    final message = _messageController.text.trim();

    if (contact == null || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Select an approved contact and enter a message first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final sendId =
        'direct-${DateTime.now().microsecondsSinceEpoch}-${contact.id}';

    setState(() => _isSending = true);

    await _recordSendLog(
      id: sendId,
      contact: contact,
      message: message,
      status: 'attempting',
      detail: 'Direct Send attempt started.',
    );

    try {
      await _smsService.sendSms(
        phoneNumber: contact.number,
        message: message,
        reminderId: sendId,
        contactId: contact.id,
      );

      await _recordSendLog(
        id: sendId,
        contact: contact,
        message: message,
        status: 'sent_to_android',
        detail:
            'Sent to Android SMS service. This is not a carrier delivery receipt.',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SMS sent to Android SMS service for ${contact.name}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      await _recordSendLog(
        id: sendId,
        contact: contact,
        message: message,
        status: 'failed',
        detail: error.toString(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Send failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = _selectedContact;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Direct Send'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _loadContacts,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _HeroCard(contact: contact),
                const SizedBox(height: 20),
                const _SectionTitle('Selected number'),
                const SizedBox(height: 12),
                if (_contacts.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No approved contacts found. Add your test number in Contacts first.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ..._contacts.map(
                    (item) => _ContactCard(
                      contact: item,
                      selected: item.id == contact?.id,
                      onTap: () {
                        setState(() => _selectedContact = item);
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                const _SectionTitle('Message'),
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
                FilledButton.icon(
                  onPressed: _canSend ? _sendNow : null,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.paperplane_fill),
                  label: Text(_isSending ? 'Sending...' : 'SEND NOW'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(62),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _SafetyNote(),
                const SizedBox(height: 12),
                const _StatusNote(),
              ],
            ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.contact});

  final NzSmsRecipient? contact;

  @override
  Widget build(BuildContext context) {
    final label = contact == null
        ? 'No number selected'
        : '${contact!.name} - ${contact!.number}';

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
                  'One Button Send',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
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

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.selected,
    required this.onTap,
  });

  final NzSmsRecipient contact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _SurfaceCard(
        borderColor: selected ? const Color(0xFF0A84FF) : null,
        child: Row(
          children: [
            Icon(
              selected
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.person_fill,
              color:
                  selected ? const Color(0xFF0A84FF) : const Color(0xFF16A34A),
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
            if (selected)
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

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: Color(0xFFF97316),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'SEND NOW sends a real SMS directly from this Android phone. Test only with your own number first. Carrier charges may apply.',
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

class _StatusNote extends StatelessWidget {
  const _StatusNote();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.check_mark_circled_solid,
            color: Color(0xFF16A34A),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Send History and Message Timeline record the attempt, success, or failure. Sent to Android means Android accepted the SMS request. Delivered appears only when Android reports a delivery receipt.',
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
      ),
      child: child,
    );
  }
}
