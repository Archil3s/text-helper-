import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const TextHelperApp());

class TextHelperApp extends StatelessWidget {
  const TextHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB));
    return MaterialApp(
      title: 'Text Helper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        cardTheme: CardTheme(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
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

  Contact copy({String? id, String? name, String? phone, String? note, bool? fav}) => Contact(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        note: note ?? this.note,
        fav: fav ?? this.fav,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone, 'note': note, 'fav': fav};

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        note: j['note'] as String? ?? '',
        fav: j['fav'] as bool? ?? false,
      );
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

  Job copy({String? id, String? contactId, String? name, String? phone, String? text, DateTime? time, Status? status}) => Job(
        id: id ?? this.id,
        contactId: contactId ?? this.contactId,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        text: text ?? this.text,
        time: time ?? this.time,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'contactId': contactId,
        'name': name,
        'phone': phone,
        'text': text,
        'time': time.toIso8601String(),
        'status': status.name,
      };

  factory Job.fromJson(Map<String, dynamic> j) => Job(
        id: j['id'] as String,
        contactId: j['contactId'] as String?,
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        text: j['text'] as String? ?? '',
        time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
        status: Status.values.firstWhere((s) => s.name == j['status'], orElse: () => Status.scheduled),
      );
}

class NativeLogEvent {
  NativeLogEvent({required this.title, required this.status, required this.detail, required this.phone, required this.reminderId, required this.createdAt});
  final String title;
  final String status;
  final String detail;
  final String phone;
  final String reminderId;
  final DateTime createdAt;

