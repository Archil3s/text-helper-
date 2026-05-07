import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/contact_group.dart';
import '../models/contact_item.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final List<ContactItem> _contacts = const [
    ContactItem(
      id: '1',
      name: 'Alex Carter',
      phoneNumber: '(555) 010-1001',
      note: 'Primary test recipient',
    ),
    ContactItem(
      id: '2',
      name: 'Morgan Lee',
      phoneNumber: '(555) 010-1002',
      note: 'Family group',
    ),
    ContactItem(
      id: '3',
      name: 'Taylor Brooks',
      phoneNumber: '(555) 010-1003',
      note: 'Work group',
    ),
  ];

  late final List<ContactGroup> _groups = [
    ContactGroup(
      id: 'family',
      name: 'Family',
      contacts: [_contacts[1]],
    ),
    ContactGroup(
      id: 'work',
      name: 'Work',
      contacts: [_contacts[2]],
    ),
    ContactGroup(
      id: 'test',
      name: 'Test Send',
      contacts: [_contacts[0], _contacts[1]],
    ),
  ];

  void _showComingNext(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label will be connected after local storage is added.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
            onPressed: () => _showComingNext('Import contacts'),
            icon: const Icon(CupertinoIcons.arrow_down_doc_fill),
            tooltip: 'Import contacts',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _SummaryPanel(
            totalContacts: _contacts.length,
            totalGroups: _groups.length,
          ),
          const SizedBox(height: 20),
          _SectionHeader(
            title: 'Groups',
            actionLabel: 'Add group',
            onPressed: () => _showComingNext('Add group'),
          ),
          const SizedBox(height: 12),
          ..._groups.map((group) => _GroupCard(group: group)),
          const SizedBox(height: 20),
          _SectionHeader(
            title: 'Recipients',
            actionLabel: 'Add contact',
            onPressed: () => _showComingNext('Add contact'),
          ),
          const SizedBox(height: 12),
          ..._contacts.map((contact) => _ContactCard(contact: contact)),
        ],
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
                  'Local recipient list',
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
  const _ContactCard({required this.contact});

  final ContactItem contact;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
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
                if (contact.note != null) ...[
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
