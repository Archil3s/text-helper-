import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactSchedulerScreen extends StatefulWidget {
  const ContactSchedulerScreen({super.key});

  @override
  State<ContactSchedulerScreen> createState() => _ContactSchedulerScreenState();
}

class _ContactSchedulerScreenState extends State<ContactSchedulerScreen> {
  static const _contactsKey = 'contact_scheduler_contacts_v1';
  static const _messagesKey = 'contact_scheduler_messages_v1';

  final _searchController = TextEditingController();
  final List<ContactEntry> _contacts = [];
  final List<ScheduledTextEntry> _messages = [];

  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getStringList(_contactsKey) ?? const [];
    final messagesJson = prefs.getStringList(_messagesKey) ?? const [];

    setState(() {
      _contacts
        ..clear()
        ..addAll(
          contactsJson.map(
            (item) => ContactEntry.fromJson(
              jsonDecode(item) as Map<String, dynamic>,
            ),
          ),
        );
      _messages
        ..clear()
        ..addAll(
          messagesJson.map(
            (item) => ScheduledTextEntry.fromJson(
              jsonDecode(item) as Map<String, dynamic>,
            ),
          ),
        )
        ..sort((a, b) => a.sendAt.compareTo(b.sendAt));
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _contactsKey,
      _contacts.map((contact) => jsonEncode(contact.toJson())).toList(),
    );
    await prefs.setStringList(
      _messagesKey,
      _messages.map((message) => jsonEncode(message.toJson())).toList(),
    );
  }

  List<ContactEntry> get _filteredContacts {
    if (_query.isEmpty) return List<ContactEntry>.from(_contacts);
    return _contacts.where((contact) {
      final haystack = [
        contact.name,
        contact.phone,
        contact.notes,
        contact.tags.join(' '),
      ].join(' ').toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }

  List<ScheduledTextEntry> get _scheduledMessages => _messages
      .where((message) => message.status != ScheduledTextStatus.cancelled)
      .toList()
    ..sort((a, b) => a.sendAt.compareTo(b.sendAt));

  Future<void> _upsertContact({ContactEntry? existing}) async {
    final result = await showModalBottomSheet<ContactEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ContactEditorSheet(existing: existing),
    );

    if (result == null) return;

    setState(() {
      final index = _contacts.indexWhere((contact) => contact.id == result.id);
      if (index == -1) {
        _contacts.add(result);
      } else {
        _contacts[index] = result;
      }
      _contacts.sort((a, b) => a.name.compareTo(b.name));
    });
    await _save();
  }

  Future<void> _deleteContact(ContactEntry contact) async {
    setState(() {
      _contacts.removeWhere((item) => item.id == contact.id);
      _messages.removeWhere((item) => item.contactId == contact.id);
    });
    await _save();
  }

  Future<void> _scheduleText(ContactEntry contact) async {
    final result = await showModalBottomSheet<ScheduledTextEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ScheduleTextSheet(contact: contact),
    );

    if (result == null) return;

    setState(() {
      _messages.add(result);
      _messages.sort((a, b) => a.sendAt.compareTo(b.sendAt));
    });
    await _save();
  }

  Future<void> _cancelMessage(ScheduledTextEntry message) async {
    setState(() {
      final index = _messages.indexWhere((item) => item.id == message.id);
      if (index != -1) {
        _messages[index] = message.copyWith(
          status: ScheduledTextStatus.cancelled,
        );
      }
    });
    await _save();
  }

  Future<void> _markSent(ScheduledTextEntry message) async {
    setState(() {
      final index = _messages.indexWhere((item) => item.id == message.id);
      if (index != -1) {
        _messages[index] = message.copyWith(status: ScheduledTextStatus.sent);
      }
    });
    await _save();
  }

  Future<void> _openSms(ScheduledTextEntry message) async {
    final uri = Uri(
      scheme: 'sms',
      path: message.phone,
      queryParameters: {'body': message.body},
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the SMS app.')),
      );
      return;
    }

