class BackgroundSetupStep {
  const BackgroundSetupStep({
    required this.title,
    required this.description,
    required this.isComplete,
  });

  final String title;
  final String description;
  final bool isComplete;
}

class BackgroundSetupChecklist {
  const BackgroundSetupChecklist({
    required this.smsPermissionGranted,
    required this.exactAlarmAllowed,
    required this.hasQueuedTexts,
    required this.hasTestNumber,
  });

  final bool smsPermissionGranted;
  final bool exactAlarmAllowed;
  final bool hasQueuedTexts;
  final bool hasTestNumber;

  List<BackgroundSetupStep> get steps {
    return [
      BackgroundSetupStep(
        title: 'SMS permission',
        description: 'Required so Android can send scheduled SMS messages.',
        isComplete: smsPermissionGranted,
      ),
      BackgroundSetupStep(
        title: 'Exact alarm permission',
        description: 'Required for more reliable closed-app scheduling.',
        isComplete: exactAlarmAllowed,
      ),
      BackgroundSetupStep(
        title: 'Queued texts',
        description: 'At least one unsent text must be queued.',
        isComplete: hasQueuedTexts,
      ),
      BackgroundSetupStep(
        title: 'Test number',
        description: 'At least one contact should be marked as a test number.',
        isComplete: hasTestNumber,
      ),
    ];
  }

  bool get ready {
    return smsPermissionGranted &&
        exactAlarmAllowed &&
        hasQueuedTexts &&
        hasTestNumber;
  }
}
