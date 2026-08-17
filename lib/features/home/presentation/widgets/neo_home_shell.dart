import 'package:flutter/material.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';

/// Configuration for a single tab in the neumorphic home shell.
@immutable
class NeoHomeTabItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String semanticsLabel;

  const NeoHomeTabItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.semanticsLabel,
  });
}

/// Per-tab floating action button configuration. [NeoHomeShell] shows a FAB
/// only when the active tab supplies a config, so each tab owns its own action.
@immutable
class NeoHomeFabConfig {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const NeoHomeFabConfig({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
}

/// Home shell with a soft-UI gradient background, an [IndexedStack] body,
/// a neumorphic bottom tab bar, and an optional shared floating action button.
///
/// Business state (tab index, downloaders, update checks) stays in
/// [HomeTabContainer]; this widget only owns the visual shell so the other
/// tabs can reuse it.
class NeoHomeShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final List<NeoHomeTabItem> tabs;
  final List<Widget> children;
  final NeoHomeFabConfig? fabConfig;

  const NeoHomeShell({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.tabs,
    required this.children,
    this.fabConfig,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.baseBackground,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.baseBackground,
              tokens.raisedSurface.withValues(
                alpha: tokens.isDark ? 0.72 : 0.92,
              ),
            ],
          ),
        ),
        child: IndexedStack(index: selectedIndex, children: children),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: fabConfig == null
          ? null
          : NeoHomeFab(
              onPressed: fabConfig!.onPressed,
              tooltip: fabConfig!.tooltip,
              icon: fabConfig!.icon,
            ),
      bottomNavigationBar: NeoHomeTabBar(
        tabs: tabs,
        selectedIndex: selectedIndex,
        onSelected: onTabSelected,
      ),
    );
  }
}

/// Neumorphic floating action button rendered as a circular raised disc.
class NeoHomeFab extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;

  const NeoHomeFab({
    super.key,
    required this.onPressed,
    required this.tooltip,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final message = tooltip;

    return Tooltip(
      message: message,
      child: Semantics(
        button: true,
        label: message,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: tokens.primaryAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: tokens.highlightColor.withValues(
                    alpha: tokens.isDark ? 0.06 : 0.9,
                  ),
                  offset: const Offset(-4, -4),
                  blurRadius: 10,
                ),
                BoxShadow(
                  color: tokens.shadowColor.withValues(
                    alpha: tokens.isDark ? 0.34 : 0.32,
                  ),
                  offset: const Offset(6, 6),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }
}

/// Raised neumorphic tab bar holding one button per [NeoHomeTabItem].
class NeoHomeTabBar extends StatelessWidget {
  final List<NeoHomeTabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const NeoHomeTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.raisedSurface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: tokens.highlightColor.withValues(
                alpha: tokens.isDark ? 0.05 : 0.95,
              ),
              offset: const Offset(-6, -6),
              blurRadius: 12,
            ),
            BoxShadow(
              color: tokens.shadowColor.withValues(
                alpha: tokens.isDark ? 0.24 : 0.30,
              ),
              offset: const Offset(8, 8),
              blurRadius: 16,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _NeoHomeTabButton(
                    item: tabs[i],
                    selected: selectedIndex == i,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeoHomeTabButton extends StatelessWidget {
  final NeoHomeTabItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NeoHomeTabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final color = selected ? tokens.primaryAccent : tokens.shadowColor;
    final icon = selected ? item.selectedIcon : item.icon;

    return Semantics(
      label: item.semanticsLabel,
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? tokens.recessedSurface : tokens.raisedSurface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: selected
                ? [
                    // Inset look: dark shadow top-left, highlight bottom-right.
                    BoxShadow(
                      color: tokens.shadowColor.withValues(
                        alpha: tokens.isDark ? 0.28 : 0.22,
                      ),
                      offset: const Offset(-4, -4),
                      blurRadius: 8,
                    ),
                    BoxShadow(
                      color: tokens.highlightColor.withValues(
                        alpha: tokens.isDark ? 0.04 : 0.85,
                      ),
                      offset: const Offset(4, 4),
                      blurRadius: 8,
                    ),
                  ]
                : const [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
