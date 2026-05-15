import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const TextHelperApp());

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
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
      ),
      home: const App(),
    );
  }
}

enum Status { scheduled, sent, cancelled }

class Contact {
  Contact({required this.id, required this.name, required this.phone, this.note = '', this.fav = false});
  final String id;
  final String name;
  final String phone;
  final String note;
  final bool fav;
  Contact copy({String? id, String? name, String? phone, String? note, bool? fav}) => Contact(id: id ?? this.id, name: name ?? this.name, phone: phone ?? this.phone, note: note ?? this.note, fav: fav ?? this.fav);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone, 'note': note, 'fav': fav};
  factory Contact.fromJson(Map<String, dynamic> j) => Contact(id: j['id'] as String, name: j['name'] as String? ?? '', phone: j['phone'] as String? ?? '', note: j['note'] as String? ?? '', fav: j['fav'] as bool? ?? false);
}

class Job {
  Job({required this.id, this.contactId, required this.name, required this.phone, required this.text, required this.time, this.status = Status.scheduled});
  final String id;
  final String? contactId;
  final String name;
  final String phone;
  final String text;
  final DateTime time;
  final Status status;
  bool get due => !time.isAfter(DateTime.now());
  Job copy({String? id, String? contactId, String? name, String? phone, String? text, DateTime? time, Status? status}) => Job(id: id ?? this.id, contactId: contactId ?? this.contactId, name: name ?? this.name, phone: phone ?? this.phone, text: text ?? this.text, time: time ?? this.time, status: status ?? this.status);
  Map<String, dynamic> toJson() => {'id': id, 'contactId': contactId, 'name': name, 'phone': phone, 'text': text, 'time': time.toIso8601String(), 'status': status.name};
  factory Job.fromJson(Map<String, dynamic> j) => Job(id: j['id'] as String, contactId: j['contactId'] as String?, name: j['name'] as String? ?? '', phone: j['phone'] as String? ?? '', text: j['text'] as String? ?? '', time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(), status: Status.values.firstWhere((s) => s.name == j['status'], orElse: () => Status.scheduled));
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final contacts = <Contact>[];
  final jobs = <Job>[];
  int tab = 0;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    contacts.addAll((p.getStringList('contacts') ?? []).map((e) => Contact.fromJson(jsonDecode(e) as Map<String, dynamic>)));
    jobs.addAll((p.getStringList('jobs') ?? []).map((e) => Job.fromJson(jsonDecode(e) as Map<String, dynamic>)));
    setState(() => loaded = true);
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('contacts', contacts.map((e) => jsonEncode(e.toJson())).toList());
    await p.setStringList('jobs', jobs.map((e) => jsonEncode(e.toJson())).toList());
  }

  void snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> openSms(String phone, String text) async {
    if (phone.trim().isEmpty) {
      snack('Add or choose a phone number first.');
      return;
    }
    try {
      final opened = await launchUrl(
        Uri(scheme: 'sms', path: phone.trim(), queryParameters: text.trim().isEmpty ? null : {'body': text.trim()}),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) snack('Could not open the SMS app.');
    } catch (error) {
      snack('Could not open SMS: $error');
    }
  }

  Future<void> editContact([Contact? c]) async {
    final r = await showModalBottomSheet<Contact>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => ContactForm(c));
    if (r == null) return;
    setState(() {
      final i = contacts.indexWhere((x) => x.id == r.id);
      if (i < 0) {
        contacts.add(r);
      } else {
        contacts[i] = r;
        for (var n = 0; n < jobs.length; n++) {
          if (jobs[n].contactId == r.id && jobs[n].status == Status.scheduled) {
            jobs[n] = jobs[n].copy(name: r.name, phone: r.phone);
          }
        }
      }
      contacts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
    await save();
    snack(c == null ? 'Contact added.' : 'Contact updated.');
  }

  Future<void> editJob([Job? j, Contact? c]) async {
    final r = await showModalBottomSheet<Job>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => JobForm(contacts: contacts, job: j, contact: c));
    if (r == null) return;
    setState(() {
      final i = jobs.indexWhere((x) => x.id == r.id);
      if (i < 0) {
        jobs.add(r);
      } else {
        jobs[i] = r;
      }
      jobs.sort((a, b) => a.time.compareTo(b.time));
    });
    await save();
    snack(j == null ? 'Message scheduled.' : 'Schedule updated.');
  }

  Future<void> toggleFavorite(Contact c) async {
    final i = contacts.indexWhere((x) => x.id == c.id);
    if (i < 0) return;
    setState(() => contacts[i] = c.copy(fav: !c.fav));
    await save();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: [
        SmsPage(contacts: contacts, onSms: openSms),
        ContactPage(contacts: contacts, onEdit: editContact, onDelete: (c) { setState(() => contacts.remove(c)); save(); snack('Contact deleted.'); }, onSms: (c) => openSms(c.phone, ''), onSchedule: (c) => editJob(null, c), onFav: toggleFavorite),
        SchedulePage(jobs: jobs, onEdit: editJob, onOpen: (j) => openSms(j.phone, j.text), onSent: (j) { setState(() => jobs[jobs.indexOf(j)] = j.copy(status: Status.sent)); save(); snack('Marked sent.'); }, onCancel: (j) { setState(() => jobs[jobs.indexOf(j)] = j.copy(status: Status.cancelled)); save(); snack('Schedule cancelled.'); }),
      ][tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.sms_outlined), selectedIcon: Icon(Icons.sms), label: 'SMS'),
          NavigationDestination(icon: Icon(Icons.contacts_outlined), selectedIcon: Icon(Icons.contacts), label: 'Contacts'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Scheduler'),
        ],
      ),
    );
  }
}

