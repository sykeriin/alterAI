import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/life_os_providers.dart';
import 'life_os_style.dart';

class LifeFeedOsScreen extends ConsumerWidget {
  const LifeFeedOsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(lifeFeedProvider);
    return LifeOsScaffold(
      child: feed.when(
        loading: () => const _Loading(),
        error: (e, _) => _Message('Could not reach Life Feed.\n$e'),
        data: (data) {
          if (data == null) {
            return const _Message(
              'Sign in and set the backend gateway to see your Life Feed.',
            );
          }
          return _FeedBody(data: data, onRefresh: () => ref.invalidate(lifeFeedProvider));
        },
      ),
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({required this.data, required this.onRefresh});

  final Map<String, dynamic> data;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final greeting = (data['greeting'] ?? 'Today').toString();
    final dateSummary = (data['date_summary'] ?? '').toString();
    final focusTitle = (data['focus_title'] ?? '').toString();
    final focusWhy = (data['focus_rationale'] ?? '').toString();
    final tasks =
        (data['tasks'] is List) ? data['tasks'] as List : const <dynamic>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LifeOsHeader(
          kicker: 'Life Feed',
          title: greeting,
          trailing: IconButton(
            icon: const Icon(LucideIcons.refresh_cw, size: 18, color: lTextLo),
            onPressed: onRefresh,
          ),
        ),
        if (dateSummary.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(dateSummary, style: const TextStyle(color: lTextLo, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        if (focusTitle.isNotEmpty)
          _FocusCard(title: focusTitle, why: focusWhy),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(LucideIcons.list_checks, size: 16, color: lLime),
            const SizedBox(width: 8),
            Text(
              'Today',
              style: const TextStyle(
                color: lTextHi,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            Text('${tasks.length}',
                style: const TextStyle(color: lTextLo, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 10),
        for (final t in tasks)
          if (t is Map)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TaskRow(task: Map<String, dynamic>.from(t)),
            ),
      ],
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.title, required this.why});

  final String title;
  final String why;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [lLime.withValues(alpha: 0.18), lPurple.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: lLime.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.target, size: 15, color: lLime),
              const SizedBox(width: 7),
              const Text(
                'TODAY’S FOCUS',
                style: TextStyle(
                  color: lLime,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              height: 1.25,
            ),
          ),
          if (why.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              why,
              style: const TextStyle(color: lTextLo, fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final Map<String, dynamic> task;

  @override
  Widget build(BuildContext context) {
    final title = (task['title'] ?? '').toString();
    final meta = (task['meta'] ?? '').toString();
    final badge = (task['badge'] ?? '').toString();
    final done = task['done'] == true;
    final hot = task['hot'] == true;
    final accent = hot ? lOrange : (done ? lGreen : lLime);

    return LifeCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(
            done ? LucideIcons.circle_check_big : LucideIcons.circle,
            size: 20,
            color: done ? lGreen : lTextLo,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: done ? lTextLo : lTextHi,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(meta, style: const TextStyle(color: lTextLo, fontSize: 12)),
                ],
              ],
            ),
          ),
          if (badge.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 120),
        child: Center(child: CircularProgressIndicator(color: lLime)),
      );
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            const Icon(LucideIcons.rss, size: 40, color: lPurple),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: lTextLo, height: 1.4),
            ),
          ],
        ),
      );
}
