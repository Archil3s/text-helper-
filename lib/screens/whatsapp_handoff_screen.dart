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

class _WhatsAppTemplate {
  const _WhatsAppTemplate({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}

class _WhatsAppHandoffScreenState extends State<WhatsAppHandoffScreen> {
  static const List<_WhatsAppTemplate> _templates = [
    _WhatsAppTemplate(
      title: 'Appointment reminder',
      message:
          'Hi {name}, this is a reminder about your appointment. Please reply if you need to change it.',
    ),
    _WhatsAppTemplate(
      title: 'Follow up',
      message:
          'Hi {name}, just following up on my previous message. Let me know when you have a chance.',
    ),
    _WhatsAppTemplate(
      title: 'Confirmation',
      message:
          'Hi {name}, this confirms your booking. Please reply if anything changes.',
    ),
    _WhatsAppTemplate(
      title: 'Running late',
      message:
          'Hi {name}, I am running a little late and will update you as soon as possible.',
    ),
  ];

  final NzRecipientStore _recipientStore = NzRecipientStore();
  final SendLogStore _sendLogStore = SendLogStore();
  final MessageTimelineService _timelineService = MessageTimelineService();
  final WhatsAppHandoffService _handoffService = WhatsAppHandoffService();

  final TextEditingController _messageController = TextEditingController();

  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];
  NzSmsRecipient? _selectedContact;

  bool _loading = true;
  bool _opening = false;
  bool _whatsAppInstalled = false;

  String _status =
      'Select an approved contact, choose a template, then open WhatsApp. You will press Send manually inside WhatsApp.';

  @override
  void initState() {
    super.initState();
    _loadScreen();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadScreen() async {
    final contacts = await _recipientStore.loadRecipients();
    final approved = contacts.where((contact) => contact.consented).toList();
    final installed = await _handoffService.isWhatsAppInstalled();

    if (!mounted) {
      return;
    }

    final selected = approved.isEmpty ? null : approved.first;

    setState(() {
      _contacts = approved;
      _selectedContact = selected;
      _whatsAppInstalled = installed;
      _loading = false;
    });

    if (selected != null && _messageController.text.trim().isEmpty) {
      _applyTemplate(_templates.first);
    }
  }

  String _renderTemplate(_WhatsAppTemplate template) {
    final contact = _selectedContact;
    final name = contact == null || contact.name.trim().isEmpty
        ? 'there'
        : contact.name.trim();

    return template.message.replaceAll('{name}', name);
  }

  void _applyTemplate(_WhatsAppTemplate template) {
    _messageController.text = _renderTemplate(template);
    setState(() {
      _status =
          'Template loaded: ${template.title}. Review before opening WhatsApp.';
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

    if (contact == null) {
      _showSnack('Add or select an approved contact first.');
      return;
    }

    if (message.isEmpty) {
      _showSnack('Write a WhatsApp message first.');
      return;
    }

    if (!_whatsAppInstalled) {
      _showSnack('WhatsApp was not detected. Install WhatsApp and try again.');
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
      detail: 'Manual WhatsApp handoff started.',
    );

    final opened = await _handoffService.launchComposer(
      phoneNumber: contact.number,
      message: message,
    );

    await _recordHandoff(
      id: handoffId,
      contact: contact,
      message: message,
      status: opened ? 'whatsapp_handoff_opened' : 'whatsapp_handoff_failed',
      detail: opened
          ? 'WhatsApp composer opened. User must press Send manually.'
          : 'Could not open WhatsApp composer.',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _opening = false;
      _status = opened
          ? 'WhatsApp opened. Press Send manually inside WhatsApp.'
          : 'Could not open WhatsApp. Check the app install and phone number format.';
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool get _canOpen {
    return !_opening &&
        _whatsAppInstalled &&
        _selectedContact != null &&
        _messageController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final contact = _selectedContact;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('WhatsApp Manual Handoff'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _opening ? null : _loadScreen,
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
                const SizedBox(height: 16),
                _InstallStatusCard(installed: _whatsAppInstalled),
                const SizedBox(height: 12),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                const _PolicyCard(),
                const SizedBox(height: 20),
                const _SectionTitle('Approved contact'),
                const SizedBox(height: 12),
                if (_contacts.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No approved contacts found. Add a contact and mark consent as approved first.',
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
                const _SectionTitle('Templates'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _templates
                      .map(
                        (template) => ActionChip(
                          label: Text(template.title),
                          onPressed: _opening
                              ? null
                              : () {
                                  _applyTemplate(template);
                                },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Message draft'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: TextField(
                    controller: _messageController,
                    maxLines: 6,
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
                    _opening ? 'Opening...' : 'Open WhatsApp Draft',
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
      decoration: const BoxDecoration(
        color: Color(0xFF075E54),
        borderRadius: BorderRadius.all(Radius.circular(32)),
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
            'WhatsApp Manual Handoff',
            style: TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Choose a consented contact, load a template, open WhatsApp, then press Send manually.',
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

class _InstallStatusCard extends StatelessWidget {
  const _InstallStatusCard({required this.installed});

  final bool installed;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          Icon(
            installed
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.xmark_circle_fill,
            color:
                installed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              installed
                  ? 'WhatsApp detected on this phone.'
                  : 'WhatsApp was not detected on this phone.',
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
                  const SizedBox(height: 4),
                  const Text(
                    'Consent approved',
                    style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
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
              'Manual handoff only. Text Helper prepares the draft and opens WhatsApp. It does not tap Send or bypass WhatsApp controls.',
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