  factory NativeLogEvent.fromTimeline(Map<String, dynamic> j) => NativeLogEvent(
        title: j['title'] as String? ?? j['status'] as String? ?? 'Event',
        status: j['status'] as String? ?? 'event',
        detail: j['detail'] as String? ?? j['errorMessage'] as String? ?? '',
        phone: j['phoneNumber'] as String? ?? '',
        reminderId: j['reminderId'] as String? ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  factory NativeLogEvent.fromReceipt(Map<String, dynamic> j) => NativeLogEvent(
        title: j['event'] as String? ?? 'Receipt',
        status: j['status'] as String? ?? 'receipt',
        detail: j['errorMessage'] as String? ?? 'Result code ${j['resultCode'] ?? ''}',
        phone: j['phoneNumber'] as String? ?? '',
        reminderId: j['reminderId'] as String? ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  static const alarmChannel = MethodChannel('text_helper/background_alarm');
  final contacts = <Contact>[];
  final jobs = <Job>[];
  final nativeEvents = <NativeLogEvent>[];
  int tab = 0;
  bool loaded = false;
  bool autoSend = false;
  bool syncingAlarms = false;
  int lastSyncedAlarmCount = 0;
  DateTime? lastLogRefresh;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    load();
    refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
      loadNativeLogs(silent: true);
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    contacts.addAll((p.getStringList('contacts') ?? []).map((e) => Contact.fromJson(jsonDecode(e) as Map<String, dynamic>)));
    jobs.addAll((p.getStringList('jobs') ?? []).map((e) => Job.fromJson(jsonDecode(e) as Map<String, dynamic>)));
    autoSend = p.getBool('auto_send_sms') ?? false;
    await loadNativeLogs(silent: true);
    if (!mounted) return;
    setState(() => loaded = true);
    if (autoSend) await syncNativeAlarms(showResult: false);
  }

  Future<void> loadNativeLogs({required bool silent}) async {
    try {
      final p = await SharedPreferences.getInstance();
      final events = <NativeLogEvent>[];
      events.addAll(parseNativeArray(p.getString('text_helper_message_timeline_events')).map(NativeLogEvent.fromTimeline));
      events.addAll(parseNativeArray(p.getString('text_helper_delivery_receipts')).map(NativeLogEvent.fromReceipt));
      events.addAll(parseNativeArray(p.getString('text_helper_send_log')).map(NativeLogEvent.fromTimeline));
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        nativeEvents
          ..clear()
          ..addAll(events.take(25));
        lastLogRefresh = DateTime.now();
      });
      if (!silent) snack('Logs refreshed.');
    } catch (error) {
      if (!silent) snack('Could not read logs: $error');
    }
  }

  List<Map<String, dynamic>> parseNativeArray(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('contacts', contacts.map((e) => jsonEncode(e.toJson())).toList());
    await p.setStringList('jobs', jobs.map((e) => jsonEncode(e.toJson())).toList());
    await p.setBool('auto_send_sms', autoSend);
    await syncNativeAlarms(showResult: false);
  }

  void snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> setAutoSend(bool enabled) async {
    if (enabled) {
      final ok = await requestSmsPermission();
      if (!ok) {
        snack('SMS permission is required for auto-send.');
        return;
      }
      final canExact = await canScheduleExactAlarms();
      if (!canExact) snack('Exact alarm permission may be needed for precise timing.');
    }
    setState(() => autoSend = enabled);
    final p = await SharedPreferences.getInstance();
    await p.setBool('auto_send_sms', autoSend);
    await syncNativeAlarms(showResult: true);
  }

  Future<bool> requestSmsPermission() async {
    try {
      return await alarmChannel.invokeMethod<bool>('requestSmsPermission') ?? false;
    } catch (error) {
      snack('Could not request SMS permission: $error');
      return false;
    }
  }

  Future<bool> canScheduleExactAlarms() async {
    try {
      return await alarmChannel.invokeMethod<bool>('canScheduleExactAlarms') ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> syncNativeAlarms({required bool showResult}) async {
    if (syncingAlarms) return;
    syncingAlarms = true;
    try {
      if (!autoSend) {
        await alarmChannel.invokeMethod<void>('cancelAllBackgroundAlarms');
        lastSyncedAlarmCount = 0;
        if (showResult) snack('Auto-send off. Alarms cancelled.');
        return;
      }
      final alarmCutoff = DateTime.now().subtract(const Duration(minutes: 10));
      final alarms = jobs
          .where((j) => j.status == Status.scheduled && j.time.isAfter(alarmCutoff) && j.phone.trim().isNotEmpty && j.text.trim().isNotEmpty)
          .map((j) => {
                'alarmId': j.id,
                'reminderId': j.id,
                'contactId': j.contactId ?? '',
                'phoneNumber': j.phone.trim(),
                'message': j.text.trim(),
                'appointmentTitle': j.name,
                'location': '',
                'scheduledAtMillis': j.time.millisecondsSinceEpoch,
                'recurrenceRule': 'once',
                'templateName': 'Text Helper',
                'notes': 'Scheduled from Text Helper',
              })
          .toList();
      final count = await alarmChannel.invokeMethod<int>('syncBackgroundAlarms', {'alarms': alarms}) ?? 0;
      if (mounted) setState(() => lastSyncedAlarmCount = count);
      if (showResult) snack('$count alarm${count == 1 ? '' : 's'} synced.');
    } catch (error) {
      if (showResult) snack('Could not sync alarms: $error');
    } finally {
      syncingAlarms = false;
    }
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
    final result = await showModalBottomSheet<List<Job>>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => JobForm(contacts: contacts, job: j, contact: c));
    if (result == null || result.isEmpty) return;
    setState(() {
      if (j != null) jobs.removeWhere((x) => x.id == j.id);
      jobs.addAll(result);
      jobs.sort((a, b) => a.time.compareTo(b.time));
    });
    await save();
    final count = result.length;
    snack('$count scheduled send${count == 1 ? '' : 's'} saved${autoSend ? ' and synced' : ''}.');
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
        ContactPage(
          contacts: contacts,
          onEdit: editContact,
          onDelete: (c) {
            setState(() => contacts.remove(c));
            save();
            snack('Contact deleted.');
          },
          onSms: (c) => openSms(c.phone, ''),
          onSchedule: (c) => editJob(null, c),
          onFav: toggleFavorite,
        ),
        SchedulePage(
          jobs: jobs,
          autoSend: autoSend,
          nativeEvents: nativeEvents,
          lastSyncedAlarmCount: lastSyncedAlarmCount,
          lastLogRefresh: lastLogRefresh,
          onToggleAutoSend: setAutoSend,
          onSyncAlarms: () => syncNativeAlarms(showResult: true),
          onRefreshLogs: () => loadNativeLogs(silent: false),
          onEdit: editJob,
          onOpen: (j) => openSms(j.phone, j.text),
          onSent: (j) {
            setState(() => jobs[jobs.indexOf(j)] = j.copy(status: Status.sent));
            save();
            snack('Marked sent.');
          },
          onCancel: (j) {
            setState(() => jobs[jobs.indexOf(j)] = j.copy(status: Status.cancelled));
            save();
            snack('Schedule cancelled.');
          },
        ),
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
  Widget build(BuildContext c) => AppPage(
        title: 'SMS',
        subtitle: 'Write a message and open your SMS app when you want to review before sending.',
        icon: Icons.sms,
        children: [
          CleanCard(children: [
            SectionHeader(icon: Icons.person_outline, title: 'Recipient', subtitle: 'Choose a saved contact or enter a number.'),
            DropdownButtonFormField<String>(
              initialValue: widget.contacts.any((x) => x.id == id) ? id : '',
              items: [const DropdownMenuItem(value: '', child: Text('Manual number')), ...widget.contacts.map((x) => DropdownMenuItem(value: x.id, child: Text('${x.name} • ${x.phone}')))],
              onChanged: (v) => setState(() {
                id = v ?? '';
                if (selected != null) phone.text = selected!.phone;
              }),
              decoration: const InputDecoration(labelText: 'Saved contact'),
            ),
            gap,
            TextField(controller: phone, enabled: id.isEmpty, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
          ]),
          CleanCard(children: [
            SectionHeader(icon: Icons.edit_note, title: 'Message', subtitle: 'This opens as a draft in your SMS app.'),
            TextField(controller: msg, maxLines: 5, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true)),
            gap,
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => widget.onSms(selected?.phone ?? phone.text, msg.text), icon: const Icon(Icons.open_in_new), label: const Text('Open SMS draft'))),
          ]),
        ],
      );
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
  Widget build(BuildContext c) => AppPage(
        title: 'Contacts',
        subtitle: '${contacts.length} saved contact${contacts.length == 1 ? '' : 's'}. Text now or schedule from one place.',
        icon: Icons.contacts,
        fab: () => onEdit(null),
        children: [
          if (contacts.isEmpty) const EmptyCard(icon: Icons.person_add_alt_1, title: 'No contacts yet', message: 'Tap Add to save your first contact.'),
          ...contacts.map((x) => ContactTile(contact: x, onFav: onFav, onSms: onSms, onSchedule: onSchedule, onEdit: onEdit, onDelete: onDelete)),
        ],
      );
}

