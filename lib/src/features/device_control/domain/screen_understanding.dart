import '../data/device_control_bridge.dart';
import 'phone_action_policy.dart';

enum ScreenElementRole { button, input, list, toggle, link, text, unknown }

class ScreenElement {
  const ScreenElement({
    required this.text,
    required this.role,
    required this.className,
    required this.viewId,
    required this.clickable,
    required this.editable,
    required this.scrollable,
    required this.centerX,
    required this.centerY,
    required this.policy,
  });

  factory ScreenElement.fromNode(VisibleNode node) {
    final role = _roleFor(node);
    return ScreenElement(
      text: node.text,
      role: role,
      className: node.className,
      viewId: node.viewId,
      clickable: node.clickable,
      editable: node.editable,
      scrollable: node.scrollable,
      centerX: node.centerX,
      centerY: node.centerY,
      policy: PhoneActionPolicy.classify(
        kind: node.editable ? 'type_text' : 'click_text',
        target: node.text,
        requiresAccessibility: true,
      ),
    );
  }

  final String text;
  final ScreenElementRole role;
  final String className;
  final String viewId;
  final bool clickable;
  final bool editable;
  final bool scrollable;
  final double centerX;
  final double centerY;
  final PhoneActionPolicyDecision policy;

  String get roleLabel => role.name;
}

class StructuredScreen {
  const StructuredScreen({
    required this.ok,
    required this.packageName,
    required this.className,
    required this.elements,
    required this.summary,
  });

  factory StructuredScreen.fromSnapshot(DeviceScreenSnapshot snapshot) {
    final elements = snapshot.nodes
        .map(ScreenElement.fromNode)
        .where((element) => element.text.trim().isNotEmpty)
        .toList(growable: false);
    return StructuredScreen(
      ok: snapshot.ok,
      packageName: snapshot.packageName,
      className: snapshot.className,
      elements: elements,
      summary: _summary(snapshot, elements),
    );
  }

  final bool ok;
  final String packageName;
  final String className;
  final List<ScreenElement> elements;
  final String summary;

  List<ScreenElement> get buttons => elements
      .where((element) => element.role == ScreenElementRole.button)
      .toList(growable: false);

  List<ScreenElement> get inputs => elements
      .where((element) => element.role == ScreenElementRole.input)
      .toList(growable: false);

  List<ScreenElement> get scrollables =>
      elements.where((element) => element.scrollable).toList(growable: false);

  String toAgentSummary({int maxItems = 24}) {
    if (!ok) return 'Accessibility screen read is unavailable.';
    final visible = elements
        .take(maxItems)
        .map((element) => '[${element.roleLabel}] ${element.text}')
        .join(' | ');
    return 'App: $packageName. ${summary.isEmpty ? visible : summary}. Visible: $visible';
  }

  static String _summary(
    DeviceScreenSnapshot snapshot,
    List<ScreenElement> elements,
  ) {
    if (!snapshot.ok) return snapshot.message;
    final buttonCount = elements
        .where((element) => element.role == ScreenElementRole.button)
        .length;
    final inputCount = elements
        .where((element) => element.role == ScreenElementRole.input)
        .length;
    final riskyCount = elements
        .where((element) => element.policy.requiresConfirmation)
        .length;
    return '$buttonCount buttons, $inputCount inputs, $riskyCount confirmation-gated controls.';
  }
}

ScreenElementRole _roleFor(VisibleNode node) {
  final klass = node.className.toLowerCase();
  final text = node.text.toLowerCase();
  if (node.editable || klass.contains('edittext')) {
    return ScreenElementRole.input;
  }
  if (klass.contains('switch') || klass.contains('checkbox')) {
    return ScreenElementRole.toggle;
  }
  if (node.scrollable ||
      klass.contains('recyclerview') ||
      klass.contains('list')) {
    return ScreenElementRole.list;
  }
  if (text.startsWith('http') || klass.contains('url')) {
    return ScreenElementRole.link;
  }
  if (node.clickable || klass.contains('button')) {
    return ScreenElementRole.button;
  }
  if (node.text.trim().isNotEmpty) return ScreenElementRole.text;
  return ScreenElementRole.unknown;
}
