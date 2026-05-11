import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _MessageProfile {
  const _MessageProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.enabled,
    required this.priority,
  });

  final String id;
  final String name;
  final String description;
  final bool enabled;
  final int priority;

  _MessageProfile copyWith({
    String? id,
    String? name,
    String? description,
    bool? enabled,
    int? priority,
  }) {
    return _MessageProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
    );
  }

  factory _MessageProfile.fromJson(Map<String, dynamic> json) {
    return _MessageProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      priority: json['priority'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'enabled': enabled,
      'priority': priority,
    };
  }
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  static const String _profilesKey = 'text_helper_message_profiles';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<_MessageProfile> _profiles = <_MessageProfile>[];
  bool _loading = true;
  String _status =
      'Profiles help group rules for driving, sleeping, meetings, and custom scenarios.';

  @override
  void initState() {
    super.initState();
    _nameController.text = 'Driving';
    _descriptionController.text =
        'Auto reply while connected to the car or driving.';
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    final profiles = <_MessageProfile>[];

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          profiles.addAll(
            decoded.whereType<Map>().map(
                  (item) => _MessageProfile.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                ),
          );
        }
      } catch (_) {}
    }

    if (profiles.isEmpty) {
      profiles.addAll(
        const [
          _MessageProfile(
            id: 'profile-driving',
            name: 'Driving',
            description:
                'Use this profile for car or Bluetooth based auto replies.',
            enabled: true,
            priority: 100,
          ),
          _MessageProfile(
            id: 'profile-meeting',
            name: 'Meeting',
            description: 'Use this profile during calendar blocked time.',
            enabled: true,
            priority: 80,
          ),
          _MessageProfile(
            id: 'profile-sleeping',
            name: 'Sleeping',
            description: 'Use this profile for night hours and quiet time.',
            enabled: false,
            priority: 60,
          ),
        ],
      );
    }

    profiles.sort((a, b) => b.priority.compareTo(a.priority));

    if (!mounted) {
      return;
    }

    setState(() {
      _profiles = profiles;
      _loading = false;
    });

    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profilesKey,
      jsonEncode(_profiles.map((profile) => profile.toJson()).toList()),
    );
  }

  Future<void> _addProfile() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      _showSnack('Enter a profile name.');
      return;
    }

    final duplicate = _profiles.any(
      (profile) => profile.name.toLowerCase() == name.toLowerCase(),
    );

    if (duplicate) {
      _showSnack('A profile with this name already exists.');
      return;
    }

    final nextPriority = _profiles.isEmpty
        ? 10
        : _profiles
                .map((profile) => profile.priority)
                .reduce((a, b) => a > b ? a : b) +
            10;

    final profile = _MessageProfile(
      id: 'profile-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      description:
          description.isEmpty ? 'Custom message profile.' : description,
      enabled: true,
      priority: nextPriority,
    );

    setState(() {
      _profiles = [profile, ..._profiles];
      _profiles.sort((a, b) => b.priority.compareTo(a.priority));
      _status = 'Profile added.';
    });

    await _save();
  }

  Future<void> _toggleProfile(_MessageProfile profile) async {
    setState(() {
      _profiles = _profiles
          .map(
            (item) => item.id == profile.id
                ? item.copyWith(enabled: !item.enabled)
                : item,
          )
          .toList();
      _status = profile.enabled ? 'Profile disabled.' : 'Profile enabled.';
    });

    await _save();
  }

  Future<void> _deleteProfile(_MessageProfile profile) async {
    setState(() {
      _profiles = _profiles.where((item) => item.id != profile.id).toList();
      _status = 'Profile deleted.';
    });

    await _save();
  }

  Future<void> _moveProfile(_MessageProfile profile, int delta) async {
    final updated = _profiles
        .map(
          (item) => item.id == profile.id
              ? item.copyWith(priority: item.priority + delta)
              : item,
        )
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    setState(() {
      _profiles = updated;
      _status = 'Profile priority updated.';
    });

    await _save();
  }

  void _editProfile(_MessageProfile profile) {
    setState(() {
      _nameController.text = profile.name;
      _descriptionController.text = profile.description;
      _status =
          'Editing "${profile.name}". Save as a new profile or delete the old one.';
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

  @override
  Widget build(BuildContext context) {
    final enabledCount = _profiles.where((profile) => profile.enabled).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Profiles'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const _HeroCard(),
                const SizedBox(height: 16),
                _StatusCard(status: _status),
                const SizedBox(height: 16),
                _SummaryCard(
                  totalCount: _profiles.length,
                  enabledCount: enabledCount,
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Add profile'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Profile name',
                          helperText: 'Example: Driving, Sleeping, Meeting',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          helperText:
                              'Describe when this profile should be used.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _addProfile,
                        icon: const Icon(CupertinoIcons.plus_circle_fill),
                        label: const Text('Save Profile'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionTitle('Saved profiles (${_profiles.length})'),
                const SizedBox(height: 12),
                ..._profiles.map(
                  (profile) => _ProfileCard(
                    profile: profile,
                    onToggle: () => _toggleProfile(profile),
                    onEdit: () => _editProfile(profile),
                    onDelete: () => _deleteProfile(profile),
                    onMoveUp: () => _moveProfile(profile, 10),
                    onMoveDown: () => _moveProfile(profile, -10),
                  ),
                ),
                const SizedBox(height: 12),
                const _HowItWorksCard(),
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
        color: Color(0xFF111827),
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.slider_horizontal_3,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 16),
          Text(
            'Profiles',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Create scenario profiles for driving, sleeping, meetings, and other auto reply modes.',
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalCount,
    required this.enabledCount,
  });

  final int totalCount;
  final int enabledCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            value: totalCount.toString(),
            label: 'Profiles',
            color: const Color(0xFF0A84FF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            value: enabledCount.toString(),
            label: 'Enabled',
            color: const Color(0xFF16A34A),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final _MessageProfile profile;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                profile.enabled
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.pause_circle_fill,
                color: profile.enabled
                    ? const Color(0xFF16A34A)
                    : CupertinoColors.systemGrey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                profile.enabled ? 'ON' : 'OFF',
                style: TextStyle(
                  color: profile.enabled
                      ? const Color(0xFF16A34A)
                      : CupertinoColors.systemGrey,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            profile.description,
            style: const TextStyle(
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Priority: ${profile.priority}',
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  profile.enabled
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                ),
                label: Text(profile.enabled ? 'Disable' : 'Enable'),
              ),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(CupertinoIcons.pencil),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: onMoveUp,
                icon: const Icon(CupertinoIcons.arrow_up),
                label: const Text('Up'),
              ),
              OutlinedButton.icon(
                onPressed: onMoveDown,
                icon: const Icon(CupertinoIcons.arrow_down),
                label: const Text('Down'),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
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

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('How profiles will be used'),
          SizedBox(height: 12),
          _StepRow(
            number: '1',
            text:
                'A trigger activates a profile, such as driving, sleeping, or meeting.',
          ),
          _StepRow(
            number: '2',
            text: 'Text Helper checks active profiles by priority.',
          ),
          _StepRow(
            number: '3',
            text:
                'The highest priority matching profile controls the auto reply behavior.',
          ),
          _StepRow(
            number: '4',
            text:
                'Future features will attach rules, schedules, flows, and triggers to profiles.',
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.text,
  });

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: const Color(0xFF0A84FF),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
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