class ContactTile extends StatelessWidget {
  const ContactTile({super.key, required this.contact, required this.onFav, required this.onSms, required this.onSchedule, required this.onEdit, required this.onDelete});
  final Contact contact;
  final Future<void> Function(Contact) onFav;
  final void Function(Contact) onSms;
  final void Function(Contact) onSchedule;
  final Future<void> Function(Contact?) onEdit;
  final void Function(Contact) onDelete;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(child: Text(contact.name.trim().isEmpty ? '?' : contact.name.trim()[0].toUpperCase())),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(contact.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text(contact.phone, style: const TextStyle(color: Colors.black54)),
              ])),
              IconButton(onPressed: () => onFav(contact), icon: Icon(contact.fav ? Icons.star : Icons.star_border, color: contact.fav ? Colors.orange : null)),
            ]),
            if (contact.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(contact.note)),
            gap,
            Row(children: [
              Expanded(child: FilledButton.tonalIcon(onPressed: () => onSms(contact), icon: const Icon(Icons.sms), label: const Text('Text'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(onPressed: () => onSchedule(contact), icon: const Icon(Icons.event_note), label: const Text('Schedule'))),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit(contact);
                  if (value == 'delete') onDelete(contact);
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
              ),
            ]),
          ]),
        ),
      );
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.jobs, required this.autoSend, required this.nativeEvents, required this.lastSyncedAlarmCount, required this.lastLogRefresh, required this.onToggleAutoSend, required this.onSyncAlarms, required this.onRefreshLogs, required this.onEdit, required this.onOpen, required this.onSent, required this.onCancel});
  final List<Job> jobs;
  final bool autoSend;
  final List<NativeLogEvent> nativeEvents;
  final int lastSyncedAlarmCount;
  final DateTime? lastLogRefresh;
  final ValueChanged<bool> onToggleAutoSend;
  final VoidCallback onSyncAlarms;
  final VoidCallback onRefreshLogs;
  final Future<void> Function(Job?) onEdit;
  final void Function(Job) onOpen;
  final void Function(Job) onSent;
  final void Function(Job) onCancel;
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late DateTime calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? selectedDay;

  @override
  Widget build(BuildContext c) {
    final sorted = [...widget.jobs]..sort((a, b) => a.time.compareTo(b.time));
    final filtered = selectedDay == null ? sorted : sorted.where((j) => sameDay(j.time, selectedDay!)).toList();
    final due = widget.jobs.where((j) => j.status == Status.scheduled && j.due).length;
    final upcoming = widget.jobs.where((j) => j.status == Status.scheduled && !j.due).length;
    final sent = widget.jobs.where((j) => j.status == Status.sent).length;
    final last = widget.nativeEvents.isEmpty ? null : widget.nativeEvents.first;

    return AppPage(
      title: 'Scheduler',
      subtitle: 'Plan texts, sync alarms, and check delivery in one place.',
      icon: Icons.event_note,
      fab: () => widget.onEdit(null),
      children: [
        QuickStats(due: due, upcoming: upcoming, sent: sent, autoSend: widget.autoSend),
        AutoSendCard(enabled: widget.autoSend, onChanged: widget.onToggleAutoSend, onSync: widget.onSyncAlarms, alarmCount: widget.lastSyncedAlarmCount),
        if (last != null) LastResultCard(event: last, onRefresh: widget.onRefreshLogs),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          collapsedShape: roundedShape,
          shape: roundedShape,
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          leading: const Icon(Icons.calendar_month),
          title: const Text('Calendar', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Tap a day to filter the list.'),
          initiallyExpanded: true,
          children: [
            SchedulerCalendar(
              month: calendarMonth,
              selectedDay: selectedDay,
              jobs: widget.jobs,
              onPrevious: () => setState(() => calendarMonth = DateTime(calendarMonth.year, calendarMonth.month - 1)),
              onNext: () => setState(() => calendarMonth = DateTime(calendarMonth.year, calendarMonth.month + 1)),
              onPickDay: (day) => setState(() => selectedDay = selectedDay != null && sameDay(selectedDay!, day) ? null : day),
            ),
          ],
        ),
        if (selectedDay != null)
          FilterChipRow(label: 'Showing ${_d(selectedDay!)}', onClear: () => setState(() => selectedDay = null)),
        SectionHeader(icon: Icons.schedule, title: 'Scheduled texts', subtitle: filtered.isEmpty ? 'No matching messages.' : '${filtered.length} message${filtered.length == 1 ? '' : 's'} shown'),
        if (filtered.isEmpty) const EmptyCard(icon: Icons.event_note, title: 'Nothing scheduled', message: 'Tap Add to schedule a text.'),
        ...filtered.map((j) => JobTile(job: j, onOpen: widget.onOpen, onEdit: widget.onEdit, onSent: widget.onSent, onCancel: widget.onCancel)),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          collapsedShape: roundedShape,
          shape: roundedShape,
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          leading: const Icon(Icons.tune),
          title: const Text('Advanced logs', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Use when you need to troubleshoot sending.'),
          children: [
            DiagnosticsCard(autoSend: widget.autoSend, alarmCount: widget.lastSyncedAlarmCount, lastRefresh: widget.lastLogRefresh, events: widget.nativeEvents, onRefresh: widget.onRefreshLogs),
          ],
        ),
      ],
    );
  }
}

