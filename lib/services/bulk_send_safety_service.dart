import '../models/nz_sms_recipient.dart';
import 'nz_recipient_store.dart';
import 'rate_limit_service.dart';

class BulkSendSafetyReport {
  const BulkSendSafetyReport({
    required this.totalContacts,
    required this.consentedContacts,
    required this.testContacts,
    required this.liveContacts,
    required this.suspiciousContacts,
    required this.largeBatchWarning,
    required this.estimatedMinutes,
    required this.estimatedHours,
    required this.maxPerMinute,
    required this.maxPerHour,
    required this.maxPerDay,
    required this.previewRows,
  });

  final int totalContacts;
  final int consentedContacts;
  final int testContacts;
  final int liveContacts;
  final int suspiciousContacts;
  final bool largeBatchWarning;
  final int estimatedMinutes;
  final int estimatedHours;
  final int maxPerMinute;
  final int maxPerHour;
  final int maxPerDay;
  final List<BulkSendPreviewRow> previewRows;

  bool get exceedsDailyLimit => consentedContacts > maxPerDay;
  bool get exceedsHourlyLimit => consentedContacts > maxPerHour;
  bool get exceedsMinuteLimit => consentedContacts > maxPerMinute;

  bool get safeForImmediateSend {
    return consentedContacts > 0 &&
        !largeBatchWarning &&
        suspiciousContacts == 0 &&
        !exceedsDailyLimit;
  }
}

class BulkSendPreviewRow {
  const BulkSendPreviewRow({
    required this.name,
    required this.phoneNumber,
    required this.testMode,
    required this.warning,
  });

  final String name;
  final String phoneNumber;
  final bool testMode;
  final String warning;
}

class BulkSendSafetyService {
  BulkSendSafetyService({NzRecipientStore? recipientStore})
      : _recipientStore = recipientStore ?? NzRecipientStore();

  final NzRecipientStore _recipientStore;

  Future<BulkSendSafetyReport> buildReport() async {
    final contacts = await _recipientStore.loadRecipients();
    final consented = contacts.where((item) => item.consented).toList();
    final testContacts = consented.where((item) => item.isTestNumber).length;
    final liveContacts = consented.length - testContacts;

    final previewRows = consented
        .take(25)
        .map(
          (item) => BulkSendPreviewRow(
            name: item.name,
            phoneNumber: item.number,
            testMode: item.isTestNumber,
            warning: _warningFor(item),
          ),
        )
        .toList();

    final suspiciousContacts =
        consented.where((item) => _warningFor(item).isNotEmpty).length;

    final estimatedMinutes = _estimateMinutes(consented.length);
    final estimatedHours = (estimatedMinutes / 60).ceil();

    return BulkSendSafetyReport(
      totalContacts: contacts.length,
      consentedContacts: consented.length,
      testContacts: testContacts,
      liveContacts: liveContacts,
      suspiciousContacts: suspiciousContacts,
      largeBatchWarning: consented.length > RateLimitService.maxPerDay,
      estimatedMinutes: estimatedMinutes,
      estimatedHours: estimatedHours,
      maxPerMinute: RateLimitService.maxPerMinute,
      maxPerHour: RateLimitService.maxPerHour,
      maxPerDay: RateLimitService.maxPerDay,
      previewRows: previewRows,
    );
  }

  int _estimateMinutes(int count) {
    if (count <= 0) {
      return 0;
    }

    return (count / RateLimitService.maxPerMinute).ceil();
  }

  String _warningFor(NzSmsRecipient contact) {
    final number = contact.number.trim();

    if (number.isEmpty) {
      return 'Missing phone number';
    }

    if (number.length < 7) {
      return 'Phone number looks too short';
    }

    if (!number.startsWith('+') && !number.startsWith('0')) {
      return 'Phone number may need a country or local prefix';
    }

    final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) {
      return 'Phone number has too few digits';
    }

    return '';
  }
}