class SmsPage extends StatefulWidget {
  const SmsPage({super.key, required this.contacts, required this.onSms});
  final List<Contact> contacts;
  final Future<void> Function(String, String) onSms;
  @override
  State<SmsPage> createState() => _SmsPageState();
}

class _SmsPageState extends State<SmsPage> {
  final phone = TextEditingController();
  final msg = TextEditingController();
  String id = '';

  @override
  void dispose() {
    phone.dispose();
    msg.dispose();
    super.dispose();
  }

  Contact? get selected {
    for (final x in widget.contacts) {
      if (x.id == id) return x;
    }
    return null;
  }

  @override
  Widget build(BuildContext c) => Page(title: 'SMS', icon: Icons.sms, subtitle: 'Pick a saved contact or type a number. Your SMS app opens with the draft ready to review.', children: [
    DropdownButtonFormField<String>(
      initialValue: widget.contacts.any((x) => x.id == id) ? id : '',
      items: [const DropdownMenuItem(value: '', child: Text('Manual number')), ...widget.contacts.map((x) => DropdownMenuItem(value: x.id, child: Text('${x.name} • ${x.phone}')))],
      onChanged: (v) => setState(() { id = v ?? ''; if (selected != null) phone.text = selected!.phone; }),
      decoration: const InputDecoration(labelText: 'Saved contact'),
    ),
    gap,
    TextField(controller: phone, enabled: id.isEmpty, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
    gap,
    TextField(controller: msg, maxLines: 5, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true)),
    gap,
    FilledButton.icon(onPressed: () => widget.onSms(selected?.phone ?? phone.text, msg.text), icon: const Icon(Icons.open_in_new), label: const Text('Open SMS Draft')),
  ]);
}

