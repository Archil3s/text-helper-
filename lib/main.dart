import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TextHelperApp());
}

class TextHelperApp extends StatelessWidget {
  const TextHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Text Helper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0A84FF),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFF2F2F7),
          foregroundColor: CupertinoColors.label,
        ),
      ),
      home: const TextHelperShell(),
    );
  }
}

class TextHelperShell extends StatefulWidget {
  const TextHelperShell({super.key});

  @override
  State<TextHelperShell> createState() => _TextHelperShellState();
}

class _TextHelperShellState extends State<TextHelperShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const SmsDraftScreen(),
      const ContactBookScreen(),
    ];

    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(CupertinoIcons.chat_bubble_text),
            selectedIcon: Icon(CupertinoIcons.chat_bubble_text_fill),
            label: 'SMS',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.person_2),
            selectedIcon: Icon(CupertinoIcons.person_2_fill),
            label: 'Contacts',
          ),
        ],
      ),
    );
  }
}

class SmsDraftScreen extends StatefulWidget {
  const SmsDraftScreen({super.key});

  @override
  State<SmsDraftScreen> createState() => _SmsDraftScreenState();
}

class _SmsDraftScreenState extends State<SmsDraftScreen> {
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  bool _opening = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _openSms() async {
    final phone = _phoneController.text.trim();
    final message = _messageController.text.trim();

    if (phone.isEmpty) {
      _showSnack('Enter a phone number.');
      return;
    }

    if (message.isEmpty) {
      _showSnack('Enter a message.');
      return;
    }

    setState(() => _opening = true);

    try {
      final uri = Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: {'body': message},
      );

      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;

      if (!opened) {
        _showSnack('Could not open the SMS app.');
      }
    } catch (error) {
      if (!mounted) return;
      _showSnack('SMS failed to open: $error');
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  void _clear() {
    _phoneController.clear();
    _messageController.clear();
    _showSnack('Cleared.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Draft'),
        actions: [
          IconButton(
            tooltip: 'Clear',
            onPressed: _clear,
            icon: const Icon(CupertinoIcons.clear),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            const _HeroCard(
              icon: CupertinoIcons.chat_bubble_text_fill,
              title: 'SMS draft',
              message:
                  'Write a message and open your SMS app with the draft ready.',
            ),
            const SizedBox(height: 18),
            _SurfaceCard(
              child: Column(
                children: [
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '+64210000000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(CupertinoIcons.phone),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageController,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(CupertinoIcons.chat_bubble_text),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _opening ? null : _openSms,
                    icon: _opening
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(CupertinoIcons.paperplane_fill),
                    label: Text(_opening ? 'Opening...' : 'Open SMS Draft'),
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
          ],
        ),
      ),
    );
  }
}

class ContactBookScreen extends StatefulWidget {
  const ContactBookScreen({super.key});

  @override
  State<ContactBookScreen> createState() => _ContactBookScreenState();
}

class _ContactBookScreenState extends State<ContactBookScreen> {
  static const _storageKey = 'text_helper_contacts_v1';

  final _searchController = TextEditingController();
  final List<ContactEntry> _contacts = [];

  bool _loading = true;
  bool _favoritesOnly = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final rawContacts = prefs.getStringList(_storageKey) ?? const <String>[];
    final loaded = <ContactEntry>[];

    for (final raw in rawContacts) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          loaded.add(ContactEntry.fromJson(decoded));
        }
      } catch (_) {
        // Ignore damaged local records so one bad entry does not break the app.
      }
    }

    loaded.sort(_sortContacts);

    if (!mounted) return;
    setState(() {
      _contacts
        ..clear()
        ..addAll(loaded);
      _loading = false;
    });
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      _contacts.map((contact) => jsonEncode(contact.toJson())).toList(),
    );
  }

  List<ContactEntry> get _visibleContacts {
    final visible = _contacts.where((contact) {
      if (_favoritesOnly && !contact.favorite) return false;

      if (_query.isEmpty) return true;

      final haystack = [
        contact.name,
        contact.phone,
        contact.email,
        contact.company,
        contact.notes,
        contact.tags.join(' '),
      ].join(' ').toLowerCase();

      return haystack.contains(_query);
    }).toList();

    visible.sort(_sortContacts);
    return visible;
  }

  int get _favoriteCount {
    return _contacts.where((contact) => contact.favorite).length;
  }

  Future<void> _addOrEditContact({ContactEntry? existing}) async {
    final result = await showModalBottomSheet<ContactEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ContactEditorSheet(existing: existing),
    );

    if (result == null || !mounted) return;

    final duplicate = _contacts.any(
      (contact) =>
          contact.id != result.id &&
          _phoneKey(contact.phone) == _phoneKey(result.phone),
    );

    if (duplicate) {
      _showSnack('A contact with that phone number already exists.');
      return;
    }

    setState(() {
      final index = _contacts.indexWhere((contact) => contact.id == result.id);
      if (index == -1) {
        _contacts.add(result);
      } else {
        _contacts[index] = result;
      }
      _contacts.sort(_sortContacts);
    });

    await _saveContacts();
    if (!mounted) return;
    _showSnack(existing == null ? 'Contact added.' : 'Contact updated.');
  }

  Future<void> _deleteContact(ContactEntry contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text('Delete ${contact.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _contacts.removeWhere((item) => item.id == contact.id));
    await _saveContacts();

    if (!mounted) return;
    _showSnack('Contact deleted.');
  }

  Future<void> _toggleFavorite(ContactEntry contact) async {
    setState(() {
      final index = _contacts.indexWhere((item) => item.id == contact.id);
      if (index == -1) return;

      _contacts[index] = contact.copyWith(
        favorite: !contact.favorite,
        updatedAt: DateTime.now(),
      );
      _contacts.sort(_sortContacts);
    });

    await _saveContacts();
  }

  Future<void> _markContacted(ContactEntry contact) async {
    final now = DateTime.now();

    setState(() {
      final index = _contacts.indexWhere((item) => item.id == contact.id);
      if (index == -1) return;

      _contacts[index] = contact.copyWith(
        lastContactedAt: now,
        updatedAt: now,
      );
      _contacts.sort(_sortContacts);
    });

    await _saveContacts();
    if (!mounted) return;
    _showSnack('Marked contacted.');
  }

  Future<void> _openSms(ContactEntry contact) async {
    await _openUri(
      contact,
      Uri(scheme: 'sms', path: contact.phone),
      failure: 'Could not open SMS app.',
    );
  }

  Future<void> _call(ContactEntry contact) async {
    await _openUri(
      contact,
      Uri(scheme: 'tel', path: contact.phone),
      failure: 'Could not open phone app.',
    );
  }

  Future<void> _email(ContactEntry contact) async {
    if (contact.email.trim().isEmpty) {
      _showSnack('This contact has no email address.');
      return;
    }

    await _openUri(
      contact,
      Uri(scheme: 'mailto', path: contact.email),
      failure: 'Could not open email app.',
    );
  }

  Future<void> _openUri(
    ContactEntry contact,
    Uri uri, {
    required String failure,
  }) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;

      if (!opened) {
        _showSnack(failure);
        return;
      }

      await _markContacted(contact);
    } catch (error) {
      if (!mounted) return;
      _showSnack('$failure $error');
    }
  }

  Future<void> _exportContacts() async {
    final payload = const JsonEncoder.withIndent('  ').convert(
      _contacts.map((contact) => contact.toJson()).toList(),
    );

    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    _showSnack('Contacts exported to clipboard.');
  }

  Future<void> _importContacts() async {
    final controller = TextEditingController();

    final pasted = await Clipboard.getData('text/plain');
    controller.text = pasted?.text ?? '';

    if (!mounted) {
      controller.dispose();
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, bottom + 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Import contacts JSON',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Paste exported contacts JSON',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(controller.text),
                icon: const Icon(CupertinoIcons.square_arrow_down),
                label: const Text('Import'),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();

    if (result == null || result.trim().isEmpty || !mounted) return;

    try {
      final decoded = jsonDecode(result);
      if (decoded is! List<dynamic>) {
        _showSnack('Import failed: JSON must be a list.');
        return;
      }

      final imported = <ContactEntry>[];

      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          imported.add(ContactEntry.fromJson(item));
        }
      }

      var added = 0;
      var updated = 0;

      setState(() {
        for (final contact in imported) {
          final key = _phoneKey(contact.phone);
          final existingIndex = _contacts.indexWhere(
            (item) => _phoneKey(item.phone) == key,
          );

          if (existingIndex == -1) {
            _contacts.add(contact);
            added++;
          } else {
            _contacts[existingIndex] = contact.copyWith(
              id: _contacts[existingIndex].id,
              updatedAt: DateTime.now(),
            );
            updated++;
          }
        }

        _contacts.sort(_sortContacts);
      });

      await _saveContacts();

      if (!mounted) return;
      _showSnack('Imported $added new, updated $updated.');
    } catch (error) {
      _showSnack('Import failed: $error');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleContacts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Book'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'import') _importContacts();
              if (value == 'export') _exportContacts();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'import', child: Text('Import JSON')),
              PopupMenuItem(value: 'export', child: Text('Export JSON')),
            ],
          ),
          IconButton(
            tooltip: 'Add contact',
            onPressed: () => _addOrEditContact(),
            icon: const Icon(CupertinoIcons.person_add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditContact(),
        icon: const Icon(CupertinoIcons.person_add),
        label: const Text('Add contact'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadContacts,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
                  children: [
                    _ContactStatsCard(
                      total: _contacts.length,
                      favorites: _favoriteCount,
                    ),
                    const SizedBox(height: 14),
                    _ContactSearchBar(controller: _searchController),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('All contacts'),
                          selected: !_favoritesOnly,
                          onSelected: (_) {
                            setState(() => _favoritesOnly = false);
                          },
                        ),
                        FilterChip(
                          label: Text('Favorites ($_favoriteCount)'),
                          selected: _favoritesOnly,
                          onSelected: (_) {
                            setState(() => _favoritesOnly = true);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (visible.isEmpty)
                      const _EmptyContactsCard()
                    else
                      ...visible.map(
                        (contact) => ContactCard(
                          contact: contact,
                          onEdit: () => _addOrEditContact(existing: contact),
                          onDelete: () => _deleteContact(contact),
                          onFavorite: () => _toggleFavorite(contact),
                          onSms: () => _openSms(contact),
                          onCall: () => _call(contact),
                          onEmail: () => _email(contact),
                          onMarkContacted: () => _markContacted(contact),
                        ),
                      ),
                  ],
                ),
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
    required this.email,
    required this.company,
    required this.notes,
    required this.tags,
    required this.favorite,
    required this.createdAt,
    required this.updatedAt,
    this.lastContactedAt,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String company;
  final String notes;
  final List<String> tags;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastContactedAt;

  ContactEntry copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? company,
    String? notes,
    List<String>? tags,
    bool? favorite,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastContactedAt,
  }) {
    return ContactEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      company: company ?? this.company,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastContactedAt: lastContactedAt ?? this.lastContactedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'company': company,
        'notes': notes,
        'tags': tags,
        'favorite': favorite,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastContactedAt': lastContactedAt?.toIso8601String(),
      };

  factory ContactEntry.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();

    return ContactEntry(
      id: json['id'] as String? ?? createdAt.microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      company: json['company'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      favorite: json['favorite'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? createdAt,
      lastContactedAt:
          DateTime.tryParse(json['lastContactedAt'] as String? ?? ''),
    );
  }
}

class ContactEditorSheet extends StatefulWidget {
  const ContactEditorSheet({super.key, this.existing});

  final ContactEntry? existing;

  @override
  State<ContactEditorSheet> createState() => _ContactEditorSheetState();
}

class _ContactEditorSheetState extends State<ContactEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _companyController;
  late final TextEditingController _notesController;
  late final TextEditingController _tagsController;

  late bool _favorite;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _nameController = TextEditingController(text: existing?.name ?? '');
    _phoneController = TextEditingController(text: existing?.phone ?? '');
    _emailController = TextEditingController(text: existing?.email ?? '');
    _companyController = TextEditingController(text: existing?.company ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _tagsController = TextEditingController(
      text: existing?.tags.join(', ') ?? '',
    );
    _favorite = existing?.favorite ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final existing = widget.existing;

    final contact = ContactEntry(
      id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      company: _companyController.text.trim(),
      notes: _notesController.text.trim(),
      tags: _parseTags(_tagsController.text),
      favorite: _favorite,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      lastContactedAt: existing?.lastContactedAt,
    );

    Navigator.of(context).pop(contact);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, bottom + 18),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            const _SheetHandle(),
            Text(
              widget.existing == null ? 'Add contact' : 'Edit contact',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
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
              validator: _validatePhone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'optional',
                border: OutlineInputBorder(),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _companyController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Company / group',
                hintText: 'optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'family, client, urgent',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _favorite,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) => setState(() => _favorite = value),
              title: const Text('Favorite contact'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(CupertinoIcons.check_mark),
              label: const Text('Save contact'),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactCard extends StatelessWidget {
  const ContactCard({
    super.key,
    required this.contact,
    required this.onEdit,
    required this.onDelete,
    required this.onFavorite,
    required this.onSms,
    required this.onCall,
    required this.onEmail,
    required this.onMarkContacted,
  });

  final ContactEntry contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onFavorite;
  final VoidCallback onSms;
  final VoidCallback onCall;
  final VoidCallback onEmail;
  final VoidCallback onMarkContacted;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE0F2FE),
                child: Text(
                  _initials(contact.name),
                  style: const TextStyle(
                    color: Color(0xFF0A84FF),
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
                    if (contact.email.isNotEmpty)
                      Text(
                        contact.email,
                        style: const TextStyle(
                          color: CupertinoColors.secondaryLabel,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: contact.favorite ? 'Remove favorite' : 'Favorite',
                onPressed: onFavorite,
                icon: Icon(
                  contact.favorite
                      ? CupertinoIcons.star_fill
                      : CupertinoIcons.star,
                  color: contact.favorite ? const Color(0xFFF59E0B) : null,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                  if (value == 'contacted') onMarkContacted();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                      value: 'contacted', child: Text('Mark contacted')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (contact.company.isNotEmpty) ...[
            const SizedBox(height: 10),
            _MetaLine(
                icon: CupertinoIcons.building_2_fill, text: contact.company),
          ],
          if (contact.lastContactedAt != null) ...[
            const SizedBox(height: 8),
            _MetaLine(
              icon: CupertinoIcons.clock,
              text: 'Last contacted ${_relativePast(contact.lastContactedAt!)}',
            ),
          ],
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onSms,
                icon: const Icon(CupertinoIcons.chat_bubble_text),
                label: const Text('Text'),
              ),
              OutlinedButton.icon(
                onPressed: onCall,
                icon: const Icon(CupertinoIcons.phone),
                label: const Text('Call'),
              ),
              if (contact.email.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: onEmail,
                  icon: const Icon(CupertinoIcons.mail),
                  label: const Text('Email'),
                ),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(CupertinoIcons.pencil),
                label: const Text('Edit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactStatsCard extends StatelessWidget {
  const _ContactStatsCard({
    required this.total,
    required this.favorites,
  });

  final int total;
  final int favorites;

  @override
  Widget build(BuildContext context) {
    return _HeroCard(
      icon: CupertinoIcons.person_2_fill,
      title: 'Contact book',
      message:
          '$total saved contacts • $favorites favorites. Data is stored locally on this device.',
    );
  }
}

class _ContactSearchBar extends StatelessWidget {
  const _ContactSearchBar({required this.controller});

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

class _EmptyContactsCard extends StatelessWidget {
  const _EmptyContactsCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Column(
        children: [
          Icon(
            CupertinoIcons.person_crop_circle_badge_plus,
            size: 38,
            color: Color(0xFF0A84FF),
          ),
          SizedBox(height: 10),
          Text(
            'No contacts yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text(
            'Add a contact to start building the book.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
          Icon(icon, color: Colors.white, size: 36),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
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

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
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

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: CupertinoColors.secondaryLabel),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
      decoration: const BoxDecoration(
        color: Color(0x1A0A84FF),
        borderRadius: BorderRadius.all(Radius.circular(999)),
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
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: const BoxDecoration(
          color: Color(0x2E000000),
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
      ),
    );
  }
}

int _sortContacts(ContactEntry a, ContactEntry b) {
  if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

String _phoneKey(String value) {
  final cleaned = value.trim().replaceAll(RegExp(r'[^0-9+]'), '');
  if (cleaned.startsWith('+')) return cleaned;
  return cleaned.replaceFirst(RegExp(r'^0+'), '');
}

List<String> _parseTags(String text) {
  final seen = <String>{};
  final tags = <String>[];

  for (final raw in text.split(',')) {
    final tag = raw.trim();
    final key = tag.toLowerCase();

    if (tag.isNotEmpty && seen.add(key)) {
      tags.add(tag);
    }
  }

  return tags;
}

String? _validatePhone(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Phone number is required';

  final cleaned = text.replaceAll(RegExp(r'[^0-9+]'), '');
  if (cleaned.length < 7) return 'Enter a valid phone number';

  return null;
}

String? _validateEmail(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;

  final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!pattern.hasMatch(text)) return 'Enter a valid email address';

  return null;
}

String _initials(String name) {
  final clean = name.trim();
  if (clean.isEmpty) return '?';

  final parts = clean.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

String _relativePast(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);

  if (diff.inDays >= 1) {
    final amount = diff.inDays;
    return '$amount ${amount == 1 ? 'day' : 'days'} ago';
  }

  if (diff.inHours >= 1) {
    final amount = diff.inHours;
    return '$amount ${amount == 1 ? 'hour' : 'hours'} ago';
  }

  final amount = diff.inMinutes < 1 ? 1 : diff.inMinutes;
  return '$amount ${amount == 1 ? 'minute' : 'minutes'} ago';
}
