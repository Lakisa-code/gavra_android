import 'package:flutter/material.dart';

import '../theme.dart';

/// Registry svih dostupnih tema aplikacije.
class ThemeRegistry {
  ThemeRegistry._();

  static final Map<String, ThemeDefinition> _themes = {
    'triple_blue_fashion': ThemeDefinition(
      id: 'triple_blue_fashion',
      name: '⚡ Triple Blue Fashion',
      description: 'Electric + Ice + Neon kombinacija',
      colorScheme: tripleBlueFashionColorScheme,
      themeData: tripleBlueFashionTheme,
      styles: TripleBlueFashionStyles,
      gradient: tripleBlueFashionGradient,
      isDefault: true,
    ),
    'dark_steel_grey': ThemeDefinition(
      id: 'dark_steel_grey',
      name: '🖤 Dark Steel Grey',
      description: 'Triple Blue Fashion sa crno-sivim gradijentom',
      colorScheme: darkSteelGreyColorScheme,
      themeData: tripleBlueFashionTheme,
      styles: DarkSteelGreyStyles,
      gradient: darkSteelGreyGradient,
    ),
    'passionate_rose': ThemeDefinition(
      id: 'passionate_rose',
      name: '❤️ Passionate Rose',
      description: 'Electric Red + Ruby + Crimson + Pink Ice kombinacija',
      colorScheme: passionateRoseColorScheme,
      themeData: tripleBlueFashionTheme,
      styles: PassionateRoseStyles,
      gradient: passionateRoseGradient,
    ),
    'dark_pink': ThemeDefinition(
      id: 'dark_pink',
      name: '💖 Dark Pink',
      description: 'Tamna tema sa neon pink akcentima',
      colorScheme: darkPinkColorScheme,
      themeData: tripleBlueFashionTheme,
      styles: DarkPinkStyles,
      gradient: darkPinkGradient,
    ),
  };

  // Keširane vrijednosti — izracunavaju se jednom
  static final ThemeDefinition _defaultTheme = _themes.values.firstWhere(
    (t) => t.isDefault,
    orElse: () => _themes.values.first,
  );
  static final List<String> _themeNames = List.unmodifiable(_themes.keys);

  /// Vraća sve dostupne teme
  static Map<String, ThemeDefinition> get allThemes => Map.unmodifiable(_themes);

  /// Vraća listu ID-eva tema (keširana, nealocira novu listu pri svakom pozivu)
  static List<String> get themeNames => _themeNames;

  /// Vraća temu po ID-u
  static ThemeDefinition? getTheme(String themeId) => _themes[themeId];

  /// Vraća ThemeData po ID-u
  static ThemeData getThemeData(String themeId) {
    return _themes[themeId]?.themeData ?? _defaultTheme.themeData;
  }

  /// Vraća default temu (keširana)
  static ThemeDefinition get defaultTheme => _defaultTheme;

  /// Proverava da li tema postoji
  static bool hasTheme(String themeId) => _themes.containsKey(themeId);
}

/// Definicija teme — sve sto treba za kompletnu temu.
class ThemeDefinition {
  const ThemeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.colorScheme,
    required this.themeData,
    required this.styles,
    required this.gradient,
    this.isDefault = false,
    this.tags,
  });
  final String id;
  final String name;
  final String description;
  final ColorScheme colorScheme;
  final ThemeData themeData;
  final Type styles; // TripleBlueFashionStyles, itd.
  final LinearGradient gradient;
  final bool isDefault;
  final List<String>? tags;

  /// Kreira kopiju sa izmenjenim vrednostima
  ThemeDefinition copyWith({
    String? id,
    String? name,
    String? description,
    ColorScheme? colorScheme,
    ThemeData? themeData,
    Type? styles,
    LinearGradient? gradient,
    bool? isDefault,
    List<String>? tags,
  }) {
    return ThemeDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorScheme: colorScheme ?? this.colorScheme,
      themeData: themeData ?? this.themeData,
      styles: styles ?? this.styles,
      gradient: gradient ?? this.gradient,
      isDefault: isDefault ?? this.isDefault,
      tags: tags ?? this.tags,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ThemeDefinition && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
