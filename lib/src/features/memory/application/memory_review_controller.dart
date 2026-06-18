import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/local/dao_providers.dart';
import '../../auth/application/auth_provider.dart';
import '../domain/memory_item.dart';
import 'memory_store.dart';

enum MemoryReviewMode { pendingOnly, all }

final memoryReviewModeProvider =
    StateProvider<MemoryReviewMode>((_) => MemoryReviewMode.all);

final memoryPendingCountProvider = FutureProvider<int>((ref) async {
  ref.watch(isDbUnlockedProvider);
  final userId = ref.watch(localUserIdProvider);
  if (userId == null) return 0;
  try {
    return await ref.read(memoryDaoProvider).countPendingReview(userId);
  } catch (_) {
    return 0;
  }
});

class MemoryReviewDeckState {
  const MemoryReviewDeckState({
    required this.queue,
    required this.currentIndex,
    required this.mode,
  });

  final List<MemoryItem> queue;
  final int currentIndex;
  final MemoryReviewMode mode;

  static MemoryReviewDeckState empty(MemoryReviewMode mode) =>
      MemoryReviewDeckState(queue: const [], currentIndex: 0, mode: mode);

  MemoryItem? get current {
    if (queue.isEmpty || currentIndex >= queue.length) return null;
    return queue[currentIndex];
  }

  MemoryItem? get next {
    final nextIndex = currentIndex + 1;
    if (nextIndex >= queue.length) return null;
    return queue[nextIndex];
  }

  int get total => queue.length;
  int get position => queue.isEmpty ? 0 : currentIndex + 1;
}

final memoryReviewDeckProvider =
    AsyncNotifierProvider<MemoryReviewDeckNotifier, MemoryReviewDeckState>(
  MemoryReviewDeckNotifier.new,
);

class MemoryReviewDeckNotifier extends AsyncNotifier<MemoryReviewDeckState> {
  @override
  Future<MemoryReviewDeckState> build() async {
    ref.watch(memoryReviewModeProvider);
    ref.watch(isDbUnlockedProvider);
    return _load();
  }

  Future<MemoryReviewDeckState> _load() async {
    final userId = ref.read(localUserIdProvider);
    final mode = ref.read(memoryReviewModeProvider);
    if (userId == null) return MemoryReviewDeckState.empty(mode);

    try {
      final dao = ref.read(memoryDaoProvider);
      final queue = mode == MemoryReviewMode.pendingOnly
          ? await dao.listUnconfirmed(userId, 200)
          : await dao.listReviewQueue(userId, 200);
      return MemoryReviewDeckState(
        queue: queue,
        currentIndex: 0,
        mode: mode,
      );
    } catch (_) {
      return MemoryReviewDeckState.empty(mode);
    }
  }

  Future<void> setMode(MemoryReviewMode mode) async {
    ref.read(memoryReviewModeProvider.notifier).state = mode;
    state = const AsyncLoading();
    state = AsyncData(await _load());
  }

  Future<void> reload() async {
    ref.invalidateSelf();
  }

  Future<void> keepCurrent() async {
    final deck = state.asData?.value;
    final item = deck?.current;
    if (item?.id == null) return;
    await ref.read(memoryStoreProvider.notifier).keep(item!.id!);
    _removeCurrentFromDeck();
  }

  Future<void> forgetCurrent() async {
    final deck = state.asData?.value;
    final item = deck?.current;
    if (item?.id == null) return;
    await ref.read(memoryStoreProvider.notifier).forget(item!.id!);
    _removeCurrentFromDeck();
  }

  Future<void> correctCurrent({String? title, String? content}) async {
    final deck = state.asData?.value;
    final item = deck?.current;
    if (item?.id == null) return;
    await ref.read(memoryStoreProvider.notifier).correct(
          item!.id!,
          title: title,
          content: content,
        );
    ref.invalidateSelf();
  }

  void _removeCurrentFromDeck() {
    final deck = state.asData?.value;
    if (deck == null || deck.queue.isEmpty) return;

    final newQueue = List<MemoryItem>.from(deck.queue);
    final idx = deck.currentIndex.clamp(0, newQueue.length - 1);
    newQueue.removeAt(idx);

    if (newQueue.isEmpty) {
      state = AsyncData(MemoryReviewDeckState.empty(deck.mode));
    } else {
      final newIdx = idx.clamp(0, newQueue.length - 1);
      state = AsyncData(
        MemoryReviewDeckState(
          queue: newQueue,
          currentIndex: newIdx,
          mode: deck.mode,
        ),
      );
    }
    ref.invalidate(memoryPendingCountProvider);
  }
}

final memoryKeptListProvider = FutureProvider<List<MemoryItem>>((ref) async {
  ref.watch(memoryStoreProvider);
  ref.watch(isDbUnlockedProvider);
  final userId = ref.watch(localUserIdProvider);
  if (userId == null) return const [];
  try {
    return await ref.read(memoryDaoProvider).listKept(userId, 200);
  } catch (_) {
    return const [];
  }
});