class QuickStats extends StatelessWidget {
  const QuickStats({super.key, required this.due, required this.upcoming, required this.sent, required this.autoSend});
  final int due;
  final int upcoming;
  final int sent;
  final bool autoSend;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: StatCard(label: 'Due', value: '$due', icon: Icons.warning_amber, tone: Colors.red)),
        const SizedBox(width: 8),
        Expanded(child: StatCard(label: 'Upcoming', value: '$upcoming', icon: Icons.schedule, tone: Colors.blue)),
        const SizedBox(width: 8),
        Expanded(child: StatCard(label: autoSend ? 'Auto on' : 'Auto off', value: '$sent sent', icon: autoSend ? Icons.flash_on : Icons.flash_off, tone: autoSend ? Colors.green : Colors.grey)),
      ]);
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.icon, required this.tone});
  final String label;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: tone.withAlpha(35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
      );
}

class AutoSendCard extends StatelessWidget {
  const AutoSendCard({super.key, required this.enabled, required this.onChanged, required this.onSync, required this.alarmCount});
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onSync;
  final int alarmCount;

  @override
  Widget build(BuildContext context) => CleanCard(children: [
        Row(children: [
          CircleAvatar(backgroundColor: enabled ? Colors.green.withAlpha(25) : Colors.grey.withAlpha(25), child: Icon(enabled ? Icons.send : Icons.sms_outlined, color: enabled ? Colors.green : Colors.grey)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Closed-app sending', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            Text(enabled ? '$alarmCount alarm${alarmCount == 1 ? '' : 's'} synced' : 'Turn on to send scheduled texts while closed.', style: const TextStyle(color: Colors.black54)),
          ])),
          Switch(value: enabled, onChanged: onChanged),
        ]),
        if (enabled) ...[
          gap,
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onSync, icon: const Icon(Icons.sync), label: const Text('Sync now'))),
        ],
      ]);
}

