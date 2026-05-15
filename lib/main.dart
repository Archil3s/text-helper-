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
  Timer? dueRefreshTimer;

  @override
  void initState() {
    super.initState();
    load();
    dueRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
      loadNativeLogs(silent: true);
    });
  }

  @override
  void dispose() {
    dueRefreshTimer?.cancel();
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
      if (!silent) snack('Diagnostics refreshed.');
    } catch (error) {
      if (!silent) snack('Could not read diagnostics: $error');
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
      if (!canExact) snack('Exact alarm permission may be needed for precise closed-app sending.');
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
        if (showResult) snack('Auto-send disabled. Background alarms cancelled.');
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
      if (showResult) snack('Auto-send enabled. $count background alarm${count == 1 ? '' : 's'} synced.');
    } catch (error) {
      if (showResult) snack('Could not sync background alarms: $error');
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
      final opened = await launchUrl(Uri(scheme: 'sms', path: phone.trim(), queryParameters: text.trim().isEmpty ? null : {'body': text.trim()}), mode: LaunchMode.externalApplication);
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
          if (jobs[n].contactId == r.id && jobs[n].status == Status.scheduled) jobs[n] = jobs[n].copy(name: r.name, phone: r.phone);
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
    snack(autoSend ? '$count scheduled send${count == 1 ? '' : 's'} synced for auto-send.' : '$count scheduled send${count == 1 ? '' : 's'} saved. Enable auto-send for closed-app sending.');
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
        SchedulePage(jobs: jobs, autoSend: autoSend, nativeEvents: nativeEvents, lastSyncedAlarmCount: lastSyncedAlarmCount, lastLogRefresh: lastLogRefresh, onToggleAutoSend: setAutoSend, onSyncAlarms: () => syncNativeAlarms(showResult: true), onRefreshLogs: () => loadNativeLogs(silent: false), onEdit: editJob, onOpen: (j) => openSms(j.phone, j.text), onSent: (j) { setState(() => jobs[jobs.indexOf(j)] = j.copy(status: Status.sent)); save(); snack('Marked sent.'); }, onCancel: (j) { setState(() => jobs[jobs.indexOf(j)] = j.copy(status: Status.cancelled)); save(); snack('Schedule cancelled.'); }),
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
  void dispose() { phone.dispose(); msg.dispose(); super.dispose(); }
  Contact? get selected { for (final x in widget.contacts) { if (x.id == id) return x; } return null; }
  @override
  Widget build(BuildContext c) => Page(title: 'SMS', icon: Icons.sms, subtitle: 'Pick a saved contact or type a number. Your SMS app opens with the draft ready to review.', children: [
    DropdownButtonFormField<String>(initialValue: widget.contacts.any((x) => x.id == id) ? id : '', items: [const DropdownMenuItem(value: '', child: Text('Manual number')), ...widget.contacts.map((x) => DropdownMenuItem(value: x.id, child: Text('${x.name} • ${x.phone}')))], onChanged: (v) => setState(() { id = v ?? ''; if (selected != null) phone.text = selected!.phone; }), decoration: const InputDecoration(labelText: 'Saved contact')),
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
    return Page(title: 'Scheduler', icon: Icons.event_note, subtitle: '$due due • $upcoming upcoming. Tap a calendar day to filter.', fab: () => widget.onEdit(null), children: [
      Card(child: SwitchListTile(value: widget.autoSend, onChanged: widget.onToggleAutoSend, title: const Text('Auto-send scheduled SMS'), subtitle: const Text('Uses Android SMS permission and alarms. Only explicit scheduled messages are sent.'), secondary: Icon(widget.autoSend ? Icons.send : Icons.sms_outlined))),
      Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 8, children: [TextButton.icon(onPressed: widget.onSyncAlarms, icon: const Icon(Icons.sync), label: const Text('Sync alarms')), TextButton.icon(onPressed: widget.onRefreshLogs, icon: const Icon(Icons.receipt_long), label: const Text('Refresh logs'))])),
      DiagnosticsCard(autoSend: widget.autoSend, alarmCount: widget.lastSyncedAlarmCount, lastRefresh: widget.lastLogRefresh, events: widget.nativeEvents),
      SchedulerCalendar(month: calendarMonth, selectedDay: selectedDay, jobs: widget.jobs, onPrevious: () => setState(() => calendarMonth = DateTime(calendarMonth.year, calendarMonth.month - 1)), onNext: () => setState(() => calendarMonth = DateTime(calendarMonth.year, calendarMonth.month + 1)), onPickDay: (day) => setState(() => selectedDay = selectedDay != null && sameDay(selectedDay!, day) ? null : day)),
      if (selectedDay != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(child: Text('Showing ${_d(selectedDay!)}', style: const TextStyle(fontWeight: FontWeight.bold))), TextButton(onPressed: () => setState(() => selectedDay = null), child: const Text('Clear'))])),
      if (filtered.isEmpty) const EmptyCard(icon: Icons.event_note, title: 'No scheduled texts', message: 'Tap + to schedule a message, or schedule one directly from a contact.'),
      ...filtered.map((j) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(j.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))), StatusPill(job: j)]),
        Text(j.phone, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 6),
        Text('${_d(j.time)} ${_t(j.time)} ${j.due ? '• due now' : '• upcoming'}', style: TextStyle(color: j.status == Status.scheduled && j.due ? Colors.red : Colors.black54, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(j.text),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [FilledButton.tonalIcon(onPressed: j.status == Status.scheduled ? () => widget.onOpen(j) : null, icon: const Icon(Icons.sms), label: const Text('Open SMS')), OutlinedButton(onPressed: () => widget.onEdit(j), child: const Text('Edit')), OutlinedButton(onPressed: j.status == Status.scheduled ? () => widget.onSent(j) : null, child: const Text('Sent')), OutlinedButton(onPressed: j.status == Status.scheduled ? () => widget.onCancel(j) : null, child: const Text('Cancel'))])
      ]))))
    ]);
  }
}

