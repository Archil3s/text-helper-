import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/nz_sms_recipient.dart';
import '../services/nz_recipient_store.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final NzRecipientStore _store = NzRecipientStore();

  List<NzSmsRecipient> _recipients = <NzSmsRecipient>[];
  bool _isLoading = true;

  int get _approvedCount {
    return _recipients.where((recipient) => recipient.consented).length;
  }

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  Future<void> _loadRecipients() async {
    final recipients = await _store.loadRecipients();

    if (!mounted) {
      return;
    }

    setState(() {
      _recipients = recipients;
      _isLoading = false;
    });
  }

  String? _normaliseNzNumber(String rawValue) {
    var cleaned = rawValue.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (cleaned.startsWith('00')) {
      cleaned = '+${cleaned.substring(2)}';
    }

    if (cleaned.startsWith('+64')) {
      // Already valid international format.
    } else if (cleaned.startsWith('64')) {
      cleaned = '+$cleaned';
    } else if (cleaned.startsWith('0')) {
      cleaned = '+64${cleaned.substring(1)}';
    }

    if (!RegExp(r'^\+64\d{7,10}$').hasMatch(cleaned)) {
      return null;
    }

    return cleaned;
  }

  Future<void> _addContact() async {
    await _showEditor(
      initialName: 'My Test Number',
      initialNumber: '',
      initialConsent: true,
      initialNote: 'Safe test contact',
    );
  }

  Future<void> _editContact(NzSmsRecipient recipient) async {
    await _showEditor(
      existing: recipient,
      initialName: recipient.name,
      initialNumber: recipient.number,
      initialConsent: recipient.consented,
      initialNote: recipient.note ?? '',
    );
  }

  Future<void> _showEditor({
    NzSmsRecipient? existing,
    required String initialName,
    required String initialNumber,
    required bool initialConsent,
    required String initialNote,
  }) async {
    final nameController = TextEditingController(text: initialName);
    final numberController = TextEditingController(text: initialNumber);
    final noteController = TextEditingController(text: initialNote);
    var consented = initialConsent;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      existing == null ? 'Add contact' : 'Edit contact',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: numberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'NZ phone number',
                        hintText: 'Example: 021 123 4567',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'Note',
                        hintText: 'Optional',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: consented,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Consent confirmed',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        'Required before opening Android Messages.',
                      ),
                      onChanged: (value) {
                        setSheetState(() => consented = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(CupertinoIcons.check_mark),
                      label: const Text('Save contact'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true) {
      return;
    }

    final name = nameController.text.trim();
    final normalisedNumber = _normaliseNzNumber(numberController.text);

    if (name.isEmpty || normalisedNumber == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a name and valid NZ number, like 021 123 4567.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final recipient = NzSmsRecipient(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      number: normalisedNumber,
      consented: consented,
      note: noteController.text.trim(),
    );

    if (existing == null) {
      await _store.addRecipient(recipient);
    } else {
      await _store.updateRecipient(recipient);
    }

    await _loadRecipients();
  }

  Future<void> _deleteContact(NzSmsRecipient recipient) async {
    await _store.deleteRecipient(recipient.id);
    await _loadRecipients();
  }

  Future<void> _resetContacts() async {
    await _store.resetDemoRecipients();
    await _loadRecipients();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Contacts'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _resetContacts,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addContact,
        icon: const Icon(CupertinoIcons.plus),
        label: const Text('Add test number'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              children: [
                _HeroCard(
                  totalCount: _recipients.length,
                  approvedCount: _approvedCount,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tap a contact to edit. Swipe left to delete.',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (_recipients.isEmpty)
                  const _EmptyCard()
                else
                  ..._recipients.map(
                    (recipient) => _ContactCard(
                      recipient: recipient,
                      onTap: () => _editContact(recipient),
                      onDelete: () => _deleteContact(recipient),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.totalCount,
    required this.approvedCount,
  });

  final int totalCount;
  final int approvedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A84FF),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(
        '$approvedCount approved contacts\n$totalCount total saved',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.recipient,
    required this.onTap,
    required this.onDelete,
  });

  final NzSmsRecipient recipient;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(recipient.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(CupertinoIcons.trash_fill, color: Colors.white),
      ),
      child: _SurfaceCard(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Row(
            children: [
              Icon(
                recipient.consented
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.xmark_circle_fill,
                color: recipient.consented
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFEF4444),
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
                    if (recipient.note != null &&
                        recipient.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        recipient.note!,
                        style: const TextStyle(
                          color: CupertinoColors.secondaryLabel,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(CupertinoIcons.pencil, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Text('No contacts yet. Add a test number.'),
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
      ),
      child: child,
    );
  }
}
