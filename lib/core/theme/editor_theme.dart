import 'package:material_ui/material_ui.dart';

import '../../domain/entities/preset.dart';

/// Hardware-inspired ThemeExtension for the multi-FX editor.
///
/// Centralizes category accents, surface shades, radii, animation timings,
/// and active-glow shadows so no widget hardcodes colors.
@immutable
class FxEditorThemeExtension extends ThemeExtension<FxEditorThemeExtension> {
  const FxEditorThemeExtension({
    required this.chassisBackground,
    required this.panelSurface,
    required this.blockSurface,
    required this.elevatedSurface,
    required this.subtleBorder,
    required this.textPrimary,
    required this.textMuted,
    required this.meterLow,
    required this.meterMid,
    required this.meterPeak,
    required this.categoryColors,
    required this.blockRadius,
    required this.panelRadius,
    required this.transitionDuration,
  });

  final Color chassisBackground;
  final Color panelSurface;
  final Color blockSurface;
  final Color elevatedSurface;
  final Color subtleBorder;
  final Color textPrimary;
  final Color textMuted;
  final Color meterLow;
  final Color meterMid;
  final Color meterPeak;
  final Map<EffectCategory, Color> categoryColors;
  final double blockRadius;
  final double panelRadius;
  final Duration transitionDuration;

  Color colorFor(EffectCategory category) =>
      categoryColors[category] ?? textPrimary;

  List<BoxShadow> glowFor(Color accent, {bool active = true}) {
    if (!active) return const <BoxShadow>[];
    return <BoxShadow>[
      BoxShadow(
        color: accent.withValues(alpha: 0.42),
        blurRadius: 14,
        spreadRadius: 1,
      ),
    ];
  }

  static const FxEditorThemeExtension darkHardware = FxEditorThemeExtension(
    chassisBackground: Color(0xFF0D0F12),
    panelSurface: Color(0xFF15181E),
    blockSurface: Color(0xFF1B1F27),
    elevatedSurface: Color(0xFF232833),
    subtleBorder: Color(0xFF2D3340),
    textPrimary: Color(0xFFE8ECF2),
    textMuted: Color(0xFF8B94A6),
    meterLow: Color(0xFF22C55E),
    meterMid: Color(0xFFF59E0B),
    meterPeak: Color(0xFFEF4444),
    categoryColors: <EffectCategory, Color>{
      EffectCategory.amp: Color(0xFF22C55E), // Green
      EffectCategory.cab: Color(0xFF14B8A6), // Teal
      EffectCategory.drive: Color(0xFFF59E0B), // Amber
      EffectCategory.delay: Color(0xFF3B82F6), // Blue
      EffectCategory.reverb: Color(0xFF06B6D4), // Cyan
      EffectCategory.modulation: Color(0xFFA855F7), // Violet
      EffectCategory.eq: Color(0xFFEC4899), // Magenta
      EffectCategory.gate: Color(0xFF64748B), // Slate
      EffectCategory.compressor: Color(0xFFF97316), // Orange
      EffectCategory.volume: Color(0xFFEAB308), // Gold
    },
    blockRadius: 10,
    panelRadius: 12,
    transitionDuration: Duration(milliseconds: 180),
  );

  @override
  FxEditorThemeExtension copyWith({
    Color? chassisBackground,
    Color? panelSurface,
    Color? blockSurface,
    Color? elevatedSurface,
    Color? subtleBorder,
    Color? textPrimary,
    Color? textMuted,
    Color? meterLow,
    Color? meterMid,
    Color? meterPeak,
    Map<EffectCategory, Color>? categoryColors,
    double? blockRadius,
    double? panelRadius,
    Duration? transitionDuration,
  }) {
    return FxEditorThemeExtension(
      chassisBackground: chassisBackground ?? this.chassisBackground,
      panelSurface: panelSurface ?? this.panelSurface,
      blockSurface: blockSurface ?? this.blockSurface,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      subtleBorder: subtleBorder ?? this.subtleBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      meterLow: meterLow ?? this.meterLow,
      meterMid: meterMid ?? this.meterMid,
      meterPeak: meterPeak ?? this.meterPeak,
      categoryColors: categoryColors ?? this.categoryColors,
      blockRadius: blockRadius ?? this.blockRadius,
      panelRadius: panelRadius ?? this.panelRadius,
      transitionDuration: transitionDuration ?? this.transitionDuration,
    );
  }

  @override
  FxEditorThemeExtension lerp(
    covariant ThemeExtension<FxEditorThemeExtension>? other,
    double t,
  ) {
    if (other is! FxEditorThemeExtension) return this;
    return FxEditorThemeExtension(
      chassisBackground:
          Color.lerp(chassisBackground, other.chassisBackground, t)!,
      panelSurface: Color.lerp(panelSurface, other.panelSurface, t)!,
      blockSurface: Color.lerp(blockSurface, other.blockSurface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      subtleBorder: Color.lerp(subtleBorder, other.subtleBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      meterLow: Color.lerp(meterLow, other.meterLow, t)!,
      meterMid: Color.lerp(meterMid, other.meterMid, t)!,
      meterPeak: Color.lerp(meterPeak, other.meterPeak, t)!,
      categoryColors: categoryColors,
      blockRadius: blockRadius + (other.blockRadius - blockRadius) * t,
      panelRadius: panelRadius + (other.panelRadius - panelRadius) * t,
      transitionDuration: transitionDuration,
    );
  }
}

ThemeData buildFxEditorTheme() {
  const ext = FxEditorThemeExtension.darkHardware;
  final scheme = ColorScheme.dark(
    primary: ext.categoryColors[EffectCategory.amp]!,
    secondary: ext.categoryColors[EffectCategory.delay]!,
    surface: ext.panelSurface,
    onSurface: ext.textPrimary,
    outline: ext.subtleBorder,
    error: ext.meterPeak,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: ext.chassisBackground,
    cardColor: ext.panelSurface,
    dividerColor: ext.subtleBorder,
    textTheme: TextTheme(
      titleMedium: TextStyle(
        color: ext.textPrimary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
      titleSmall: TextStyle(
        color: ext.textPrimary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        color: ext.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
      bodySmall: TextStyle(color: ext.textMuted, fontSize: 12),
    ),
    extensions: const <ThemeExtension<dynamic>>[ext],
  );
}
