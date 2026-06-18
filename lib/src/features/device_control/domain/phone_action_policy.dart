enum PhoneActionSurface { agentDirect, openClawConfirmed }

enum PhoneActionRisk { safe, confirmationRequired, blocked }

class PhoneActionPolicyDecision {
  const PhoneActionPolicyDecision({
    required this.kind,
    required this.target,
    required this.risk,
    required this.requiresAccessibility,
    required this.reason,
  });

  final String kind;
  final String target;
  final PhoneActionRisk risk;
  final bool requiresAccessibility;
  final String reason;

  bool get requiresConfirmation => risk == PhoneActionRisk.confirmationRequired;

  bool canExecuteOn(PhoneActionSurface surface) {
    return switch (risk) {
      PhoneActionRisk.safe => true,
      PhoneActionRisk.confirmationRequired =>
        surface == PhoneActionSurface.openClawConfirmed,
      PhoneActionRisk.blocked => false,
    };
  }

  String get label => switch (risk) {
    PhoneActionRisk.safe => 'safe',
    PhoneActionRisk.confirmationRequired => 'confirm',
    PhoneActionRisk.blocked => 'blocked',
  };
}

class PhoneActionPolicy {
  const PhoneActionPolicy._();

  static PhoneActionPolicyDecision classify({
    required String kind,
    String target = '',
    bool requiresAccessibility = false,
  }) {
    final haystack = '$kind $target'.toLowerCase();

    if (_blocked.hasMatch(haystack)) {
      return PhoneActionPolicyDecision(
        kind: kind,
        target: target,
        risk: PhoneActionRisk.blocked,
        requiresAccessibility: requiresAccessibility,
        reason:
            'Blocked: ALTER cannot execute destructive, security-bypass, or credential-harvesting actions.',
      );
    }

    if (_confirm.hasMatch(haystack)) {
      return PhoneActionPolicyDecision(
        kind: kind,
        target: target,
        risk: PhoneActionRisk.confirmationRequired,
        requiresAccessibility: requiresAccessibility,
        reason:
            'Confirmation required: this can send, pay, install, approve, delete, or otherwise commit something.',
      );
    }

    if (kind == 'type_text' && _sensitiveText.hasMatch(target)) {
      return PhoneActionPolicyDecision(
        kind: kind,
        target: target,
        risk: PhoneActionRisk.confirmationRequired,
        requiresAccessibility: requiresAccessibility,
        reason:
            'Confirmation required: typed text may contain sensitive credentials, OTPs, or financial details.',
      );
    }

    return PhoneActionPolicyDecision(
      kind: kind,
      target: target,
      risk: PhoneActionRisk.safe,
      requiresAccessibility: requiresAccessibility,
      reason: 'Safe local action: reversible or user-confirmed by Android UI.',
    );
  }

  static final _confirm = RegExp(
    r'\b(send|pay|confirm|approve|install|buy|purchase|transfer|delete|allow|grant|submit|checkout|book|order)\b',
  );

  static final _blocked = RegExp(
    r'\b(factory\s*reset|erase\s+phone|wipe\s+device|disable\s+security|bypass|steal|exfiltrate|root\s+device|read\s+password|show\s+password|reveal\s+otp)\b',
  );

  static final _sensitiveText = RegExp(
    r'\b(otp|password|passcode|pin|cvv|card|upi|bank|ssn|aadhaar)\b',
    caseSensitive: false,
  );
}