    await _markSent(message);
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _filteredContacts;
    final scheduled = _scheduledMessages;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Contacts & scheduled texts'),
        actions: [
          IconButton(
            tooltip: 'Add contact',
            onPressed: () => _upsertContact(),
            icon: const Icon(CupertinoIcons.person_badge_plus),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _upsertContact(),
        icon: const Icon(CupertinoIcons.person_add),
        label: const Text('Add contact'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
                children: [
                  _OverviewCard(
                    contactsCount: _contacts.length,
                    scheduledCount: scheduled
                        .where(
                          (message) =>
                              message.status == ScheduledTextStatus.scheduled,
                        )
                        .length,
                  ),
                  const SizedBox(height: 16),
                  _SearchField(controller: _searchController),
                  const SizedBox(height: 22),
                  _SectionHeader(
                    title: 'Contact book',
                    actionLabel: 'New',
                    onAction: () => _upsertContact(),
                  ),
                  const SizedBox(height: 10),
                  if (contacts.isEmpty)
                    const _EmptyCard(
                      icon: CupertinoIcons.person_2,
                      title: 'No contacts yet',
                      message: 'Add a contact to schedule a text message.',
                    )
                  else
                    ...contacts.map(
                      (contact) => _ContactCard(
                        contact: contact,
                        onEdit: () => _upsertContact(existing: contact),
                        onDelete: () => _deleteContact(contact),
                        onSchedule: () => _scheduleText(contact),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const _SectionHeader(title: 'Scheduled texts'),
                  const SizedBox(height: 10),
                  if (scheduled.isEmpty)
                    const _EmptyCard(
                      icon: CupertinoIcons.calendar_badge_plus,
                      title: 'No scheduled texts',
                      message: 'Schedule a message from any contact card.',
                    )
                  else
                    ...scheduled.map(
                      (message) => _ScheduledMessageCard(
                        message: message,
                        onCancel: () => _cancelMessage(message),
                        onOpenSms: () => _openSms(message),
                        onMarkSent: () => _markSent(message),
                      ),
                    ),
                  const SizedBox(height: 18),
                  const _InfoCard(),
                ],
              ),
            ),
    );
  }
}

class ContactEntry {
  const ContactEntry({
    required this.id,
    required this.name,
    required this.phone,
    required this.notes,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final String notes;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContactEntry copyWith({
    String? name,
    String? phone,
    String? notes,
    List<String>? tags,
  }) {
    return ContactEntry(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'notes': notes,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ContactEntry.fromJson(Map<String, dynamic> json) {
    return ContactEntry(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

enum ScheduledTextStatus { scheduled, sent, cancelled }

class ScheduledTextEntry {
  const ScheduledTextEntry({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.phone,
    required this.body,
    required this.sendAt,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String contactId;
  final String contactName;
  final String phone;
  final String body;
  final DateTime sendAt;
  final ScheduledTextStatus status;
  final DateTime createdAt;

  bool get isDue =>
      DateTime.now().isAfter(sendAt) || DateTime.now().isAtSameMomentAs(sendAt);

  ScheduledTextEntry copyWith({ScheduledTextStatus? status}) {
    return ScheduledTextEntry(
      id: id,
      contactId: contactId,
      contactName: contactName,
      phone: phone,
      body: body,
      sendAt: sendAt,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'contactId': contactId,
        'contactName': contactName,
        'phone': phone,
        'body': body,
        'sendAt': sendAt.toIso8601String(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ScheduledTextEntry.fromJson(Map<String, dynamic> json) {
    return ScheduledTextEntry(
      id: json['id'] as String,
      contactId: json['contactId'] as String,
      contactName: json['contactName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      body: json['body'] as String? ?? '',
      sendAt:
          DateTime.tryParse(json['sendAt'] as String? ?? '') ?? DateTime.now(),
      status: ScheduledTextStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => ScheduledTextStatus.scheduled,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class _ContactEditorSheet extends StatefulWidget {
  const _ContactEditorSheet({this.existing});

  final ContactEntry? existing;

  @override
  State<_ContactEditorSheet> createState() => _ContactEditorSheetState();
}

class _ContactEditorSheetState extends State<_ContactEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;
  late final TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _phoneController = TextEditingController(text: existing?.phone ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _tagsController =
        TextEditingController(text: existing?.tags.join(', ') ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.existing;
    final now = DateTime.now();
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    final contact = ContactEntry(
      id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      notes: _notesController.text.trim(),
      tags: tags,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.of(context).pop(contact);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, bottomInset + 18),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(),
              Text(
                widget.existing == null ? 'Add contact' : 'Edit contact',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+64210000000',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Phone number is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'client, family, urgent',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(CupertinoIcons.check_mark),
                  label: const Text('Save contact'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleTextSheet extends StatefulWidget {
  const _ScheduleTextSheet({required this.contact});

  final ContactEntry contact;

  @override
  State<_ScheduleTextSheet> createState() => _ScheduleTextSheetState();
}

class _ScheduleTextSheetState extends State<_ScheduleTextSheet> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  late DateTime _sendAt;

  @override
  void initState() {
    super.initState();
    _sendAt = DateTime.now().add(const Duration(minutes: 30));
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _sendAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    setState(() {
      _sendAt = DateTime(
        date.year,
        date.month,
        date.day,
        _sendAt.hour,
        _sendAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_sendAt),
    );
    if (time == null) return;
    setState(() {
      _sendAt = DateTime(
        _sendAt.year,
        _sendAt.month,
        _sendAt.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final message = ScheduledTextEntry(
      id: now.microsecondsSinceEpoch.toString(),
      contactId: widget.contact.id,
      contactName: widget.contact.name,
      phone: widget.contact.phone,
      body: _messageController.text.trim(),
      sendAt: _sendAt,
      status: ScheduledTextStatus.scheduled,
      createdAt: now,
    );

    Navigator.of(context).pop(message);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, bottomInset + 18),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(),
              const Text(
                'Schedule text',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.contact.name} • ${widget.contact.phone}',
                style: const TextStyle(
                  color: CupertinoColors.secondaryLabel,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Message is required'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(CupertinoIcons.calendar),
                      label: Text(_formatDate(_sendAt)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(CupertinoIcons.time),
                      label: Text(_formatTime(_sendAt)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(CupertinoIcons.calendar_badge_plus),
                  label: const Text('Save scheduled text'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.contactsCount,
    required this.scheduledCount,
  });

  final int contactsCount;
  final int scheduledCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.person_crop_circle_badge_checkmark,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 14),
          const Text(
            'Contact book',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Save contacts, draft future texts, and open the SMS app when a message is due.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Pill(label: '$contactsCount contacts'),
              const SizedBox(width: 10),
              _Pill(label: '$scheduledCount scheduled'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: const Icon(CupertinoIcons.search),
        hintText: 'Search contacts, numbers, notes, tags',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
    required this.onSchedule,
  });

  final ContactEntry contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE0F2FE),
                child:
                    Icon(CupertinoIcons.person_fill, color: Color(0xFF0A84FF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      contact.phone,
                      style: const TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (contact.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              contact.notes,
              style: const TextStyle(height: 1.35, fontWeight: FontWeight.w600),
            ),
          ],
          if (contact.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: contact.tags.map((tag) => _Chip(label: tag)).toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSchedule,
              icon: const Icon(CupertinoIcons.calendar_badge_plus),
              label: const Text('Schedule text'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduledMessageCard extends StatelessWidget {
  const _ScheduledMessageCard({
    required this.message,
    required this.onCancel,
    required this.onOpenSms,
    required this.onMarkSent,
  });

  final ScheduledTextEntry message;
  final VoidCallback onCancel;
  final VoidCallback onOpenSms;
  final VoidCallback onMarkSent;

  @override
  Widget build(BuildContext context) {
    final due =
        message.isDue && message.status == ScheduledTextStatus.scheduled;

    return _SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  message.contactName,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              _StatusChip(status: message.status, due: due),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatDate(message.sendAt)} at ${_formatTime(message.sendAt)}',
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(message.body, style: const TextStyle(height: 1.35)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: message.status == ScheduledTextStatus.scheduled
                      ? onOpenSms
                      : null,
                  icon: const Icon(CupertinoIcons.chat_bubble_text),
                  label: Text(due ? 'Open SMS now' : 'Open SMS'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Mark sent',
                onPressed: message.status == ScheduledTextStatus.scheduled
                    ? onMarkSent
                    : null,
                icon: const Icon(CupertinoIcons.check_mark),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Cancel',
                onPressed: message.status == ScheduledTextStatus.scheduled
                    ? onCancel
                    : null,
                icon: const Icon(CupertinoIcons.xmark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.info_circle_fill, color: Color(0xFF0A84FF)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This MVP stores contacts and scheduled texts on this device/browser. It opens the SMS app with the message filled in. Fully automatic scheduled sending needs a backend and SMS provider.',
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        children: [
          Icon(icon, size: 36, color: const Color(0xFF0A84FF)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.margin = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.due});

  final ScheduledTextStatus status;
  final bool due;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ScheduledTextStatus.scheduled => due ? 'Due' : 'Scheduled',
      ScheduledTextStatus.sent => 'Sent',
      ScheduledTextStatus.cancelled => 'Cancelled',
    };

    final color = switch (status) {
      ScheduledTextStatus.scheduled =>
        due ? const Color(0xFFDC2626) : const Color(0xFF0A84FF),
      ScheduledTextStatus.sent => const Color(0xFF16A34A),
      ScheduledTextStatus.cancelled => const Color(0xFF6B7280),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A84FF).withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0A84FF),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

String _formatDate(DateTime dateTime) {
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '${dateTime.year}-$month-$day';
}

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
