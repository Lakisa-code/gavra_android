import 'package:flutter/material.dart';

import '../theme.dart';

// 🎨 REGISTRY ZA SVE TEME - Lako dodavanje novih tema!
class ThemeRegistry {
  // 📝 Lista dostupnih tema
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
      colorScheme: darkSteelGreyColorScheme, // SIVE BOJE BEZ PLAVIH!
      themeData: tripleBlueFashionTheme, // ISTA TEMA!
      styles: DarkSteelGreyStyles, // CRNI STILOVI BEZ SHADOW-A!
      gradient: darkSteelGreyGradient, // SAMO GRADIJENT DRUGAČIJI!
    ),
    'passionate_rose': ThemeDefinition(
      id: 'passionate_rose',
      name: '❤️ Passionate Rose',
      description: 'Electric Red + Ruby + Crimson + Pink Ice kombinacija',
      colorScheme: passionateRoseColorScheme, // NOVA BOJA SHEMA!
      themeData: tripleBlueFashionTheme, // ISTA TEMA!
      styles: PassionateRoseStyles, // NOVI STILOVI!
      gradient: passionateRoseGradient, // SAMO GRADIJENT DRUGAČIJI!
    ),
    'dark_pink': ThemeDefinition(
      id: 'dark_pink',
      name: '💖 Dark Pink',
      description: 'Tamna tema sa neon pink akcentima',
      colorScheme: darkPinkColorScheme, // PINK BOJE!
      themeData: tripleBlueFashionTheme, // ISTA TEMA!
      styles: DarkPinkStyles, // PINK STILOVI!
      gradient: darkPinkGradient, // TAMNO PINK GRADIJENT!
    ),
  };

  /// Vraća sve dostupne teme
  static Map<String, ThemeDefinition> get allThemes => Map.unmodifiable(_themes);

  /// Vraća listu naziva tema za dropdown
  static List<String> get themeNames => _themes.keys.toList();

  /// Vraća temu po ID-u
  static ThemeDefinition? getTheme(String themeId) => _themes[themeId];

  /// Vraća ThemeData po ID-u
  static ThemeData getThemeData(String themeId) {
    final theme = _themes[themeId];
    return theme?.themeData ?? _themes['triple_blue_fashion']!.themeData;
  }

  /// Vraća default temu
  static ThemeDefinition get defaultTheme {
    return _themes.values.firstWhere(
      (t) => t.isDefault,
      orElse: () => _themes['triple_blue_fashion']!,
    );
  }

  /// Proverava da li tema postoji
  static bool hasTheme(String themeId) => _themes.containsKey(themeId);
}

// 🎭 Definicija teme - sve što treba za kompletnu temu
class ThemeDefinition {
  // za kategorije tema

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
}
