import 'package:flutter/material.dart';

/// Neumorphism design tokens shared by the light and dark themes.
///
/// Both themes are versions of the *same* visual language, not independent
/// skins. Every token category (background, surface, highlight, shadow,
/// semantic status) is therefore represented in both [light] and [dark].
@immutable
class NeoThemeTokens extends ThemeExtension<NeoThemeTokens> {
  final bool isDark;
  final Color baseBackground;
  final Color raisedSurface;
  final Color recessedSurface;
  final Color highlightColor;
  final Color shadowColor;
  final Color primaryAccent;
  final Color successTint;
  final Color warningTint;
  final Color errorTint;

  const NeoThemeTokens({
    required this.isDark,
    required this.baseBackground,
    required this.raisedSurface,
    required this.recessedSurface,
    required this.highlightColor,
    required this.shadowColor,
    required this.primaryAccent,
    required this.successTint,
    required this.warningTint,
    required this.errorTint,
  });

  /// Light theme: foggy grey-blue soft surface system.
  static const NeoThemeTokens light = NeoThemeTokens(
    isDark: false,
    baseBackground: Color(0xFFE9EEF5),
    raisedSurface: Color(0xFFF1F4F8),
    recessedSurface: Color(0xFFE3E8F0),
    highlightColor: Color(0xFFFFFFFF),
    shadowColor: Color(0xFFA8B5C7),
    primaryAccent: Color(0xFF2A7FFF),
    successTint: Color(0xFFDBF5EE),
    warningTint: Color(0xFFFFF1D6),
    errorTint: Color(0xFFFDE3E5),
  );

  /// Dark theme: graphite / blue-black soft surface system (not a simple
  /// inversion of the light theme — designed independently per spec).
  static const NeoThemeTokens dark = NeoThemeTokens(
    isDark: true,
    baseBackground: Color(0xFF111827),
    raisedSurface: Color(0xFF1A2332),
    recessedSurface: Color(0xFF0D1522),
    highlightColor: Color(0xFF3A4760),
    shadowColor: Color(0xFF05080F),
    primaryAccent: Color(0xFF5B9CFF),
    successTint: Color(0xFF1F3D37),
    warningTint: Color(0xFF3D3015),
    errorTint: Color(0xFF3D1C20),
  );

  @override
  NeoThemeTokens copyWith({
    bool? isDark,
    Color? baseBackground,
    Color? raisedSurface,
    Color? recessedSurface,
    Color? highlightColor,
    Color? shadowColor,
    Color? primaryAccent,
    Color? successTint,
    Color? warningTint,
    Color? errorTint,
  }) {
    return NeoThemeTokens(
      isDark: isDark ?? this.isDark,
      baseBackground: baseBackground ?? this.baseBackground,
      raisedSurface: raisedSurface ?? this.raisedSurface,
      recessedSurface: recessedSurface ?? this.recessedSurface,
      highlightColor: highlightColor ?? this.highlightColor,
      shadowColor: shadowColor ?? this.shadowColor,
      primaryAccent: primaryAccent ?? this.primaryAccent,
      successTint: successTint ?? this.successTint,
      warningTint: warningTint ?? this.warningTint,
      errorTint: errorTint ?? this.errorTint,
    );
  }

  @override
  NeoThemeTokens lerp(ThemeExtension<NeoThemeTokens>? other, double t) {
    if (other is! NeoThemeTokens) return this;
    return NeoThemeTokens(
      isDark: t < 0.5 ? isDark : other.isDark,
      baseBackground: Color.lerp(baseBackground, other.baseBackground, t)!,
      raisedSurface: Color.lerp(raisedSurface, other.raisedSurface, t)!,
      recessedSurface: Color.lerp(recessedSurface, other.recessedSurface, t)!,
      highlightColor: Color.lerp(highlightColor, other.highlightColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      primaryAccent: Color.lerp(primaryAccent, other.primaryAccent, t)!,
      successTint: Color.lerp(successTint, other.successTint, t)!,
      warningTint: Color.lerp(warningTint, other.warningTint, t)!,
      errorTint: Color.lerp(errorTint, other.errorTint, t)!,
    );
  }
}
