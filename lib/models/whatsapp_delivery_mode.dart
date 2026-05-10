enum WhatsAppDeliveryMode {
  manualHandoff,
  businessApiTemplates,
}

extension WhatsAppDeliveryModeLabel on WhatsAppDeliveryMode {
  String get title {
    switch (this) {
      case WhatsAppDeliveryMode.manualHandoff:
        return 'Manual handoff';
      case WhatsAppDeliveryMode.businessApiTemplates:
        return 'Business API templates';
    }
  }

  String get description {
    switch (this) {
      case WhatsAppDeliveryMode.manualHandoff:
        return 'Open WhatsApp with a prepared draft. The user presses Send manually.';
      case WhatsAppDeliveryMode.businessApiTemplates:
        return 'Prepare approved WhatsApp Business template messaging through a secure backend.';
    }
  }

  bool get requiresBackend {
    switch (this) {
      case WhatsAppDeliveryMode.manualHandoff:
        return false;
      case WhatsAppDeliveryMode.businessApiTemplates:
        return true;
    }
  }
}
