import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../ui/widgets.dart';
import '../../memory/application/memory_review_controller.dart';
import '../../memory/domain/memory_item.dart';
import 'memory_card.dart';

const _swipeThreshold = 120.0;

class MemorySwipeDeck extends ConsumerStatefulWidget {
  const MemorySwipeDeck({
    this.onBrowseKept,
    super.key,
  });

  final VoidCallback? onBrowseKept;

  @override
  ConsumerState<MemorySwipeDeck> createState() => _MemorySwipeDeckState();
}

class _MemorySwipeDeckState extends ConsumerState<MemorySwipeDeck> {
  double _dragX = 0;
  double _dragY = 0;
  bool _animatingOut = false;

  @override
  Widget build(BuildContext context) {
    final deckAsync = ref.watch(memoryReviewDeckProvider);
    final pendingAsync = ref.watch(memoryPendingCountProvider);
    final mode = ref.watch(memoryReviewModeProvider);

    return deckAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Could not load memories')),
      data: (deck) {
        if (deck.queue.isEmpty) {
          return _EmptyDeck(
            pendingCount: pendingAsync.asData?.value ?? 0,
            mode: mode,
            onBrowseKept: widget.onBrowseKept,
            onShowAll: () => ref
                .read(memoryReviewDeckProvider.notifier)
                .setMode(MemoryReviewMode.all),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${deck.position} of ${deck.total} to review',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if ((pendingAsync.asData?.value ?? 0) > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AlterPalette.amber.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${pendingAsync.asData?.value} pending',
                      style: TextStyle(
                        color: AlterPalette.amber,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                PillChip(
                  label: mode == MemoryReviewMode.pendingOnly
                      ? 'Pending only'
                      : 'All memories',
                  selected: true,
                  onTap: () {
                    final next = mode == MemoryReviewMode.pendingOnly
                        ? MemoryReviewMode.all
                        : MemoryReviewMode.pendingOnly;
                    ref.read(memoryReviewDeckProvider.notifier).setMode(next);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardHeight = math.max(
                    280.0,
                    math.min(constraints.maxHeight, 420.0),
                  );
                  if (deck.current == null) {
                    return const SizedBox.shrink();
                  }
                  return Align(
                    alignment: Alignment.topCenter,
                    child: Material(
                      elevation: 10,
                      shadowColor: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.transparent,
                      child: _DraggableMemoryCard(
                        item: deck.current!,
                        width: constraints.maxWidth,
                        height: cardHeight,
                        dragX: _dragX,
                        dragY: _dragY,
                        animatingOut: _animatingOut,
                        onDragUpdate: (dx, dy) {
                          if (_animatingOut) return;
                          setState(() {
                            _dragX = dx;
                            _dragY = dy;
                          });
                        },
                        onDragEnd: () => _handleDragEnd(),
                        onEdit: () => _showEditSheet(deck.current!),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Forget',
                    icon: LucideIcons.x,
                    color: AlterPalette.danger,
                    onTap: () => _actForget(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: 'Keep',
                    icon: LucideIcons.check,
                    color: AlterPalette.mint,
                    onTap: () => _actKeep(),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _actKeep() async {
    if (_animatingOut) return;
    setState(() {
      _animatingOut = true;
      _dragX = 400;
    });
    await Future<void>.delayed(const Duration(milliseconds: 220));
    await ref.read(memoryReviewDeckProvider.notifier).keepCurrent();
    _resetDrag();
  }

  Future<void> _actForget() async {
    if (_animatingOut) return;
    setState(() {
      _animatingOut = true;
      _dragX = -400;
    });
    await Future<void>.delayed(const Duration(milliseconds: 220));
    await ref.read(memoryReviewDeckProvider.notifier).forgetCurrent();
    _resetDrag();
  }

  Future<void> _handleDragEnd() async {
    if (_dragX > _swipeThreshold) {
      await _actKeep();
      return;
    }
    if (_dragX < -_swipeThreshold) {
      await _actForget();
      return;
    }
    setState(() {
      _dragX = 0;
      _dragY = 0;
    });
  }

  void _resetDrag() {
    setState(() {
      _dragX = 0;
      _dragY = 0;
      _animatingOut = false;
    });
  }

  Future<void> _showEditSheet(MemoryItem item) async {
    final titleCtrl = TextEditingController(text: item.title);
    final contentCtrl = TextEditingController(text: item.content);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.paddingOf(ctx).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit memory',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: contentCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'What ALTER learned'),
            ),
            const SizedBox(height: 16),
            LimeButton(
              label: 'Save',
              onTap: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      await ref.read(memoryReviewDeckProvider.notifier).correctCurrent(
            title: titleCtrl.text.trim(),
            content: contentCtrl.text.trim(),
          );
    }
    titleCtrl.dispose();
    contentCtrl.dispose();
  }
}

class _DraggableMemoryCard extends StatelessWidget {
  const _DraggableMemoryCard({
    required this.item,
    required this.width,
    required this.height,
    required this.dragX,
    required this.dragY,
    required this.animatingOut,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onEdit,
  });

  final MemoryItem item;
  final double width;
  final double height;
  final double dragX;
  final double dragY;
  final bool animatingOut;
  final void Function(double dx, double dy) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final rotation = (dragX / 300).clamp(-0.12, 0.12);
    final keepOpacity = (dragX / _swipeThreshold).clamp(0.0, 1.0);
    final forgetOpacity = (-dragX / _swipeThreshold).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: animatingOut
          ? null
          : (d) => onDragUpdate(dragX + d.delta.dx, dragY + d.delta.dy),
      onPanEnd: animatingOut ? null : (_) => onDragEnd(),
      child: Transform.translate(
        offset: Offset(dragX, dragY),
        child: Transform.rotate(
          angle: rotation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MemoryCard(item: item, onEdit: onEdit),
                  MemorySwipeOverlay(
                    keepOpacity: keepOpacity,
                    forgetOpacity: forgetOpacity,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.55)),
            color: color.withValues(alpha: 0.16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck({
    required this.pendingCount,
    required this.mode,
    this.onBrowseKept,
    this.onShowAll,
  });

  final int pendingCount;
  final MemoryReviewMode mode;
  final VoidCallback? onBrowseKept;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.brain,
              size: 48,
              color: AlterPalette.aura.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              mode == MemoryReviewMode.pendingOnly && pendingCount == 0
                  ? 'Nothing to review'
                  : 'All caught up',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'ALTER only remembers what you confirm matters. '
              'New facts from voice and LifeShield appear here for you to keep or forget.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (mode == MemoryReviewMode.pendingOnly && onShowAll != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onShowAll, child: const Text('Review all memories')),
            ],
            if (onBrowseKept != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onBrowseKept,
                child: const Text('Browse kept memories'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