class DiagnosticsCard extends StatelessWidget {
  const DiagnosticsCard({super.key, required this.autoSend, required this.alarmCount, required this.lastRefresh, required this.events});
  final bool autoSend;
  final int alarmCount;
  final DateTime? lastRefresh;
  final List<NativeLogEvent> events;

  @override
  Widget build(BuildContext context) {
    final last = events.isEmpty ? null : events.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Expanded(child: Text('Send diagnostics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))), Chip(label: Text(autoSend ? 'auto-send on' : 'auto-send off'))]),
          Text('Last synced alarms: $alarmCount'),
          Text('Last refresh: ${lastRefresh == null ? 'never' : _t(lastRefresh!)}'),
          if (last != null) ...[
            const SizedBox(height: 8),
            Text('Latest: ${last.title} • ${last.status}', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (last.phone.isNotEmpty) Text(last.phone, style: const TextStyle(color: Colors.black54)),
            if (last.detail.isNotEmpty) Text(last.detail, style: const TextStyle(color: Colors.black54)),
          ],
          const SizedBox(height: 10),
          if (events.isEmpty)
            const Text('No native send events yet. Send a scheduled SMS, then tap Refresh logs.')
          else
            ...events.take(5).map((e) => Padding(padding: const EdgeInsets.only(top: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(iconForStatus(e.status), size: 18, color: colorForStatus(e.status)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${e.title} • ${e.status}', style: const TextStyle(fontWeight: FontWeight.w700)), Text('${_d(e.createdAt)} ${_t(e.createdAt)} ${e.phone}', style: const TextStyle(color: Colors.black54)), if (e.detail.isNotEmpty) Text(e.detail, style: const TextStyle(color: Colors.black54))]))]))),
        ]),
      ),
    );
  }
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
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
      Row(children: [IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)), Expanded(child: Center(child: Text('${monthName(month.month)} ${month.year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))), IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right))]),
      const Row(children: [Expanded(child: Center(child: Text('M', style: TextStyle(fontWeight: FontWeight.bold)))), Expanded(child: Center(child: Text('T', style: TextStyle(fontWeight: FontWeight.bold)))), Expanded(child: Center(child: Text('W', style: TextStyle(fontWeight: FontWeight.bold)))), Expanded(child: Center(child: Text('T', style: TextStyle(fontWeight: FontWeight.bold)))), Expanded(child: Center(child: Text('F', style: TextStyle(fontWeight: FontWeight.bold)))), Expanded(child: Center(child: Text('S', style: TextStyle(fontWeight: FontWeight.bold)))), Expanded(child: Center(child: Text('S', style: TextStyle(fontWeight: FontWeight.bold))))]),
      const SizedBox(height: 8),
      GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: cellCount, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 6, mainAxisSpacing: 6), itemBuilder: (context, index) {
        if (index < leadingBlanks) return const SizedBox.shrink();
        final day = index - leadingBlanks + 1;
        final date = DateTime(month.year, month.month, day);
        final count = jobs.where((job) => sameDay(job.time, date)).length;
        final isToday = sameDay(date, DateTime.now());
        final isSelected = selectedDay != null && sameDay(date, selectedDay!);
        return InkWell(borderRadius: BorderRadius.circular(12), onTap: () => onPickDay(date), child: Container(decoration: BoxDecoration(color: isSelected ? const Color(0xFF0A84FF) : count > 0 ? const Color(0x1A0A84FF) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isToday ? const Color(0xFF0A84FF) : const Color(0xFFE5E7EB), width: isToday ? 2 : 1)), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('$day', style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black)), if (count > 0) Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF0A84FF)))]))));
      }),
    ])));
  }
}