class LastResultCard extends StatelessWidget {
  const LastResultCard({super.key, required this.event, required this.onRefresh});
  final NativeLogEvent event;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => CleanCard(children: [
        Row(children: [
          Icon(iconForStatus(event.status), color: colorForStatus(event.status)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Latest result', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            Text('${event.title} • ${event.status}', style: const TextStyle(color: Colors.black54)),
          ])),
          TextButton(onPressed: onRefresh, child: const Text('Refresh')),
        ]),
        if (event.detail.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(event.detail)),
      ]);
}

class JobTile extends StatelessWidget {
  const JobTile({super.key, required this.job, required this.onOpen, required this.onEdit, required this.onSent, required this.onCancel});
  final Job job;
  final void Function(Job) onOpen;
  final Future<void> Function(Job?) onEdit;
  final void Function(Job) onSent;
  final void Function(Job) onCancel;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(job.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
              StatusPill(job: job),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit(job);
                  if (value == 'sent') onSent(job);
                  if (value == 'cancel') onCancel(job);
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'sent', child: Text('Mark sent')), PopupMenuItem(value: 'cancel', child: Text('Cancel'))],
              ),
            ]),
            Text(job.phone, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.schedule, size: 16, color: job.due ? Colors.red : Colors.black54),
              const SizedBox(width: 6),
              Text('${_d(job.time)} ${_t(job.time)}${job.due ? ' • due now' : ''}', style: TextStyle(color: job.due ? Colors.red : Colors.black54, fontWeight: FontWeight.w700)),
            ]),
            const Divider(height: 22),
            Text(job.text),
            gap,
            SizedBox(width: double.infinity, child: FilledButton.tonalIcon(onPressed: job.status == Status.scheduled ? () => onOpen(job) : null, icon: const Icon(Icons.sms), label: const Text('Open SMS'))),
          ]),
        ),
      );
}

class DiagnosticsCard extends StatelessWidget {
  const DiagnosticsCard({super.key, required this.autoSend, required this.alarmCount, required this.lastRefresh, required this.events, required this.onRefresh});
  final bool autoSend;
  final int alarmCount;
  final DateTime? lastRefresh;
  final List<NativeLogEvent> events;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Auto-send: ${autoSend ? 'on' : 'off'} • alarms: $alarmCount', style: const TextStyle(fontWeight: FontWeight.w700))),
            TextButton(onPressed: onRefresh, child: const Text('Refresh')),
          ]),
          Text('Last refresh: ${lastRefresh == null ? 'never' : _t(lastRefresh!)}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const Text('No send events yet.')
          else
            ...events.take(6).map((e) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(iconForStatus(e.status), size: 18, color: colorForStatus(e.status)),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${e.title} • ${e.status}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${_d(e.createdAt)} ${_t(e.createdAt)} ${e.phone}', style: const TextStyle(color: Colors.black54)),
                      if (e.detail.isNotEmpty) Text(e.detail, style: const TextStyle(color: Colors.black54)),
                    ])),
                  ]),
                )),
        ]),
      );
}