class ContactPage extends StatelessWidget {
  const ContactPage({super.key, required this.contacts, required this.onEdit, required this.onDelete, required this.onSms, required this.onSchedule, required this.onFav});
  final List<Contact> contacts;
  final Future<void> Function(Contact?) onEdit;
  final void Function(Contact) onDelete;
  final void Function(Contact) onSms;
  final void Function(Contact) onSchedule;
  final Future<void> Function(Contact) onFav;
  @override
  Widget build(BuildContext c) => Page(title: 'Contacts', icon: Icons.contacts, subtitle: '${contacts.length} saved contacts. Use a contact to text now or create a scheduled message.', fab: () => onEdit(null), children: [
    if (contacts.isEmpty) const EmptyCard(icon: Icons.person_add_alt_1, title: 'No contacts yet', message: 'Tap + to add your first contact. Contacts will appear in SMS and Scheduler.'),
    ...contacts.map((x) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [CircleAvatar(child: Text(x.name.trim().isEmpty ? '?' : x.name.trim()[0].toUpperCase())), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(x.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(x.phone, style: const TextStyle(color: Colors.black54))])), IconButton(onPressed: () => onFav(x), icon: Icon(x.fav ? Icons.star : Icons.star_border, color: x.fav ? Colors.orange : null))]),
      if (x.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(x.note)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.tonalIcon(onPressed: () => onSms(x), icon: const Icon(Icons.sms), label: const Text('Text now')),
        OutlinedButton.icon(onPressed: () => onSchedule(x), icon: const Icon(Icons.event_note), label: const Text('Schedule')),
        OutlinedButton.icon(onPressed: () => onEdit(x), icon: const Icon(Icons.edit), label: const Text('Edit')),
        OutlinedButton.icon(onPressed: () => onDelete(x), icon: const Icon(Icons.delete), label: const Text('Delete')),
      ])
    ]))))
  ]);
}

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key, required this.jobs, required this.onEdit, required this.onOpen, required this.onSent, required this.onCancel});
  final List<Job> jobs;
  final Future<void> Function(Job?) onEdit;
  final void Function(Job) onOpen;
  final void Function(Job) onSent;
  final void Function(Job) onCancel;
  @override
  Widget build(BuildContext c) {
    final sorted = [...jobs]..sort((a, b) => a.time.compareTo(b.time));
    final due = jobs.where((j) => j.status == Status.scheduled && j.due).length;
    final upcoming = jobs.where((j) => j.status == Status.scheduled && !j.due).length;
    return Page(title: 'Scheduler', icon: Icons.event_note, subtitle: '$due due • $upcoming upcoming. Open a due SMS, then mark it sent after sending.', fab: () => onEdit(null), children: [
      if (sorted.isEmpty) const EmptyCard(icon: Icons.event_note, title: 'No scheduled texts', message: 'Tap + to schedule a message, or schedule one directly from a contact.'),
      ...sorted.map((j) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(j.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))), StatusPill(job: j)]),
        Text(j.phone, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 6),
        Text('${_d(j.time)} ${_t(j.time)} ${j.due ? '• due now' : '• upcoming'}', style: TextStyle(color: j.status == Status.scheduled && j.due ? Colors.red : Colors.black54, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(j.text),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonalIcon(onPressed: j.status == Status.scheduled ? () => onOpen(j) : null, icon: const Icon(Icons.sms), label: const Text('Open SMS')),
          OutlinedButton(onPressed: () => onEdit(j), child: const Text('Edit')),
          OutlinedButton(onPressed: j.status == Status.scheduled ? () => onSent(j) : null, child: const Text('Sent')),
          OutlinedButton(onPressed: j.status == Status.scheduled ? () => onCancel(j) : null, child: const Text('Cancel')),
        ])
      ]))))
    ]);
  }
}

class ContactForm extends StatefulWidget { const ContactForm(this.c, {super.key}); final Contact? c; @override State<ContactForm> createState() => _ContactFormState(); }
class _ContactFormState extends State<ContactForm> {
  late final name = TextEditingController(text: widget.c?.name ?? '');
  late final phone = TextEditingController(text: widget.c?.phone ?? '');
  late final note = TextEditingController(text: widget.c?.note ?? '');
  @override
  Widget build(BuildContext c) => Sheet(children: [
    Text(widget.c == null ? 'Add contact' : 'Edit contact', style: head), gap,
    TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
    gap,
    TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
    gap,
    TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Note')),
    gap,
    FilledButton(onPressed: saveContact, child: const Text('Save contact'))
  ]);
  void saveContact() {
    if (name.text.trim().isEmpty || phone.text.trim().length < 7) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and a valid phone number are required.')));
      return;
    }
    Navigator.pop(context, Contact(id: widget.c?.id ?? DateTime.now().microsecondsSinceEpoch.toString(), name: name.text.trim(), phone: phone.text.trim(), note: note.text.trim(), fav: widget.c?.fav ?? false));
  }
}

