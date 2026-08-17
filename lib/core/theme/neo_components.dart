import 'package:flutter/material.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';

/// Shared Neumorphism UI primitives.
///
/// These components are the single source of truth for the app's soft-UI
/// language. Pages must prefer these over hand-rolled `BoxDecoration`s so
/// light and dark themes stay visually consistent.
///
/// Every primitive reads its colors and shadow recipes from
/// [NeoThemeTokens], which is registered on both the light and dark themes.

/// Raised, grouped container surface. The base "plate" for sections and
/// panels.
class NeoSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;

  const NeoSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.raisedSurface,
        borderRadius: borderRadius,
        boxShadow: _raisedShadow(tokens),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Raised card for tasks, settings rows, and downloader info blocks.
/// Subtly pressed in on tap to convey depth change.
class NeoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const NeoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.raisedSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _raisedShadow(tokens),
      ),
      child: child,
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}

/// Recessed (inset) shell for inputs, search fields and path fields.
class NeoInputShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const NeoInputShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final transparentInputTheme = theme.inputDecorationTheme.copyWith(
      filled: false,
      fillColor: Colors.transparent,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.recessedSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: tokens.shadowColor.withValues(
              alpha: tokens.isDark ? 0.26 : 0.18,
            ),
            offset: const Offset(4, 4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: tokens.highlightColor.withValues(
              alpha: tokens.isDark ? 0.04 : 0.78,
            ),
            offset: const Offset(-4, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: tokens.highlightColor.withValues(
              alpha: tokens.isDark ? 0.08 : 0.65,
            ),
          ),
        ),
        child: Padding(
          padding: padding,
          child: Theme(
            data: theme.copyWith(inputDecorationTheme: transparentInputTheme),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Status badge / auxiliary meta label with explicit foreground/background.
class NeoBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const NeoBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Progress bar with a rounded track, kept scannable on both themes.
class NeoProgress extends StatelessWidget {
  final double value;
  final double minHeight;

  const NeoProgress({super.key, required this.value, this.minHeight = 10});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: minHeight,
      ),
    );
  }
}

/// Bottom fixed action area wrapping content in a SafeArea'd card.
class NeoActionBar extends StatelessWidget {
  final Widget child;

  const NeoActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: NeoCard(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

/// Primary / secondary full-width button following the brand accent.
class NeoButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget label;
  final bool isPrimary;

  const NeoButton.primary({
    super.key,
    required this.onPressed,
    required this.label,
  }) : isPrimary = true;

  const NeoButton.secondary({
    super.key,
    required this.onPressed,
    required this.label,
  }) : isPrimary = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: isPrimary
              ? colorScheme.primary
              : colorScheme.surface,
          foregroundColor: isPrimary ? Colors.white : colorScheme.onSurface,
        ),
        child: label,
      ),
    );
  }
}

/// Content group with a title, optional subtitle and a raised body.
class NeoSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const NeoSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 2, bottom: 12),
          child: Row(
            crossAxisAlignment: subtitle == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: textTheme.bodySmall?.copyWith(
                          color: textTheme.bodySmall?.color?.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
        NeoCard(child: child),
      ],
    );
  }
}

