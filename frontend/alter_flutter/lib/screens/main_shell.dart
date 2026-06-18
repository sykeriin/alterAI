import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import 'dashboard.dart';
import 'future.dart';
import 'voice.dart';
import 'stats.dart';
import 'profile.dart';
import 'settings.dart';

/// Hosts the 5 primary tabs with a persistent glass pill nav + Settings drawer.
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});
  @override
  State<MainShell> createState() => MainShellState();

  /// Allow descendant screens to switch tabs / open settings.
  static MainShellState of(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>()!;
}

class MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void goTab(int i) => setState(() => _index = i);
  void openSettings() => _scaffoldKey.currentState?.openEndDrawer();

  @override
  Widget build(BuildContext context) {
    final pages = const [
      DashboardScreen(),
      FutureScreen(),
      VoiceScreen(),
      StatsScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      endDrawer: const SettingsDrawer(),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: GlassNavBar(
        index: _index,
        onTap: goTab,
      ),
    );
  }
}

/// Persistent glass pill bottom navigation, elevated center action.
class GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const GlassNavBar({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26, left: 24, right: 24),
      child: Center(
        child: ClipRRect(
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
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 50,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _navIcon(0, _home),
                  _navIcon(1, _tree),
                  _centerIcon(),
                  _navIcon(3, _chart),
                  _navIcon(4, _user),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navIcon(int i, Widget Function(Color) builder) {
    final active = index == i;
    return GestureDetector(
      onTap: () => onTap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: active ? AppColors.white(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Center(
            child: builder(active ? AppColors.lime : AppColors.white(0.5))),
      ),
    );
  }

  Widget _centerIcon() {
    return GestureDetector(
      onTap: () => onTap(2),
      child: Container(
        width: 56,
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        transform: Matrix4.translationValues(0, -4, 0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.lime, AppColors.limeDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.lime.withValues(alpha: 0.55),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(child: StarMark(size: 26, color: AppColors.bg)),
      ),
    );
  }

  // --- nav glyphs ---
  Widget _home(Color c) => Icon(Icons.home_outlined, size: 24, color: c);
  Widget _tree(Color c) => Icon(Icons.account_tree_outlined, size: 23, color: c);
  Widget _chart(Color c) => Icon(Icons.bar_chart_rounded, size: 25, color: c);
  Widget _user(Color c) => Icon(Icons.person_outline, size: 24, color: c);
}
