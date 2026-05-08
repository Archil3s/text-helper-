class ScheduleValidationResult {
  const ScheduleValidationResult({
    required this.isValid,
    required this.warnings,
    required this.nextOccurrences,
  });

  final bool isValid;
  final List<String> warnings;
  final List<DateTime> nextOccurrences;
}

class RepeatConfig {
  const RepeatConfig({
    required this.rule,
    required this.customInterval,
    required this.customUnit,
    required this.windowStartHour,
    required this.windowStartMinute,
    required this.windowEndHour,
    required this.windowEndMinute,
  });

  final String rule;
  final int customInterval;
  final String customUnit;
  final int windowStartHour;
  final int windowStartMinute;
  final int windowEndHour;
  final int windowEndMinute;
}
