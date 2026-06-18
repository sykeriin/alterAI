import 'package:flutter/widgets.dart';

class Breakpoints {
  const Breakpoints._();

  static const compact = 640.0;
  static const medium = 920.0;
  static const expanded = 1200.0;
}

extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);

  bool get isCompact => screenSize.width < Breakpoints.compact;

  bool get isMedium =>
      screenSize.width >= Breakpoints.compact &&
      screenSize.width < Breakpoints.medium;

  bool get isExpanded => screenSize.width >= Breakpoints.medium;

  double get pageGutter {
    if (screenSize.width >= Breakpoints.expanded) {
      return 40;
    }
    if (isExpanded) {
      return 28;
    }
    return 18;
  }

  double get maxContentWidth => isExpanded ? 1180 : double.infinity;
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    required this.children,
    this.compactColumns = 1,
    this.mediumColumns = 2,
    this.expandedColumns = 3,
    this.spacing = 14,
    super.key,
  });

  final List<Widget> children;
  final int compactColumns;
  final int mediumColumns;
  final int expandedColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final columns = context.isCompact
        ? compactColumns
        : context.isMedium
        ? mediumColumns
        : expandedColumns;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) /
            columns.clamp(1, 6);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(
                width: width.isFinite ? width : constraints.maxWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}
