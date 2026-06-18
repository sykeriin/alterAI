class ActionRuntimeResult {
  const ActionRuntimeResult({
    required this.reply,
    this.toolsUsed = const [],
  });

  final String reply;
  final List<String> toolsUsed;
}