class SchedulerCalendar extends StatelessWidget {
  const SchedulerCalendar({super.key, required this.month, required this.selectedDay, required this.jobs, required this.onPrevious, required this.onNext, required this.onPickDay});
  final DateTime month;
  final DateTime? selectedDay;
  final List<Job> jobs;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onPickDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = first.weekday - 1;
    final cellCount = leadingBlanks + daysInMonth;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(children: [
        Row(children: [
          IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
          Expanded(child: Center(child: Text('${monthName(month.month)} ${month.year}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)))),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ]),
        const Row(children: [for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Expanded(child: Center(child: Text(d, style: TextStyle(fontWeight: FontWeight.bold))))]),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 6, mainAxisSpacing: 6),
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = index - leadingBlanks + 1;
            final date = DateTime(month.year, month.month, day);
            final count = jobs.where((job) => sameDay(job.time, date)).length;
            final isToday = sameDay(date, DateTime.now());
            final isSelected = selectedDay != null && sameDay(date, selectedDay!);
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onPickDay(date),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : count > 0 ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isToday ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB), width: isToday ? 2 : 1),
                ),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$day', style: TextStyle(fontWeight: FontWeight.w800, color: isSelected ? Colors.white : Colors.black)),
                  if (count > 0) Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : const Color(0xFF2563EB))),
                ])),
              ),
            );
          },
        ),
      ]),
    );
  }
}

class ContactForm extends StatefulWidget {
  const ContactForm(this.c, {super.key});
  final Contact? c;
  @override
  State<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  late final name = TextEditingController(text: widget.c?.name ?? '');
  late final phone = TextEditingController(text: widget.c?.phone ?? '');
  late final note = TextEditingController(text: widget.c?.note ?? '');

  @override
  Widget build(BuildContext c) => Sheet(children: [
        Text(widget.c == null ? 'Add contact' : 'Edit contact', style: head),
        gap,
        TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
        gap,
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
        gap,
        TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Note')),
        gap,
        FilledButton(onPressed: saveContact, child: const Text('Save contact')),
      ]);

  void saveContact() {
    if (name.text.trim().isEmpty || phone.text.trim().length < 7) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and a valid phone number are required.')));
      return;
    }
    Navigator.pop(context, Contact(id: widget.c?.id ?? DateTime.now().microsecondsSinceEpoch.toString(), name: name.text.trim(), phone: phone.text.trim(), note: note.text.trim(), fav: widget.c?.fav ?? false));
  }
}

class JobForm extends StatefulWidget {
  const JobForm({super.key, required this.contacts, this.job, this.contact});
  final List<Contact> contacts;
  final Job? job;
  final Contact? contact;
  @override
  State<JobForm> createState() => _JobFormState();
}

class _JobFormState extends State<JobForm> {
  late String id = widget.job?.contactId ?? widget.contact?.id ?? '';
  late final phone = TextEditingController(text: widget.job?.contactId == null ? widget.job?.phone ?? '' : '');
  late final name = TextEditingController(text: widget.job?.contactId == null ? widget.job?.name ?? '' : '');
  late final msg = TextEditingController(text: widget.job?.text ?? '');
  late DateTime time = widget.job?.time ?? DateTime.now().add(const Duration(minutes: 30));
  String spacing = 'once';
  int copies = 1;

  Contact? get contact {
    for (final x in widget.contacts) {
      if (x.id == id) return x;
    }
    return null;
  }

  bool get editing => widget.job != null;
  int get previewCount => editing ? 1 : cappedCopies(spacing, copies);

