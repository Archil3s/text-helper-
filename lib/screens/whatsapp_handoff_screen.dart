import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/nz_sms_recipient.dart';
import '../models/send_log_entry.dart';
import '../services/message_timeline_service.dart';
import '../services/nz_recipient_store.dart';
import '../services/send_log_store.dart';
import '../services/whatsapp_handoff_service.dart';

class WhatsAppHandoffScreen extends StatefulWidget {
  const WhatsAppHandoffScreen({super.key});

  @override
  State<WhatsAppHandoffScreen> createState() => _WhatsAppHandoffScreenState();
}

class _WhatsAppHandoffScreenState extends State<WhatsAppHandoffScreen> {
  final NzRecipientStore _recipientStore = NzRecipientStore();
  final SendLogStore _sendLogStore = SendLogStore();
  final MessageTimelineService _timelineService = MessageTimelineService();
  final WhatsAppHandoffService _handoffService = WhatsAppHandoffService();

  final TextEditingController _messageController = TextEditingController(
    text: 'Hi, this is a WhatsApp handoff draft from Text Helper.',
  );

  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];
  NzSmsRecipient? _selectedContact;

  bool _loading = true;
  bool _opening = false;
  String _status =
      'Select an approved contact, write a message, then open WhatsApp. You must press Send manually in WhatsApp.';

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
    final contacts = await _recipientStore.loadRecipients();
    final approved = contacts.where((contact) => contact.consented).toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _contacts = approved;
      _selectedContact = approved.isEmpty ? null : approved.first;
      _loading = false;
    });
  }

  Future<void> _recordHandoff({
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

  Future<void> _openWhatsApp() async {
    final contact = _selectedContact;
    final message = _messageController.text.trim();

    if (contact == null || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an approved contact and enter a message.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final handoffId =
        'whatsapp-handoff-${DateTime.now().microsecondsSinceEpoch}-${contact.id}';

    setState(() {
      _opening = true;
      _status = 'Opening WhatsApp composer...';
    });

    await _recordHandoff(
      id: handoffId,
      contact: contact,
      message: message,
      status: 'whatsapp_handoff_attempting',
      detail: 'WhatsApp handoff started. This is not an automated send.',
    );

    try {
      final opened = await _handoffService.launchComposer(
        phoneNumber: contact.number,
        message: message,
      );

      await _recordHandoff(
        id: handoffId,
        contact: contact,
        message: message,
        status: opened ? 'whatsapp_handoff' : 'whatsapp_handoff_failed',
        detail: opened
            ? 'WhatsApp composer opened. User must press Send manually in WhatsApp.'
            : 'Could not open WhatsApp composer on this device.',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _opening = false;
        _status = opened
            ? 'WhatsApp composer opened. Press Send manually in WhatsApp.'
            : 'Could not open WhatsApp. Check that WhatsApp is installed and the number uses international format.';
      });
    } catch (error) {
      await _recordHandoff(
        id: handoffId,
        contact: contact,
        message: message,
        status: 'whatsapp_handoff_failed',
        detail: error.toString(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _opening = false;
        _status = 'WhatsApp handoff failed: $error';
      });
    }
  }

  bool get _canOpen {
    return !_opening &&
        _selectedContact != null &&
        _messageController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final contact = _selectedContact;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('WhatsApp Handoff'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _opening ? null : _loadContacts,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const _HeroCard(),
                const SizedBox(height: 20),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                const _PolicyCard(),
                const SizedBox(height: 20),
                const _SectionTitle('Approved contact'),
                const SizedBox(height: 12),
                if (_contacts.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No approved contacts found. Add a consented contact first.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ..._contacts.map(
                    (item) => _ContactCard(
                      contact: item,
                      selected: item.id == contact?.id,
                      onTap: _opening
                          ? null
                          : () {
                              setState(() => _selectedContact = item);
                            },
                    ),
                  ),
                const SizedBox(height: 20),
                const _SectionTitle('Message draft'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: TextField(
                    controller: _messageController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Write WhatsApp draft...',
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
                  onPressed: _canOpen ? _openWhatsApp : null,
                  icon: _opening
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.arrow_up_right_square_fill),
                  label: Text(
                    _opening ? 'Opening...' : 'Open WhatsApp Composer',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(62),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF075E54),
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.chat_bubble_2_fill,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 16),
          Text(
            'WhatsApp Handoff',
            style: TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Open WhatsApp with a prefilled draft. Text Helper does not auto-send WhatsApp messages.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.35,
              fontWeight: FontWeight.w700,
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
  final VoidCallback? onTap;

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
                      fontWeight: FontWeight.w900,
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
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard();

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
              'This is a manual handoff. Text Helper opens WhatsApp with a draft, but the user must press Send in WhatsApp. No delivery, background scheduling, or auto-send is claimed.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
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
