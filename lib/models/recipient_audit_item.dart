class RecipientAuditItem {
  const RecipientAuditItem({
    required this.id,
    required this.contactName,
    required this.phoneNumber,
    required this.normalizedPhoneNumber,
    required this.groupLabel,
    required this.message,
    required this.testState,
    required this.scheduledAtLabel,
    required this.warnings,
    required this.isBlocked,
  });

  final String id;
  final String contactName;
  final String phoneNumber;
  final String normalizedPhoneNumber;
  final String groupLabel;
  final String message;
  final String testState;
  final String scheduledAtLabel;
  final List<String> warnings;
  final bool isBlocked;

  bool get hasWarnings => warnings.isNotEmpty;

  bool get hasNormalizationChange =>
      phoneNumber.trim() != normalizedPhoneNumber.trim();
}