  @override
  Widget build(BuildContext c) => Sheet(children: [
        Text(editing ? 'Edit schedule' : 'Schedule text', style: head),
        const SizedBox(height: 4),
        const Text('Simple setup first. Testing and repeats are tucked under Advanced.', style: TextStyle(color: Colors.black54)),
        gap,
        CleanCard(children: [
          SectionHeader(icon: Icons.person_outline, title: 'Who gets it?', subtitle: 'Choose a contact or use a custom number.'),
          DropdownButtonFormField<String>(
            initialValue: widget.contacts.any((x) => x.id == id) ? id : '',
            items: [const DropdownMenuItem(value: '', child: Text('Custom recipient')), ...widget.contacts.map((x) => DropdownMenuItem(value: x.id, child: Text('${x.name} • ${x.phone}')))],
            onChanged: (v) => setState(() => id = v ?? ''),
            decoration: const InputDecoration(labelText: 'Contact'),
          ),
          if (id.isEmpty) ...[
            gap,
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
            gap,
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
          ],
        ]),
        CleanCard(children: [
          SectionHeader(icon: Icons.message_outlined, title: 'Message', subtitle: 'Keep it clear and short for testing.'),
          TextField(controller: msg, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Message')),
        ]),
        CleanCard(children: [
          SectionHeader(icon: Icons.event, title: 'When should it send?', subtitle: 'Pick a date and time, or use a test shortcut.'),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.calendar_today), label: Text(_d(time)))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: pickTime, icon: const Icon(Icons.access_time), label: Text(_t(time)))),
          ]),
          gap,
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(label: const Text('+60 sec'), avatar: const Icon(Icons.recommend, size: 18), onPressed: () => quickDelay(60)),
            ActionChip(label: const Text('+5 min'), avatar: const Icon(Icons.schedule, size: 18), onPressed: () => quickDelay(300)),
          ]),
        ]),
        if (!editing)
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            collapsedShape: roundedShape,
            shape: roundedShape,
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.white,
            leading: const Icon(Icons.science_outlined),
            title: const Text('Advanced testing and repeats', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Create visible one-time sends. No hidden loops.'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Align(alignment: Alignment.centerLeft, child: FilledButton.tonalIcon(onPressed: recommendedTest, icon: const Icon(Icons.auto_awesome), label: const Text('Use recommended test'))),
              gap,
              Wrap(spacing: 8, runSpacing: 8, children: [
                ActionChip(label: const Text('+15 sec'), avatar: const Icon(Icons.timer, size: 18), onPressed: () => quickDelay(15)),
                ActionChip(label: const Text('+30 sec'), avatar: const Icon(Icons.timer, size: 18), onPressed: () => quickDelay(30)),
              ]),
              gap,
              DropdownButtonFormField<String>(
                initialValue: spacing,
                decoration: const InputDecoration(labelText: 'Repeat pattern'),
                items: spacingOptions.map((item) => DropdownMenuItem(value: item, child: Text(spacingLabel(item)))).toList(),
                onChanged: (value) => setState(() {
                  spacing = value ?? 'once';
                  if (spacing == 'once') copies = 1;
                }),
              ),
              gap,
              DropdownButtonFormField<int>(
                initialValue: copies,
                decoration: const InputDecoration(labelText: 'Number of scheduled sends'),
                items: [1, 2, 3, 5, 10].map((n) => DropdownMenuItem(value: n, child: Text('$n send${n == 1 ? '' : 's'}'))).toList(),
                onChanged: spacing == 'once' ? null : (value) => setState(() => copies = value ?? 1),
              ),
              if (spacing.startsWith('test')) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Testing repeats are capped to 3 sends. Use 60-second spacing if your phone/provider throttles faster tests.', style: TextStyle(color: Colors.black54))),
            ],
          ),
        CleanCard(children: [
          SectionHeader(icon: Icons.visibility_outlined, title: 'Preview', subtitle: '$previewCount scheduled send${previewCount == 1 ? '' : 's'} will be created.'),
          ...List.generate(previewCount, (i) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                  const SizedBox(width: 10),
                  Text('${_d(spacedTime(time, spacing, i))} ${_t(spacedTime(time, spacing, i))}'),
                ]),
              )),
        ]),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: saveJob, icon: const Icon(Icons.check), label: Text(editing ? 'Save schedule' : 'Create schedule'))),
      ]);

  void quickDelay(int seconds) => setState(() => time = DateTime.now().add(Duration(seconds: seconds)));

  void recommendedTest() => setState(() {
        time = DateTime.now().add(const Duration(seconds: 60));
        spacing = 'test60';
        copies = 3;
      });

  Future<void> pickDate() async {
    final p = await showDatePicker(context: context, initialDate: time, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (p != null) setState(() => time = DateTime(p.year, p.month, p.day, time.hour, time.minute));
  }

  Future<void> pickTime() async {
    final p = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(time));
    if (p != null) setState(() => time = DateTime(time.year, time.month, time.day, p.hour, p.minute));
  }

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
    final baseName = c?.name ?? (name.text.trim().isEmpty ? chosenPhone : name.text.trim());
    final count = previewCount;
    final seed = DateTime.now().microsecondsSinceEpoch.toString();
    final created = <Job>[];
    for (var i = 0; i < count; i++) {
      created.add(Job(id: i == 0 ? widget.job?.id ?? seed : '$seed-$i', contactId: c?.id, name: count == 1 ? baseName : '$baseName (${i + 1}/$count)', phone: chosenPhone, text: msg.text.trim(), time: spacedTime(time, spacing, i), status: Status.scheduled));
    }
    Navigator.pop(context, created);
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.job});
  final Job job;
  @override
  Widget build(BuildContext context) {
    final color = switch (job.status) { Status.scheduled => job.due ? Colors.red : Colors.blue, Status.sent => Colors.green, Status.cancelled => Colors.grey };
    final label = job.status == Status.scheduled && job.due ? 'Due' : titleCase(job.status.name);
    return Chip(label: Text(label), backgroundColor: color.withAlpha(25), labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold));
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => CleanCard(children: [
        Icon(icon, size: 38, color: const Color(0xFF2563EB)),
        const SizedBox(height: 8),
        Center(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        const SizedBox(height: 4),
        Center(child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))),
      ]);
}

