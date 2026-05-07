import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/contact_group.dart';
import '../models/contact_item.dart';
import '../repositories/contacts_repository.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactsRepository _repository = ContactsRepository();

  List<ContactItem> _contacts = <ContactItem>[];
  bool _isLoading = true;

  List<ContactGroup> get _groups {
    if (_contacts.isEmpty) {
      return const <ContactGroup>[];
    }

    return [
      ContactGroup(
        id: 'all',
        name: 'All Recipients',
        contacts: _contacts,
      ),
      ContactGroup(
        id: 'test',
        name: 'Test Send',
        contacts: _contacts.take(2).toList(),
      ),
      ContactGroup(
        id: 'recent',
        name: 'Recently Added',
        contacts: _contacts.reversed.take(3).toList(),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await _repository.loadContacts();

    if (!mounted) {
      return;
    }

    setState(() {
      _contacts = contacts;
      _isLoading = false;
    });
  }

  Future<void> _addDemoContact() async {
    final contactNumber = _contacts.length + 1;

    final contact = ContactItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Local Contact $contactNumber',
      phoneNumber: '(555) 010-${contactNumber.toString().padLeft(4, '0')}',
      note: 'Saved locally on Android',
    );

    await _repository.addContact(contact);
    await _loadContacts();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contact saved locally. Restart the app to verify persistence.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetContacts() async {
    await _repository.resetContacts();
    await _loadContacts();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contacts reset to sample data.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteContact(ContactItem contact) async {
    await _repository.deleteContact(contact.id);
    await _loadContacts();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${contact.name} deleted locally.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showComingNext(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is queued for the next storage upgrade.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Contacts'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _resetContacts,
            icon: const Icon(CupertinoIcons.refresh),
            tooltip: 'Reset contacts',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _SummaryPanel(
                  totalContacts: _contacts.length,
                  totalGroups: groups.length,
                ),
                const SizedBox(height: 20),
                _SectionHeader(
                  title: 'Groups',
                  actionLabel: 'Add group',
                  onPressed: () => _showComingNext('Add group'),
                ),
                const SizedBox(height: 12),
                ...groups.map((group) => _GroupCard(group: group)),
                const SizedBox(height: 20),
                _SectionHeader(
                  title: 'Recipients',
                  actionLabel: 'Add contact',
                  onPressed: _addDemoContact,
                ),
                const SizedBox(height: 12),
                if (_contacts.isEmpty)
                  const _EmptyContactsCard()
                else
                  ..._contacts.map(
                    (contact) => _ContactCard(
                      contact: contact,
                      onDelete: () => _deleteContact(contact),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDemoContact,
        icon: const Icon(CupertinoIcons.plus),
        label: const Text('Add demo contact'),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.totalContacts,
    required this.totalGroups,
  });

  final int totalContacts;
  final int totalGroups;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A84FF),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.person_2_fill,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Persistent recipient list',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$totalContacts contacts • $totalGroups groups',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 15,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
          ),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final ContactGroup group;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          _IconBubble(
            icon: CupertinoIcons.folder_fill,
            backgroundColor: const Color(0xFFEFF6FF),
            foregroundColor: const Color(0xFF0A84FF),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${group.contactCount} recipients',
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(CupertinoIcons.chevron_forward, size: 18),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.onDelete,
  });

  final ContactItem contact;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(contact.id),
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
        child: const Icon(
          CupertinoIcons.trash_fill,
          color: Colors.white,
        ),
      ),
      child: _SurfaceCard(
        child: Row(
          children: [
            _IconBubble(
              icon: CupertinoIcons.person_fill,
              backgroundColor: const Color(0xFFF3F4F6),
              foregroundColor: const Color(0xFF111827),
            ),
            const SizedBox(width: 14),
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
                    contact.phoneNumber,
                    style: const TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (contact.note != null && contact.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      contact.note!,
                      style: const TextStyle(
                        color: CupertinoColors.tertiaryLabel,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
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
      child: Row(
        children: [
          _IconBubble(
            icon: CupertinoIcons.person_badge_plus,
            backgroundColor: Color(0xFFF3F4F6),
            foregroundColor: Color(0xFF111827),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'No contacts saved yet. Add a demo contact to test persistence.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                height: 1.28,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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

class _IconBubble extends StatelessWidget {
  const _IconBubble({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: foregroundColor, size: 22),
    );
  }
}
