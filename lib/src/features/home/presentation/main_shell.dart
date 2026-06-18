import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/responsive.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets.dart';
import '../../contextos/presentation/moment_sheet.dart';

class MainShell extends StatelessWidget {
  const MainShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  static const items = [
    _NavItem('/agent', 'Talk', LucideIcons.mic),
    _NavItem('/home', 'Home', LucideIcons.house),
    _NavItem('/backend', 'Backend', LucideIcons.server),
    _NavItem('/twin', 'Twin', LucideIcons.brain),
    _NavItem('/feed', 'Feed', LucideIcons.radio),
    _NavItem('/shield', 'Shield', LucideIcons.shield_check),
    _NavItem('/daytwin', 'Day', LucideIcons.calendar_clock),
    _NavItem('/futuretwin', 'Future', LucideIcons.git_fork),
    _NavItem('/openclaw', 'OpenClaw', LucideIcons.wand_sparkles),
    _NavItem('/decision-council', 'Council', LucideIcons.users),
    _NavItem('/dna', 'DNA', LucideIcons.dna),
    _NavItem('/edge', 'Edge', LucideIcons.cpu),
    _NavItem('/privacy', 'Privacy', LucideIcons.lock),
    _NavItem('/mission', 'Control', LucideIcons.command),
    _NavItem('/officekit', 'OfficeKit', LucideIcons.briefcase),
    _NavItem('/voice', 'Voice', LucideIcons.mic),
    _NavItem('/council', 'Council', LucideIcons.messages_square),
    _NavItem('/simulator', 'Future', LucideIcons.route),
    _NavItem('/radar', 'Radar', LucideIcons.radar),
    _NavItem('/social', 'Graph', LucideIcons.network),
    _NavItem('/nfc', 'NFC', LucideIcons.nfc),
    _NavItem('/reputation', 'Rep', LucideIcons.trophy),
    _NavItem('/lens', 'Lens', LucideIcons.scan_eye),
    _NavItem('/settings', 'Settings', LucideIcons.settings),
  ];

  /// Public, type-safe view of the destinations so other surfaces (e.g. the
  /// voice screen's app menu) can navigate without depending on the private
  /// nav-item type.
  static List<({String path, String label, IconData icon})> get destinations =>
      items
          .map((e) => (path: e.path, label: e.label, icon: e.icon))
          .toList();

  @override
  Widget build(BuildContext context) {
    final expanded = context.isExpanded;
    final bubbleBottom = expanded
        ? 24.0
        : 84.0 + MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: expanded
                ? Row(
                    children: [
                      _DesktopRail(location: location),
                      Expanded(child: child),
                    ],
                  )
                : Stack(
                    children: [
                      Positioned.fill(child: child),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12 + MediaQuery.paddingOf(context).bottom,
                        child: _MobileNav(location: location),
                      ),
                    ],
                  ),
          ),
          Positioned(right: 18, bottom: bubbleBottom, child: _ContextBubble()),
        ],
      ),
    );
  }
}

class _ContextBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Drop a moment',
      child: GestureDetector(
        onTap: () => showMomentSheet(context),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.lime, AppColors.limeDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.lime.withValues(alpha: 0.55),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.scan_eye,
            color: AppColors.bg,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      padding: EdgeInsets.fromLTRB(
        14,
        18 + MediaQuery.paddingOf(context).top,
        14,
        18,
      ),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        child: Column(
          children: [
            const StarMark(size: 22),
            const SizedBox(height: 22),
            for (final item in MainShell.items)
              _RailButton(item: item, selected: location == item.path),
            const Spacer(),
            Icon(LucideIcons.shield_check, color: AppColors.lime, size: 22),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.item, required this.selected});

  final _NavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.go(item.path),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            height: 48,
            decoration: BoxDecoration(
              color: selected ? AppColors.white(0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.lime.withValues(alpha: 0.35) : Colors.transparent,
              ),
            ),
            child: Icon(
              item.icon,
              color: selected ? AppColors.lime : AppColors.white(0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final light = AlterUiTheme.light;
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.navBg.withValues(alpha: 0.66),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: AppColors.white(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: light ? 0.12 : 0.5),
                blurRadius: 50,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final item in MainShell.items)
                  _MobileNavButton(item: item, selected: location == item.path),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavButton extends StatelessWidget {
  const _MobileNavButton({required this.item, required this.selected});

  final _NavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.lime : AppColors.white(0.5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => context.go(item.path),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minWidth: 58),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.white(0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: AppText.body(10, weight: FontWeight.w800, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}
