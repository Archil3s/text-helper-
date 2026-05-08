import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/sms_template.dart';
import '../services/sms_template_store.dart';

class TemplateManagerScreen extends StatefulWidget {
  const TemplateManagerScreen({super.key});

  @override
  State<TemplateManagerScreen> createState() => _TemplateManagerScreenState();
}

class _TemplateManagerScreenState extends State<TemplateManagerScreen> {
  final SmsTemplateStore _templateStore = SmsTemplateStore();

  List<SmsTemplate> _templates = <SmsTemplate>[];

  bool _loading = true;

  String _status = 'Templates loaded.';

  final Map<String, String> _previewValues = const {
    'name': 'Alex',
    'date': '2026-01-01',
    'time': '09:00',
    'location': ' at Clinic',
    'appointment': 'appointment',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final templates = await _templateStore.loadTemplates();

    if (!mounted) {
      return;
    }

    setState(() {
      _templates = templates;
      _loading = false;
      _status = 'Templates loaded: ${templates.length}.';
    });
  }

  Future<void> _resetTemplates() async {
    await _templateStore.resetTemplates();
    await _load();

    if (!mounted) {
      return;
    }

    setState(() => _status = 'Default templates restored.');
  }

  Future<void> _addTemplate() async {
    await _showEditor();
  }

  Future<void> _editTemplate(SmsTemplate template) async {
    await _showEditor(existing: template);
  }

  Future<void> _duplicateTemplate(SmsTemplate template) async {
    final now = DateTime.now();

    await _templateStore.addTemplate(
      template.copyWith(
        id: 'template-${now.microsecondsSinceEpoch}',
        name: '${template.name} copy',
        createdAt: now,
        updatedAt: now,
        isBuiltIn: false,
      ),
    );

    await _load();

    if (!mounted) {
      return;
    }

    setState(() => _status = 'Template duplicated.');
  }

  Future<void> _copyTemplate(SmsTemplate template) async {
    await Clipboard.setData(ClipboardData(text: template.body));

    if (!mounted) {
      return;
    }

    setState(() => _status = 'Template copied to clipboard.');
  }

  Future<void> _deleteTemplate(SmsTemplate template) async {
    if (template.isBuiltIn) {
      setState(() => _status =
          'Built-in templates cannot be deleted. Duplicate it first.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete template?'),
          content: Text('Delete "${template.name}"?'),
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

    await _templateStore.deleteTemplate(template.id);
    await _load();

    if (!mounted) {
      return;
    }

    setState(() => _status = 'Template deleted.');
  }

  Future<void> _showEditor({SmsTemplate? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final categoryController =
        TextEditingController(text: existing?.category ?? 'Custom');
    final bodyController = TextEditingController(
      text: existing?.body ??
          'Hi {name}, reminder for your {appointment} on {date} at {time}{location}.',
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final preview = _preview(bodyController.text);

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
                        existing == null ? 'Create template' : 'Edit template',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: _fieldDecoration('Template name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: categoryController,
                        decoration: _fieldDecoration('Category'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bodyController,
                        maxLines: 6,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: _fieldDecoration(
                          'Template body',
                          helper:
                              'Supported: {name}, {date}, {time}, {location}, {appointment}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Preview',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              preview,
                              style: const TextStyle(
                                color: CupertinoColors.secondaryLabel,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          _PlaceholderChip(label: '{name}'),
                          _PlaceholderChip(label: '{date}'),
                          _PlaceholderChip(label: '{time}'),
                          _PlaceholderChip(label: '{location}'),
                          _PlaceholderChip(label: '{appointment}'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(CupertinoIcons.check_mark),
                        label: const Text('Save template'),
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
    final category = categoryController.text.trim();
    final body = bodyController.text.trim();

    if (name.isEmpty || body.isEmpty) {
      setState(() => _status = 'Template name and body are required.');
      return;
    }

    final now = DateTime.now();

    final template = SmsTemplate(
      id: existing?.id ?? 'template-${now.microsecondsSinceEpoch}',
      name: name,
      body: body,
      category: category.isEmpty ? 'Custom' : category,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      isBuiltIn: existing?.isBuiltIn ?? false,
    );

    if (existing == null) {
      await _templateStore.addTemplate(template);
    } else {
      await _templateStore.updateTemplate(template);
    }

    await _load();

    if (!mounted) {
      return;
    }

    setState(() => _status = 'Template saved: $name');
  }

  String _preview(String body) {
    return _templateStore.applyPlaceholders(
      body,
      name: _previewValues['name']!,
      date: _previewValues['date']!,
      time: _previewValues['time']!,
      location: _previewValues['location']!,
      appointment: _previewValues['appointment']!,
    );
  }

  InputDecoration _fieldDecoration(String label, {String? helper}) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customCount = _templates.where((item) => !item.isBuiltIn).length;
    final builtInCount = _templates.where((item) => item.isBuiltIn).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Template Manager'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(CupertinoIcons.refresh),
          ),
          IconButton(
            onPressed: _resetTemplates,
            icon: const Icon(CupertinoIcons.arrow_counterclockwise),
          ),
          IconButton(
            onPressed: _addTemplate,
            icon: const Icon(CupertinoIcons.plus),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTemplate,
        icon: const Icon(CupertinoIcons.plus),
        label: const Text('Add template'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              children: [
                _TemplateHero(
                  total: _templates.length,
                  custom: customCount,
                  builtIn: builtInCount,
                ),
                const SizedBox(height: 20),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                const _SurfaceCard(
                  child: Text(
                    'Templates support placeholders: {name}, {date}, {time}, {location}, and {appointment}. These are replaced when composing reminder messages.',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Templates',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (_templates.isEmpty)
                  const _SurfaceCard(
                    child: Text('No templates yet.'),
                  )
                else
                  ..._templates.map(
                    (template) => _TemplateCard(
                      template: template,
                      preview: _preview(template.body),
                      onEdit: () => _editTemplate(template),
                      onDuplicate: () => _duplicateTemplate(template),
                      onCopy: () => _copyTemplate(template),
                      onDelete: () => _deleteTemplate(template),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _TemplateHero extends StatelessWidget {
  const _TemplateHero({
    required this.total,
    required this.custom,
    required this.builtIn,
  });

  final int total;
  final int custom;
  final int builtIn;

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
            CupertinoIcons.text_bubble_fill,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'Template manager',
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
            'Create reusable reminder messages with appointment placeholders.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(value: '$total', label: 'total'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$custom', label: 'custom'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$builtIn', label: 'built-in'),
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

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.preview,
    required this.onEdit,
    required this.onDuplicate,
    required this.onCopy,
    required this.onDelete,
  });

  final SmsTemplate template;
  final String preview;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color =
        template.isBuiltIn ? const Color(0xFF0A84FF) : const Color(0xFF16A34A);

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.text_bubble_fill,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  template.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                template.isBuiltIn ? 'BUILT-IN' : 'CUSTOM',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            template.category,
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            template.body,
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              preview,
              style: const TextStyle(
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                onPressed: onDuplicate,
                icon: const Icon(CupertinoIcons.square_on_square, size: 16),
                label: const Text('Duplicate'),
              ),
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 16),
                label: const Text('Copy'),
              ),
              OutlinedButton.icon(
                onPressed: template.isBuiltIn ? null : onDelete,
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

class _PlaceholderChip extends StatelessWidget {
  const _PlaceholderChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800),
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
