import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// @deprecated Use [AlterPageLayout] from `ui/widgets.dart` directly.
class AmbientScaffold extends StatelessWidget {
  const AmbientScaffold({
    required this.child,
    this.padding,
    this.scrollable = false,
    this.bottomPadding = 104,
    this.header,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;
  final double bottomPadding;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return AlterPageLayout(
      padding: padding,
      scrollable: scrollable,
      bottomInset: bottomPadding,
      header: header,
      child: child,
    );
  }
}