class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.title, required this.children, this.fab, this.icon, this.subtitle});
  final String title;
  final List<Widget> children;
  final VoidCallback? fab;
  final IconData? icon;
  final String? subtitle;
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent, elevation: 0),
        floatingActionButton: fab == null ? null : FloatingActionButton.extended(onPressed: fab, icon: const Icon(Icons.add), label: const Text('Add')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [HeroPanel(title: title, subtitle: subtitle ?? '', icon: icon ?? Icons.apps), gap, ...children]),
      );
}

class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF111827), Color(0xFF1D4ED8)]),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Colors.white, size: 34),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          if (subtitle.isNotEmpty) ...[const SizedBox(height: 6), Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.35))],
        ]),
      );
}

class CleanCard extends StatelessWidget {
  const CleanCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)));
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            if (subtitle != null) Text(subtitle!, style: const TextStyle(color: Colors.black54)),
          ])),
        ]),
      );
}

class FilterChipRow extends StatelessWidget {
  const FilterChipRow({super.key, required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [Expanded(child: Chip(label: Text(label))), TextButton(onPressed: onClear, child: const Text('Clear'))]),
      );
}

class Sheet extends StatelessWidget {
  const Sheet({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext c) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: ListView(shrinkWrap: true, children: children),
      );
}

final roundedShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(24));
const gap = SizedBox(height: 12);
const head = TextStyle(fontSize: 24, fontWeight: FontWeight.w900);
const spacingOptions = ['once', 'test15', 'test30', 'test60', 'daily', 'weekly', 'monthly'];

String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _t(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String monthName(int month) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
String titleCase(String value) => value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
String spacingLabel(String spacing) => switch (spacing) { 'test15' => '15 seconds apart (test)', 'test30' => '30 seconds apart (test)', 'test60' => '60 seconds apart (test)', 'daily' => 'Daily', 'weekly' => 'Weekly', 'monthly' => 'Monthly', _ => 'Once' };
int cappedCopies(String spacing, int copies) => spacing == 'once' ? 1 : spacing.startsWith('test') ? copies.clamp(1, 3) : copies.clamp(1, 10);
DateTime spacedTime(DateTime start, String spacing, int index) => switch (spacing) { 'test15' => start.add(Duration(seconds: 15 * index)), 'test30' => start.add(Duration(seconds: 30 * index)), 'test60' => start.add(Duration(seconds: 60 * index)), 'daily' => start.add(Duration(days: index)), 'weekly' => start.add(Duration(days: 7 * index)), 'monthly' => DateTime(start.year, start.month + index, start.day, start.hour, start.minute), _ => start };
IconData iconForStatus(String status) => switch (status) { 'sent' => Icons.send, 'delivered' => Icons.done_all, 'failed' => Icons.error_outline, 'blocked' => Icons.block, 'triggered' => Icons.alarm, _ => Icons.info_outline };
Color colorForStatus(String status) => switch (status) { 'sent' => Colors.blue, 'delivered' => Colors.green, 'failed' => Colors.red, 'blocked' => Colors.orange, 'triggered' => Colors.purple, _ => Colors.grey };
