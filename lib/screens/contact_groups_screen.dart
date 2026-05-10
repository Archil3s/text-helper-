import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/appointment_reminder.dart';
import '../models/contact_group.dart';
import '../models/nz_sms_recipient.dart';
import '../services/appointment_reminder_store.dart';
import '../services/contact_group_store.dart';
import '../services/do_not_send_service.dart';
import '../services/nz_recipient_store.dart';

class ContactGroupsScreen extends StatefulWidget {
  const ContactGroupsScreen({super.key});

  @override
  State<ContactGroupsScreen> createState() => _ContactGroupsScreenState();
}

class _ContactGroupsScreenState extends State<ContactGroupsScreen> {
  final ContactGroupStore _groupStore = ContactGroupStore();
  final NzRecipientStore _recipientStore = NzRecipientStore();
  final AppointmentReminderStore _reminderStore = AppointmentReminderStore();
  final DoNotSendService _doNotSendService = DoNotSendService();

  List<ContactGroup> _groups = <ContactGroup>[];
  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];

  bool _loading = true;
  String _status = 'Groups loaded.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = await _groupStore.loadGroups();
    final contacts = await _recipientStore.loadRecipients();

    if (!mounted) {
      return;
    }

    setState(() {
      _groups = groups;
      _contacts = contacts.where((contact) => contact.consented).toList();
      _loading = false;
    });
  }

  List<NzSmsRecipient> _contactsForGroup(ContactGroup group) {
    return _contacts
        .where((contact) => group.contactIds.contains(contact.id))
        .toList();
  }

  Future<void> _resetGroups() async {
    await _groupStore.resetGroups();
    await _load();

    if (!mounted) {
      return;
    }

    setState(() => _status = 'Default groups restored.');
  }

  Future<void> _addGroup() async {
    await _showGroupEditor(
      initialName: 'New Group',
      initialBlocked: false,
      initialContactIds: <String>[],
    );
  }

  Future<void> _editGroup(ContactGroup group) async {
    await _showGroupEditor(
      existing: group,
      initialName: group.name,
      initialBlocked: group.isBlockedGroup,
      initialContactIds: [...group.contactIds],
    );
  }

  Future<void> _showGroupEditor({
    ContactGroup? existing,
    required String initialName,
    required bool initialBlocked,
    required List<String> initialContactIds,
  }) async {
    final nameController = TextEditingController(text: initialName);
    var isBlocked = initialBlocked;
    final selectedIds = initialContactIds.toSet();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
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
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey3,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        existing == null ? 'Create group' : 'Edit group',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: _fieldDecoration('Group name'),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: isBlocked,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Do Not Send group',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: const Text(
                          'Contacts in this group should be blocked from sending later.',
                        ),
                        onChanged: (value) {
                          setSheetState(() => isBlocked = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Contacts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_contacts.isEmpty)
                        const _SurfaceCard(
                          child: Text(
                            'No approved contacts yet. Add contacts first.',
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        ..._contacts.map(
                          (contact) => _SurfaceCard(
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: selectedIds.contains(contact.id),
                              title: Text(
                                contact.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(contact.number),
                              onChanged: (value) {
                                setSheetState(() {
                                  if (value == true) {
                                    selectedIds.add(contact.id);
                                  } else {
                                    selectedIds.remove(contact.id);
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(CupertinoIcons.check_mark),
                        label: const Text('Save group'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ],
                  ),
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

    if (name.isEmpty) {
      return;
    }

    final group = ContactGroup(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      contactIds: selectedIds.toList(),
      isBlockedGroup: isBlocked,
    );

    if (existing == null) {
      await _groupStore.addGroup(group);
    } else {
      await _groupStore.updateGroup(group);
    }

    await _load();

    if (!mounted) {
      return;
    }

    setState(() => _status = 'Group saved: $name');
  }

  Future<void> _deleteGroup(ContactGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete group?'),
          content:
              Text('Delete "${group.name}"? Contacts will not be deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _groupStore.deleteGroup(group.id);
    await _load();

    if (!mounted) {
      return;
    }

    setState(() => _status = 'Group deleted.');
  }

  Future<void> _queueGroupText(ContactGroup group) async {
    if (group.isBlockedGroup) {
      setState(() => _status = 'This is a Do Not Send group. Queue blocked.');
      return;
    }

    final recipients = _contactsForGroup(group);

    if (recipients.isEmpty) {
      setState(() => _status = 'No contacts in this group.');
      return;
    }

    final doNotSendResult = await _doNotSendService.checkContacts(recipients);

    if (!doNotSendResult.allowed) {
      final reason = doNotSendResult.reason ??
          'Group send blocked because at least one recipient is in Do Not Send.';

      for (final recipient in recipients) {
        final recipientResult = await _doNotSendService.checkContact(recipient);

        if (recipientResult.allowed) {
          continue;
        }

        await _doNotSendService.logBlockedContact(
          contact: recipient,
          message: 'Group send blocked before queueing.',
          reason: recipientResult.reason ?? reason,
          reminderId:
              'group-${group.id}-blocked-${DateTime.now().microsecondsSinceEpoch}',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() => _status = reason);
      return;
    }
    var scheduledAt = DateTime.now().add(const Duration(minutes: 5));
    var template = 'Appointment reminder';

    final titleController = TextEditingController(text: 'Group reminder');
    final locationController = TextEditingController();
    final messageController = TextEditingController(
      text: 'Hi {name}, reminder for {appointment} at {time}{location}.',
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: scheduledAt,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );

              if (picked == null) {
                return;
              }

              setSheetState(() {
                scheduledAt = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  scheduledAt.hour,
                  scheduledAt.minute,
                );
              });
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(scheduledAt),
              );

              if (picked == null) {
                return;
              }

              setSheetState(() {
                scheduledAt = DateTime(
                  scheduledAt.year,
                  scheduledAt.month,
                  scheduledAt.day,
                  picked.hour,
                  picked.minute,
                );
              });
            }

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
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
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey3,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Queue group text',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${group.name} - ${recipients.length} contact(s)',
                        style: const TextStyle(
                          color: CupertinoColors.secondaryLabel,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: _fieldDecoration('Appointment / text type'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: locationController,
                        decoration: _fieldDecoration('Location / detail'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: template,
                        decoration: _fieldDecoration('Template'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Appointment reminder',
                            child: Text('Appointment reminder'),
                          ),
                          DropdownMenuItem(
                            value: 'Confirmation',
                            child: Text('Confirmation request'),
                          ),
                          DropdownMenuItem(
                            value: 'Follow up',
                            child: Text('Follow up'),
                          ),
                          DropdownMenuItem(
                            value: 'Custom',
                            child: Text('Custom'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setSheetState(() => template = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickDate,
                              icon: const Icon(CupertinoIcons.calendar),
                              label: const Text('Date'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickTime,
                              icon: const Icon(CupertinoIcons.clock),
                              label: const Text('Time'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SurfaceCard(
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.clock_fill,
                              color: Color(0xFF0A84FF),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _formatDateTime(scheduledAt),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: messageController,
                        maxLines: 5,
                        decoration: _fieldDecoration(
                          'Message. Use {name}, {appointment}, {time}, {location}',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(CupertinoIcons.tray_arrow_down_fill),
                        label: Text('Queue ${recipients.length} texts'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ],
                  ),
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

    final baseMessage = messageController.text.trim();

    if (baseMessage.isEmpty) {
      return;
    }

    final nowId = DateTime.now().millisecondsSinceEpoch;

    for (var index = 0; index < recipients.length; index++) {
      final contact = recipients[index];
      final message = _applyPlaceholders(
        baseMessage,
        contact: contact,
        appointment: titleController.text.trim().isEmpty
            ? 'appointment'
            : titleController.text.trim(),
        location: locationController.text.trim(),
        scheduledAt: scheduledAt,
      );

      await _reminderStore.addReminder(
        AppointmentReminder(
          id: '$nowId-group-${group.id}-$index',
          contactId: contact.id,
          phoneNumber: contact.number,
          appointmentTitle: titleController.text.trim().isEmpty
              ? 'Group reminder'
              : titleController.text.trim(),
          location: locationController.text.trim(),
          message: message,
          scheduledAt: scheduledAt,
          isSent: false,
          recurrenceRule: 'once',
          templateName: template,
          notes: 'Queued from group: ${group.name}',
        ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Queued ${recipients.length} text(s) for ${group.name}.';
    });
  }

  String _applyPlaceholders(
    String template, {
    required NzSmsRecipient contact,
    required String appointment,
    required String location,
    required DateTime scheduledAt,
  }) {
    final locationText = location.trim().isEmpty ? '' : ' at $location';

    return template
        .replaceAll('{name}', contact.name)
        .replaceAll('{appointment}', appointment)
        .replaceAll('{time}', _formatTime(scheduledAt))
        .replaceAll('{date}', _formatDate(scheduledAt))
        .replaceAll('{location}', locationText);
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime value) {
    return '${_formatDate(value)} ${_formatTime(value)}';
  }

  @override
  Widget build(BuildContext context) {
    final blockedGroups = _groups.where((group) => group.isBlockedGroup).length;
    final totalAssignedContacts = _groups.fold<int>(
      0,
      (sum, group) => sum + group.contactIds.length,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Contact Groups'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(CupertinoIcons.refresh),
          ),
          IconButton(
            onPressed: _resetGroups,
            icon: const Icon(CupertinoIcons.arrow_counterclockwise),
          ),
          IconButton(
            onPressed: _addGroup,
            icon: const Icon(CupertinoIcons.plus),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGroup,
        icon: const Icon(CupertinoIcons.plus),
        label: const Text('Add group'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              children: [
                _GroupsHero(
                  groups: _groups.length,
                  contacts: _contacts.length,
                  assigned: totalAssignedContacts,
                  blocked: blockedGroups,
                ),
                const SizedBox(height: 20),
                _SurfaceCard(
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.info_circle_fill,
                        color: Color(0xFF0A84FF),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _status,
                          style: const TextStyle(
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_groups.isEmpty)
                  const _SurfaceCard(
                    child: Text('No groups yet. Add a group to start.'),
                  )
                else
                  ..._groups.map(
                    (group) => _GroupCard(
                      group: group,
                      contacts: _contactsForGroup(group),
                      onEdit: () => _editGroup(group),
                      onDelete: () => _deleteGroup(group),
                      onQueue: () => _queueGroupText(group),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _GroupsHero extends StatelessWidget {
  const _GroupsHero({
    required this.groups,
    required this.contacts,
    required this.assigned,
    required this.blocked,
  });

  final int groups;
  final int contacts;
  final int assigned;
  final int blocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF111827),
            Color(0xFF1D4ED8),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.person_3_fill,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'Contact groups',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Organise contacts and queue one reminder to a whole group.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(value: '$groups', label: 'groups'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$contacts', label: 'contacts'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$assigned', label: 'assigned'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$blocked', label: 'blocked'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.contacts,
    required this.onEdit,
    required this.onDelete,
    required this.onQueue,
  });

  final ContactGroup group;
  final List<NzSmsRecipient> contacts;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final color = group.isBlockedGroup
        ? const Color(0xFFF97316)
        : const Color(0xFF0A84FF);

    return _SurfaceCard(
      borderColor: group.isBlockedGroup ? color : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                group.isBlockedGroup
                    ? CupertinoIcons.shield_fill
                    : CupertinoIcons.person_3_fill,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                group.isBlockedGroup ? 'BLOCK' : '${contacts.length}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (contacts.isEmpty)
            const Text(
              'No contacts assigned.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: contacts
                  .map(
                    (contact) => _Chip(
                      label: contact.name,
                      color: contact.isTestNumber
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF6B7280),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(CupertinoIcons.pencil, size: 16),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: group.isBlockedGroup ? null : onQueue,
                icon: const Icon(CupertinoIcons.tray_arrow_down_fill, size: 16),
                label: const Text('Queue group text'),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(CupertinoIcons.trash, size: 16),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
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