/// Circular icon action used in page headers.
class NeoHeaderAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const NeoHeaderAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, color: colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Page-level title block with optional back and trailing actions.
class NeoPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const NeoPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (onBack != null) ...[
            NeoHeaderAction(
              tooltip: 'Back',
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.68,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Tappable settings row with icon, descriptive copy and optional value text.
class NeoSettingRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Widget? trailing;
  final bool isDestructive;
  final VoidCallback? onTap;

  const NeoSettingRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.isDestructive = false,
    this.onTap,
  }) : assert(icon != null || leading != null);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final foreground = isDestructive
        ? colorScheme.error
        : colorScheme.onSurface;

    return NeoCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          leading ?? Icon(icon!, color: foreground),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: textTheme.bodySmall?.color?.withValues(
                        alpha: 0.68,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ] else if (trailingText != null) ...[
            const SizedBox(width: 12),
            Text(
              trailingText!,
              style: textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Value-label pair used by [NeoFilterStrip].
class NeoChoiceOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const NeoChoiceOption({required this.value, required this.label, this.icon});
}

/// Horizontal choice strip for compact filtering.
class NeoFilterStrip<T> extends StatefulWidget {
  final T selectedValue;
  final List<NeoChoiceOption<T>> options;
  final ValueChanged<T> onSelected;
  final bool showIcons;

  const NeoFilterStrip({
    super.key,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
    this.showIcons = false,
  });

  @override
  State<NeoFilterStrip<T>> createState() => _NeoFilterStripState<T>();
}

class _NeoFilterStripState<T> extends State<NeoFilterStrip<T>> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyForIndex(int index) {
    return _itemKeys.putIfAbsent(index, () => GlobalKey());
  }

  int? _selectedValueIndex() {
    for (var i = 0; i < widget.options.length; i++) {
      if (widget.options[i].value == widget.selectedValue) return i;
    }
    return null;
  }

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = _selectedValueIndex();
      if (index == null) return;
      final key = _keyForIndex(index);
      final context = key.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollToSelected();
  }

  @override
  void didUpdateWidget(NeoFilterStrip<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedValue != oldWidget.selectedValue) {
      _scrollToSelected();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          for (var index = 0; index < widget.options.length; index++) ...[
            NeoChoicePill(
              key: _keyForIndex(index),
              label: widget.options[index].label,
              icon: widget.showIcons ? widget.options[index].icon : null,
              selected: widget.options[index].value == widget.selectedValue,
              onTap: () => widget.onSelected(widget.options[index].value),
            ),
            if (index != widget.options.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Single selectable pill used in filter strips and segmented controls.
class NeoChoicePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const NeoChoicePill({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final textTheme = Theme.of(context).textTheme;
    final foreground = selected
        ? tokens.primaryAccent
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? tokens.primaryAccent.withValues(alpha: 0.12)
                : tokens.recessedSurface,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: tokens.shadowColor.withValues(
                  alpha: selected
                      ? (tokens.isDark ? 0.26 : 0.12)
                      : (tokens.isDark ? 0.32 : 0.16),
                ),
                offset: const Offset(3, 3),
                blurRadius: 8,
              ),
              BoxShadow(
                color: tokens.highlightColor.withValues(
                  alpha: selected
                      ? (tokens.isDark ? 0.02 : 0.54)
                      : (tokens.isDark ? 0.03 : 0.68),
                ),
                offset: const Offset(-3, -3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Labelled form shell that can display a compact suffix beside its child.
class NeoFormFieldShell extends StatelessWidget {
  final String label;
  final String? suffix;
  final bool enabled;
  final Widget child;

  const NeoFormFieldShell({
    super.key,
    required this.label,
    this.suffix,
    this.enabled = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          NeoInputShell(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(child: child),
                if (suffix != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    suffix!,
                    style: textTheme.labelLarge?.copyWith(
                      color: textTheme.labelLarge?.color?.withValues(
                        alpha: 0.68,
                      ),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Prominent status summary card for task detail and downloader overview pages.
class NeoStatusHeroCard extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String subtitle;
  final Widget? badge;
  final double? progress;
  final String? leadingMeta;
  final String? trailingMeta;
  final Color? iconColor;
  final VoidCallback? onTap;

  const NeoStatusHeroCard({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    required this.subtitle,
    this.badge,
    this.progress,
    this.leadingMeta,
    this.trailingMeta,
    this.iconColor,
    this.onTap,
  }) : assert(icon != null || leading != null);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;

    return NeoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              leading ??
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tokens.recessedSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon!,
                      color: iconColor ?? tokens.primaryAccent,
                    ),
                  ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[const SizedBox(width: 12), badge!],
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 18),
            NeoProgress(value: progress!),
          ],
          if (leadingMeta != null || trailingMeta != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (leadingMeta != null)
                  Text(
                    leadingMeta!,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const Spacer(),
                if (trailingMeta != null)
                  Text(
                    trailingMeta!,
                    style: textTheme.labelLarge?.copyWith(
                      color: tokens.primaryAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty-state panel for pages that have no data to show yet.
class NeoEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const NeoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    return NeoCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: tokens.primaryAccent),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: textTheme.bodyMedium?.color?.withValues(alpha: 0.68),
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

/// Shared raised-surface shadow recipe: light highlight top-left, soft shadow
/// bottom-right — the defining Neumorphism "extruded" look.
List<BoxShadow> _raisedShadow(NeoThemeTokens tokens) {
  return [
    BoxShadow(
      color: tokens.highlightColor.withValues(
        alpha: tokens.isDark ? 0.05 : 0.95,
      ),
      offset: const Offset(-6, -6),
      blurRadius: 12,
    ),
    BoxShadow(
      color: tokens.shadowColor.withValues(alpha: tokens.isDark ? 0.24 : 0.30),
      offset: const Offset(8, 8),
      blurRadius: 16,
    ),
  ];
}