class ContactForm extends StatefulWidget { const ContactForm(this.c, {super.key}); final Contact? c; @override State<ContactForm> createState() => _ContactFormState(); }
class _ContactFormState extends State<ContactForm> {
  late final name = TextEditingController(text: widget.c?.name ?? '');
  late final phone = TextEditingController(text: widget.c?.phone ?? '');
  late final note = TextEditingController(text: widget.c?.note ?? '');
  @override
  Widget build(BuildContext c) => Sheet(children: [Text(widget.c == null ? 'Add contact' : 'Edit contact', style: head), gap, TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')), gap, TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')), gap, TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Note')), gap, FilledButton(onPressed: saveContact, child: const Text('Save contact'))]);
  void saveContact() {
    if (name.text.trim().isEmpty || phone.text.trim().length < 7) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and a valid phone number are required.'))); return; }
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
  String spacing = 'once';
  int copies = 1;
  Contact? get contact { for (final x in widget.contacts) { if (x.id == id) return x; } return null; }
  bool get editing => widget.job != null;

  @override
  Widget build(BuildContext c) => Sheet(children: [
    Text(widget.job == null ? 'Schedule text' : 'Edit schedule', style: head), gap,
    DropdownButtonFormField<String>(initialValue: widget.contacts.any((x) => x.id == id) ? id : '', items: [const DropdownMenuItem(value: '', child: Text('Custom recipient')), ...widget.contacts.map((x) => DropdownMenuItem(value: x.id, child: Text('${x.name} • ${x.phone}')))], onChanged: (v) => setState(() => id = v ?? ''), decoration: const InputDecoration(labelText: 'Contact')),
    gap,
    if (id.isEmpty) ...[TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')), gap, TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')), gap],
    TextField(controller: msg, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Message')),
    gap,
    Row(children: [Expanded(child: OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.calendar_today), label: Text(_d(time)))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: pickTime, icon: const Icon(Icons.access_time), label: Text(_t(time))))]),
    gap,
    const Text('Quick test time', style: TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 6),
    Wrap(spacing: 8, runSpacing: 8, children: [ActionChip(label: const Text('+15 sec'), avatar: const Icon(Icons.timer, size: 18), onPressed: () => quickDelay(15)), ActionChip(label: const Text('+30 sec'), avatar: const Icon(Icons.timer, size: 18), onPressed: () => quickDelay(30)), ActionChip(label: const Text('+60 sec'), avatar: const Icon(Icons.timer, size: 18), onPressed: () => quickDelay(60)), ActionChip(label: const Text('+5 min'), avatar: const Icon(Icons.schedule, size: 18), onPressed: () => quickDelay(300))]),
    if (!editing) ...[
      gap,
      DropdownButtonFormField<String>(initialValue: spacing, decoration: const InputDecoration(labelText: 'Create more visible sends'), items: spacingOptions.map((item) => DropdownMenuItem(value: item, child: Text(spacingLabel(item)))).toList(), onChanged: (value) => setState(() { spacing = value ?? 'once'; if (spacing == 'once') copies = 1; })),
      gap,
      DropdownButtonFormField<int>(initialValue: copies, decoration: const InputDecoration(labelText: 'How many sends to create'), items: [1, 2, 3, 5, 10].map((n) => DropdownMenuItem(value: n, child: Text('$n send${n == 1 ? '' : 's'}'))).toList(), onChanged: spacing == 'once' ? null : (value) => setState(() => copies = value ?? 1)),
      if (spacing.startsWith('test')) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Testing spacing is capped to 3 visible sends.', style: TextStyle(color: Colors.black54))),
    ],
    gap,
    Text('Selected: ${_d(time)} ${_t(time)}', style: const TextStyle(color: Colors.black54)),
    gap,
    FilledButton(onPressed: saveJob, child: Text(editing ? 'Save schedule' : 'Create schedule'))
  ]);

  void quickDelay(int seconds) => setState(() => time = DateTime.now().add(Duration(seconds: seconds)));
  Future<void> pickDate() async { final p = await showDatePicker(context: context, initialDate: time, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730))); if (p != null) setState(() => time = DateTime(p.year, p.month, p.day, time.hour, time.minute)); }
  Future<void> pickTime() async { final p = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(time)); if (p != null) setState(() => time = DateTime(time.year, time.month, time.day, p.hour, p.minute)); }
  void saveJob() {
    final c = contact;
    final chosenPhone = c?.phone ?? phone.text.trim();
    if (chosenPhone.length < 7 || msg.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a contact or phone, and enter a message.'))); return; }
    if (!time.isAfter(DateTime.now())) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a future date and time.'))); return; }
    final baseName = c?.name ?? (name.text.trim().isEmpty ? chosenPhone : name.text.trim());
    final count = editing ? 1 : cappedCopies(spacing, copies);
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
  Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: Text(title)), floatingActionButton: fab == null ? null : FloatingActionButton.extended(onPressed: fab, icon: const Icon(Icons.add), label: const Text('Add')), body: ListView(padding: const EdgeInsets.all(18), children: [if (subtitle != null) HeroPanel(title: title, subtitle: subtitle!, icon: icon ?? Icons.apps), if (subtitle != null) gap, ...children]));
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
const spacingOptions = ['once', 'test15', 'test30', 'test60', 'daily', 'weekly', 'monthly'];
String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _t(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String monthName(int month) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
String spacingLabel(String spacing) => switch (spacing) { 'test15' => '15 seconds apart (test)', 'test30' => '30 seconds apart (test)', 'test60' => '60 seconds apart (test)', 'daily' => 'Daily', 'weekly' => 'Weekly', 'monthly' => 'Monthly', _ => 'Once' };
int cappedCopies(String spacing, int copies) => spacing == 'once' ? 1 : spacing.startsWith('test') ? copies.clamp(1, 3) : copies.clamp(1, 10);
DateTime spacedTime(DateTime start, String spacing, int index) => switch (spacing) { 'test15' => start.add(Duration(seconds: 15 * index)), 'test30' => start.add(Duration(seconds: 30 * index)), 'test60' => start.add(Duration(seconds: 60 * index)), 'daily' => start.add(Duration(days: index)), 'weekly' => start.add(Duration(days: 7 * index)), 'monthly' => DateTime(start.year, start.month + index, start.day, start.hour, start.minute), _ => start };
IconData iconForStatus(String status) => switch (status) { 'sent' => Icons.send, 'delivered' => Icons.done_all, 'failed' => Icons.error_outline, 'blocked' => Icons.block, 'triggered' => Icons.alarm, _ => Icons.info_outline };
Color colorForStatus(String status) => switch (status) { 'sent' => Colors.blue, 'delivered' => Colors.green, 'failed' => Colors.red, 'blocked' => Colors.orange, 'triggered' => Colors.purple, _ => Colors.grey };
