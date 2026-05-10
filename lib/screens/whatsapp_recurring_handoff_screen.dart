import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/nz_sms_recipient.dart';
import '../models/send_log_entry.dart';
import '../models/whatsapp_recurring_handoff.dart';
import '../services/message_timeline_service.dart';
import '../services/nz_recipient_store.dart';
import '../services/send_log_store.dart';
import '../services/whatsapp_handoff_service.dart';
import '../services/whatsapp_recurring_handoff_store.dart';

class WhatsAppRecurringHandoffScreen extends StatefulWidget {
  const WhatsAppRecurringHandoffScreen({super.key});

  @override
  State<WhatsAppRecurringHandoffScreen> createState() =>
      _WhatsAppRecurringHandoffScreenState();
}

class _WhatsAppTemplate {
  const _WhatsAppTemplate({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}

class _WhatsAppRecurringHandoffScreenState
    extends State<WhatsAppRecurringHandoffScreen> {
  static const List<_WhatsAppTemplate> _templates = [
    _WhatsAppTemplate(
      title: 'Appointment reminder',
      message:
          'Hi {name}, this is your recurring appointment reminder. Please reply if you need to change it.',
    ),
    _WhatsAppTemplate(
      title: 'Daily check in',
      message:
          'Hi {name}, this is your daily check in reminder. Please reply when you can.',
    ),
    _WhatsAppTemplate(
      title: 'Weekly follow up',
      message:
          'Hi {name}, this is your weekly follow up message. Let me know if anything has changed.',
    ),
    _WhatsAppTemplate(
      title: 'Monthly reminder',
      message:
          'Hi {name}, this is your monthly reminder. Please reply if you need help.',
    ),
  ];

  final NzRecipientStore _recipientStore = NzRecipientStore();
  final WhatsAppRecurringHandoffStore _recurringStore =
      WhatsAppRecurringHandoffStore();
  final WhatsAppHandoffService _handoffService = WhatsAppHandoffService();
  final SendLogStore _sendLogStore = SendLogStore();
  final MessageTimelineService _timelineService = MessageTimelineService();

  final TextEditingController _messageController = TextEditingController();

  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];
  List<WhatsAppRecurringHandoff> _items = <WhatsAppRecurringHandoff>[];

  NzSmsRecipient? _selectedContact;
  WhatsAppRepeatRule _repeatRule = WhatsAppRepeatRule.daily;

  bool _loading = true;
  bool _opening = false;
  bool _whatsAppInstalled = false;

  String _status =
      'Create a recurring WhatsApp handoff. When it is due, open the prepared WhatsApp draft and press Send manually.';

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
    final approvedContacts =
        contacts.where((contact) => contact.consented).toList();
    final items = await _recurringStore.loadItems();
    final installed = await _handoffService.isWhatsAppInstalled();

    if (!mounted) {
      return;
    }

    setState(() {
      _contacts = approvedContacts;
      _selectedContact =
          approvedContacts.isEmpty ? null : approvedContacts.first;
      _items = items;
      _whatsAppInstalled = installed;
      _loading = false;
    });

    if (_selectedContact != null && _messageController.text.trim().isEmpty) {
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
      _status = 'Template loaded: ${template.title}.';
    });
  }

  Future<void> _createRecurringHandoff() async {
    final contact = _selectedContact;
    final message = _messageController.text.trim();

    if (contact == null) {
      _showSnack('Add or select an approved contact first.');
      return;
    }

    if (message.isEmpty) {
      _showSnack('Write a message first.');
      return;
    }

    final now = DateTime.now();
    final item = WhatsAppRecurringHandoff(
      id: 'whatsapp-recurring-${now.microsecondsSinceEpoch}-${contact.id}',
      contactId: contact.id,
      contactName: contact.name,
      phoneNumber: contact.number,
      message: message,
      repeatRule: _repeatRule,
      nextDueAt: now,
      createdAt: now,
    );

    await _recurringStore.addItem(item);
    await _loadScreen();

    if (!mounted) {
      return;
    }

    setState(() {
      _status =
          'Recurring WhatsApp handoff created. It is due now. Open the draft when ready.';
    });
  }

  Future<void> _openDueDraft(WhatsAppRecurringHandoff item) async {
    if (!_whatsAppInstalled) {
      _showSnack('WhatsApp was not detected. Install WhatsApp and try again.');
      return;
    }

    setState(() {
      _opening = true;
      _status = 'Opening WhatsApp draft for ${item.contactName}...';
    });

    final eventId =
        'whatsapp-recurring-open-${DateTime.now().microsecondsSinceEpoch}';

    await _recordLog(
      id: eventId,
      item: item,
      status: 'whatsapp_recurring_opening',
      detail:
          'Recurring WhatsApp handoff opening. User must press Send manually.',
    );

    final opened = await _handoffService.launchComposer(
      phoneNumber: item.phoneNumber,
      message: item.message,
    );

    if (opened) {
      await _recordLog(
        id: eventId,
        item: item,
        status: 'whatsapp_recurring_opened',
        detail:
            'WhatsApp draft opened. User must press Send manually. Next occurrence scheduled.',
      );

      final updated = item.copyWith(
        lastOpenedAt: DateTime.now(),
        nextDueAt: item.nextOccurrence,
        openCount: item.openCount + 1,
      );

      await _recurringStore.updateItem(updated);
    } else {
      await _recordLog(
        id: eventId,
        item: item,
        status: 'whatsapp_recurring_failed',
        detail: 'Could not open WhatsApp draft.',
      );
    }

    await _loadScreen();

    if (!mounted) {
      return;
    }

    setState(() {
      _opening = false;
      _status = opened
          ? 'WhatsApp opened. Press Send manually. Next occurrence scheduled.'
          : 'Could not open WhatsApp draft.';
    });
  }

  Future<void> _skipOccurrence(WhatsAppRecurringHandoff item) async {
    final updated = item.copyWith(nextDueAt: item.nextOccurrence);
    await _recurringStore.updateItem(updated);
    await _loadScreen();

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Skipped this occurrence for ${item.contactName}.';
    });
  }

  Future<void> _toggleEnabled(WhatsAppRecurringHandoff item) async {
    final updated = item.copyWith(enabled: !item.enabled);
    await _recurringStore.updateItem(updated);
    await _loadScreen();

    if (!mounted) {
      return;
    }

    setState(() {
      _status = updated.enabled
          ? 'Recurring handoff enabled.'
          : 'Recurring handoff disabled.';
    });
  }

  Future<void> _deleteItem(WhatsAppRecurringHandoff item) async {
    await _recurringStore.deleteItem(item.id);
    await _loadScreen();

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Deleted recurring handoff for ${item.contactName}.';
    });
  }

  Future<void> _recordLog({
    required String id,
    required WhatsAppRecurringHandoff item,
    required String status,
    required String detail,
  }) async {
    final log = SendLogEntry(
      id: id,
      phoneNumber: item.phoneNumber,
      message: item.message,
      createdAt: DateTime.now(),
      status: status,
      errorMessage: detail,
      reminderId: item.id,
    );

    await _sendLogStore.addLog(log);
    await _timelineService.logFromSendLog(log);
  }

  String _formatDate(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day}/${value.month}/${value.year} $hour:$minute';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dueItems = _items.where((item) => item.isDue).toList();
    final scheduledItems = _items.where((item) => !item.isDue).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Recurring WhatsApp'),
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
                const _SectionTitle('Create recurring handoff'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_contacts.isEmpty)
                        const Text(
                          'No approved contacts found. Add a consented contact first.',
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        DropdownButtonFormField<NzSmsRecipient>(
                          value: _selectedContact,
                          decoration: const InputDecoration(
                            labelText: 'Approved contact',
                          ),
                          items: _contacts
                              .map(
                                (contact) => DropdownMenuItem<NzSmsRecipient>(
                                  value: contact,
                                  child: Text(
                                      '${contact.name} - ${contact.number}'),
                                ),
                              )
                              .toList(),
                          onChanged: _opening
                              ? null
                              : (value) {
                                  setState(() => _selectedContact = value);
                                },
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<WhatsAppRepeatRule>(
                        value: _repeatRule,
                        decoration: const InputDecoration(
                          labelText: 'Repeat',
                        ),
                        items: WhatsAppRepeatRule.values
                            .map(
                              (rule) => DropdownMenuItem<WhatsAppRepeatRule>(
                                value: rule,
                                child: Text(rule.label),
                              ),
                            )
                            .toList(),
                        onChanged: _opening
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }

                                setState(() => _repeatRule = value);
                              },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Templates',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
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
                      const SizedBox(height: 16),
                      TextField(
                        controller: _messageController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Message draft',
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
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _opening ? null : _createRecurringHandoff,
                        icon: const Icon(CupertinoIcons.plus_circle_fill),
                        label: const Text('Create Recurring Handoff'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionTitle('Due now (${dueItems.length})'),
                const SizedBox(height: 12),
                if (dueItems.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No WhatsApp handoffs are due right now.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ...dueItems.map(
                    (item) => _RecurringCard(
                      item: item,
                      due: true,
                      formattedDate: _formatDate(item.nextDueAt),
                      opening: _opening,
                      onOpen: () => _openDueDraft(item),
                      onSkip: () => _skipOccurrence(item),
                      onToggle: () => _toggleEnabled(item),
                      onDelete: () => _deleteItem(item),
                    ),
                  ),
                const SizedBox(height: 20),
                _SectionTitle('Scheduled (${scheduledItems.length})'),
                const SizedBox(height: 12),
                if (scheduledItems.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No future recurring WhatsApp handoffs yet.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ...scheduledItems.map(
                    (item) => _RecurringCard(
                      item: item,
                      due: false,
                      formattedDate: _formatDate(item.nextDueAt),
                      opening: _opening,
                      onOpen: () => _openDueDraft(item),
                      onSkip: () => _skipOccurrence(item),
                      onToggle: () => _toggleEnabled(item),
                      onDelete: () => _deleteItem(item),
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
            CupertinoIcons.repeat,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 16),
          Text(
            'Recurring WhatsApp',
            style: TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Schedule recurring WhatsApp drafts. Text Helper opens the draft; you press Send manually.',
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

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({
    required this.item,
    required this.due,
    required this.formattedDate,
    required this.opening,
    required this.onOpen,
    required this.onSkip,
    required this.onToggle,
    required this.onDelete,
  });

  final WhatsAppRecurringHandoff item;
  final bool due;
  final String formattedDate;
  final bool opening;
  final VoidCallback onOpen;
  final VoidCallback onSkip;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      borderColor: due ? const Color(0xFF16A34A) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                due ? CupertinoIcons.bell_fill : CupertinoIcons.clock_fill,
                color: due ? const Color(0xFF16A34A) : const Color(0xFF0A84FF),
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
                item.repeatRule.label,
                style: const TextStyle(
                  color: CupertinoColors.secondaryLabel,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.phoneNumber,
            style: const TextStyle(
              color: Color(0xFF0A84FF),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Next due: $formattedDate',
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.message,
            style: const TextStyle(
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: opening || !item.enabled ? null : onOpen,
                icon: const Icon(CupertinoIcons.arrow_up_right_square_fill),
                label: const Text('Open Draft'),
              ),
              OutlinedButton.icon(
                onPressed: opening || !item.enabled ? null : onSkip,
                icon: const Icon(CupertinoIcons.forward_fill),
                label: const Text('Skip'),
              ),
              OutlinedButton.icon(
                onPressed: opening ? null : onToggle,
                icon: Icon(
                  item.enabled
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                ),
                label: Text(item.enabled ? 'Disable' : 'Enable'),
              ),
              TextButton.icon(
                onPressed: opening ? null : onDelete,
                icon: const Icon(CupertinoIcons.delete),
                label: const Text('Delete'),
              ),
            ],
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
              'Recurring WhatsApp uses manual handoff only. Text Helper prepares the draft and opens WhatsApp. It does not press Send.',
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
