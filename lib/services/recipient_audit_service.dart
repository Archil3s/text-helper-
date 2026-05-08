import '../models/appointment_reminder.dart';
import '../models/nz_sms_recipient.dart';
import '../models/recipient_audit_item.dart';
import 'appointment_reminder_store.dart';
import 'nz_recipient_store.dart';

class RecipientAuditService {
  RecipientAuditService({
    AppointmentReminderStore? reminderStore,
    NzRecipientStore? recipientStore,
  })  : _reminderStore = reminderStore ?? AppointmentReminderStore(),
        _recipientStore = recipientStore ?? NzRecipientStore();

  final AppointmentReminderStore _reminderStore;
  final NzRecipientStore _recipientStore;

  Future<List<RecipientAuditItem>> buildAuditItems() async {
    final reminders = await _reminderStore.loadReminders();
    final contacts = await _recipientStore.loadRecipients();

    final pending = reminders.where((item) => !item.isSent).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return pending.map((reminder) {
      final contact = _findContact(reminder, contacts);
      final rawPhone = reminder.phoneNumber.trim();
      final normalized = normalizePhoneNumber(rawPhone);
      final warnings = <String>[];

      if (rawPhone.isEmpty) {
        warnings.add('Phone number is empty.');
      }

      if (!_looksLikePhoneNumber(rawPhone)) {
        warnings.add('Phone number has suspicious characters or length.');
      }

      if (normalized != rawPhone) {
        warnings.add('Country-code normalization would change this number.');
      }

      if (!normalized.startsWith('+')) {
        warnings.add('Number has no explicit country code.');
      }

      if (contact == null) {
        warnings.add('No saved contact matches this reminder.');
      } else {
        if (!contact.consented) {
          warnings.add('Contact is not marked as consented.');
        }

        if (contact.number.trim() != rawPhone) {
          warnings.add('Reminder number differs from saved contact number.');
        }
      }

      if (reminder.message.trim().isEmpty) {
        warnings.add('Final message is empty.');
      }

      if (reminder.scheduledAt.isBefore(DateTime.now())) {
        warnings.add('Scheduled time is in the past.');
      }

      return RecipientAuditItem(
        id: reminder.id,
        contactName: contact?.name.trim().isNotEmpty == true
            ? contact!.name.trim()
            : 'Unknown contact',
        phoneNumber: rawPhone,
        normalizedPhoneNumber: normalized,
        groupLabel: _groupLabel(reminder, contact),
        message: reminder.message,
        testState: contact?.isTestNumber == true ? 'TEST NUMBER' : 'LIVE',
        scheduledAtLabel: _formatDateTime(reminder.scheduledAt),
        warnings: warnings,
        isBlocked: warnings.any(
          (warning) =>
              warning.contains('empty') ||
              warning.contains('suspicious') ||
              warning.contains('not marked as consented'),
        ),
      );
    }).toList();
  }

  NzSmsRecipient? _findContact(
    AppointmentReminder reminder,
    List<NzSmsRecipient> contacts,
  ) {
    for (final contact in contacts) {
      if (contact.id == reminder.contactId && reminder.contactId.isNotEmpty) {
        return contact;
      }
    }

    for (final contact in contacts) {
      if (normalizePhoneNumber(contact.number) ==
          normalizePhoneNumber(reminder.phoneNumber)) {
        return contact;
      }
    }

    return null;
  }

  String _groupLabel(AppointmentReminder reminder, NzSmsRecipient? contact) {
    if (contact == null) {
      return reminder.contactId.isEmpty
          ? 'Direct / no contact link'
          : 'Contact ID: ${reminder.contactId}';
    }

    if (contact.isTestNumber) {
      return 'Test Numbers';
    }

    if (reminder.templateName.trim().isNotEmpty) {
      return 'Template: ${reminder.templateName}';
    }

    return 'Saved contact';
  }

  String normalizePhoneNumber(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    final keepPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return trimmed;
    }

    if (keepPlus) {
      return '+$digits';
    }

    if (digits.startsWith('00') && digits.length > 4) {
      return '+${digits.substring(2)}';
    }

    if (digits.startsWith('64')) {
      return '+$digits';
    }

    if (digits.startsWith('0') && digits.length >= 8) {
      return '+64${digits.substring(1)}';
    }

    return digits;
  }

  bool _looksLikePhoneNumber(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return false;
    }

    if (!RegExp(r'^\+?[0-9\s\-\(\)]{7,20}$').hasMatch(trimmed)) {
      return false;
    }

    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');

    return digits.length >= 7 && digits.length <= 15;
  }

  String _formatDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}