class JobForm extends StatefulWidget { const JobForm({super.key, required this.contacts, this.job, this.contact}); final List<Contact> contacts; final Job? job; final Contact? contact; @override State<JobForm> createState() => _JobFormState(); }
class _JobFormState extends State<JobForm> {
  late String id = widget.job?.contactId ?? widget.contact?.id ?? '';
  late final phone = TextEditingController(text: widget.job?.contactId == null ? widget.job?.phone ?? '' : '');
  late final name = TextEditingController(text: widget.job?.contactId == null ? widget.job?.name ?? '' : '');
  late final msg = TextEditingController(text: widget.job?.text ?? '');
  late DateTime time = widget.job?.time ?? DateTime.now().add(const Duration(minutes: 30));
  Contact? get contact { for (final x in widget.contacts) { if (x.id == id) return x; } return null; }
  @override
  Widget build(BuildContext c) => Sheet(children: [
    Text(widget.job == null ? 'Schedule text' : 'Edit schedule', style: head), gap,
    DropdownButtonFormField<String>(initialValue: widget.contacts.any((x) => x.id == id) ? id : '', items: [const DropdownMenuItem(value: '', child: Text('Custom recipient')), ...widget.contacts.map((x) => DropdownMenuItem(value: x.id, child: Text('${x.name} • ${x.phone}')))], onChanged: (v) => setState(() => id = v ?? ''), decoration: const InputDecoration(labelText: 'Contact')),
    gap,
    if (id.isEmpty) ...[TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')), gap, TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')), gap],
    TextField(controller: msg, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Message')),
    gap,
    Row(children: [Expanded(child: OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.calendar_today), label: Text(_d(time)))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: pickTime, icon: const Icon(Icons.access_time), label: Text(_t(time))))]), gap,
    FilledButton(onPressed: saveJob, child: const Text('Save schedule'))
  ]);
  Future<void> pickDate() async { final p = await showDatePicker(context: context, initialDate: time, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730))); if (p != null) setState(() => time = DateTime(p.year, p.month, p.day, time.hour, time.minute)); }
  Future<void> pickTime() async { final p = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(time)); if (p != null) setState(() => time = DateTime(time.year, time.month, time.day, p.hour, p.minute)); }
  void saveJob() {
    final c = contact;
    final chosenPhone = c?.phone ?? phone.text.trim();
    if (chosenPhone.length < 7 || msg.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a contact or phone, and enter a message.')));
      return;
    }
    if (!time.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a future date and time.')));
      return;
    }
    Navigator.pop(context, Job(id: widget.job?.id ?? DateTime.now().microsecondsSinceEpoch.toString(), contactId: c?.id, name: c?.name ?? (name.text.trim().isEmpty ? chosenPhone : name.text.trim()), phone: chosenPhone, text: msg.text.trim(), time: time, status: Status.scheduled));
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.job});
  final Job job;
  @override
  Widget build(BuildContext context) {
    final color = switch (job.status) { Status.scheduled => job.due ? Colors.red : Colors.blue, Status.sent => Colors.green, Status.cancelled => Colors.grey };
    final label = job.status == Status.scheduled && job.due ? 'due' : job.status.name;
    return Chip(label: Text(label), backgroundColor: color.withOpacity(0.12), labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold));
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [Icon(icon, size: 38, color: const Color(0xFF0A84FF)), const SizedBox(height: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))])));
}

class Page extends StatelessWidget {
  const Page({super.key, required this.title, required this.children, this.fab, this.icon, this.subtitle});
  final String title;
  final List<Widget> children;
  final VoidCallback? fab;
  final IconData? icon;
  final String? subtitle;
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(title)),
    floatingActionButton: fab == null ? null : FloatingActionButton.extended(onPressed: fab, icon: const Icon(Icons.add), label: const Text('Add')),
    body: ListView(padding: const EdgeInsets.all(18), children: [if (subtitle != null) HeroPanel(title: title, subtitle: subtitle!, icon: icon ?? Icons.apps), if (subtitle != null) gap, ...children]),
  );
}

class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(26)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Colors.white, size: 34), const SizedBox(height: 12), Text(title, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.35))]));
}

class Sheet extends StatelessWidget { const Sheet({super.key, required this.children}); final List<Widget> children; @override Widget build(BuildContext c) => Padding(padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(c).viewInsets.bottom + 18), child: ListView(shrinkWrap: true, children: children)); }
const gap = SizedBox(height: 12);
const head = TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _t(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
