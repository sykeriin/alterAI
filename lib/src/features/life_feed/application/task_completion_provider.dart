import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final taskCompletionProvider =
    NotifierProvider<TaskCompletionNotifier, Set<String>>(
  TaskCompletionNotifier.new,
);

/// Persists dashboard task checkbox state locally.
class TaskCompletionNotifier extends Notifier<Set<String>> {
  static const _prefsKey = 'alter_task_done_ids';

  @override
  Set<String> build() {
    Future.microtask(_load);
    return {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const [];
    state = raw.toSet();
  }

  Future<void> toggle(String taskId) async {
    final next = Set<String>.from(state);
    if (next.contains(taskId)) {
      next.remove(taskId);
    } else {
      next.add(taskId);
    }
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, next.toList());
  }

  bool isDone(String taskId) => state.contains(taskId);
}
