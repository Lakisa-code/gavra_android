import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🎨 APLIKACIJA SA 3 TEME: TRIPLE BLUE FASHION, DARK THEME, PINK SVETLANA

// ⚡🔷💠 1. TRIPLE BLUE FASHION - Electric + Ice + Neon kombinacija!
const ColorScheme tripleBlueFashionColorScheme = ColorScheme(
  brightness: Brightness.light,
  // Electric Blue Shine kao glavni - OSVETLJEN!
  primary: Color(0xFF1976D2), // Svetliji Electric Blue - Material Blue 700
  onPrimary: Colors.white,
  primaryContainer: Color(0xFF1E88E5), // Electric Blue Shine - svetliji
  onPrimaryContainer: Colors.white,

  // Blue Ice Metallic kao secondary - OSVETLJEN!
  secondary: Color(0xFF42A5F5), // Blue Ice Metallic - svetliji
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFF64B5F6), // Blue Ice Metallic - još svetliji
  onSecondaryContainer: Colors.white,

  // Neon Blue Glow kao tertiary - TREĆA BOJA!
  tertiary: Color(0xFF03DAC6), // Bright Teal/Cyan - treća boja za gradijent
  onTertiary: Color(0xFF000000), // Crn tekst na svetlom cyan-u
  tertiaryContainer: Color(0xFF4DD0E1), // Svetliji cyan
  onTertiaryContainer: Color(0xFF000000),

  // Surface colors - svetla pozadina
  surface: Color(0xFFF0F9FF), // Svetla pozadina
  onSurface: Color(0xFF1A1A1A),
  surfaceVariant: Color(0xFFE0F2FE),
  onSurfaceVariant: Color(0xFF4B5563),
  surfaceContainerHighest: Color(0xFFDCFDF7),

  outline: Color(0xFF6B7280),
  outlineVariant: Color(0xFFD1D5DB),

  // Error colors
  error: Color(0xFFEF4444),
  onError: Colors.white,
  errorContainer: Color(0xFFFEF2F2),
  onErrorContainer: Color(0xFF991B1B),
);

// 🌙💜 2. DARK THEME - Normalna tamna tema
const ColorScheme darkThemeColorScheme = ColorScheme(
  brightness: Brightness.dark,
  // Tamni primary colors - NORMALNA DARK TEMA
  primary: Color(0xFF1F2937), // Tamno siva za AppBar
  onPrimary: Color(0xFFF9FAFB), // Svetli tekst na tamnoj pozadini
  primaryContainer: Color(0xFF374151), // Tamniji container
  onPrimaryContainer: Color(0xFFE5E7EB),

  // Purple accent za eleganciju
  secondary: Color(0xFFBB86FC), // Electric purple
  onSecondary: Color(0xFF000000),
  secondaryContainer: Color(0xFF6B46C1),
  onSecondaryContainer: Color(0xFFE5E7EB),

  // Cyan accent kao tertiary - treća boja!
  tertiary: Color(0xFF22D3EE), // Bright cyan za dark temu
  onTertiary: Color(0xFF000000),
  tertiaryContainer: Color(0xFF0891B2), // Tamniji cyan
  onTertiaryContainer: Color(0xFFE0F7FA),

  // Tamne surface boje
  surface: Color(0xFF111827), // Tamna pozadina
  onSurface: Color(0xFFF9FAFB),
  surfaceVariant: Color(0xFF1F2937),
  onSurfaceVariant: Color(0xFFD1D5DB),
  surfaceContainerHighest: Color(0xFF374151),

  outline: Color(0xFF4B5563),
  outlineVariant: Color(0xFF374151),

  // Error colors za dark
  error: Color(0xFFEF4444),
  onError: Color(0xFF1F2937),
  errorContainer: Color(0xFF7F1D1D),
  onErrorContainer: Color(0xFFFECACA),
);

// 💖👸 3. PINK SVETLANA - Specijalna pink tema za Svetlanu!
const ColorScheme pinkSvetlanaColorScheme = ColorScheme(
  brightness: Brightness.light,
  // Pink kao glavni
  primary: Color(0xFFE91E63), // Hot pink
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFF06292), // Svetliji pink
  onPrimaryContainer: Colors.white,

  // Pink accent
  secondary: Color(0xFFFF4081), // Pink accent
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFFCE4EC), // Svetao pink
  onSecondaryContainer: Color(0xFFAD1457),

  // Rose gold kao tertiary - treća boja!
  tertiary: Color(0xFFFFB74D), // Warm gold za pink temu
  onTertiary: Color(0xFF000000),
  tertiaryContainer: Color(0xFFFFF3E0), // Svetao gold
  onTertiaryContainer: Color(0xFFE65100),

  // Pink surface boje
  surface: Color(0xFFFDF2F8), // Pink pozadina
  onSurface: Color(0xFF1A1A1A),
  surfaceVariant: Color(0xFFFCE4EC),
  onSurfaceVariant: Color(0xFF4B5563),
  surfaceContainerHighest: Color(0xFFFEF7F0),

  outline: Color(0xFFEC4899),
  outlineVariant: Color(0xFFF8BBD9),

  // Error colors
  error: Color(0xFFE57373),
  onError: Colors.white,
  errorContainer: Color(0xFFFFEBEE),
  onErrorContainer: Color(0xFFC62828),
);

// 🎨 CUSTOM COLOR EXTENSIONS za dodatne boje
extension CustomColors on ColorScheme {
  // 👥 Student Colors
  Color get studentPrimary => const Color(0xFF2196F3); // Blue
  Color get studentSecondary => const Color(0xFF42A5F5);
  Color get studentContainer => const Color(0xFFE3F2FD);
  Color get onStudentContainer => const Color(0xFF0D47A1);

  // 💼 Worker Colors
  Color get workerPrimary => const Color(0xFF009688); // Teal
  Color get workerSecondary => const Color(0xFF26A69A);
  Color get workerContainer => const Color(0xFFE0F2F1);
  Color get onWorkerContainer => const Color(0xFF004D40);

  // ✅ Success Colors
  Color get successPrimary => const Color(0xFF4CAF50);
  Color get successContainer => const Color(0xFFE8F5E8);
  Color get onSuccessContainer => const Color(0xFF2E7D32);

  // ⚠️ Warning Colors
  Color get warningPrimary => const Color(0xFFFF9800);
  Color get warningContainer => const Color(0xFFFFF3E0);
  Color get onWarningContainer => const Color(0xFFE65100);

  // 🔴 Danger Colors
  Color get dangerPrimary => const Color(0xFFEF5350);
  Color get dangerContainer => const Color(0xFFFFEBEE);
  Color get onDangerContainer => const Color(0xFFC62828);
}

// 🎨 GRADIJENTI ZA 3 TEME

// ⚡ Triple Blue Fashion Gradient - 3 GLAVNE BOJE!
const LinearGradient tripleBlueFashionGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF1976D2), // Electric Blue - prva boja
    Color(0xFF42A5F5), // Ice Blue - druga boja
    Color(0xFF03DAC6), // Neon Cyan - treća boja
  ],
  stops: [0.0, 0.5, 1.0], // Ravnomerno raspoređene 3 boje
);

// 🌙 Dark Theme Gradient - 3 TAMNE BOJE!
const LinearGradient darkThemeGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF1F2937), // Tamno siva - primary
    Color(0xFFBB86FC), // Electric purple - secondary
    Color(0xFF22D3EE), // Bright cyan - tertiary
  ],
  stops: [0.0, 0.5, 1.0],
);

// 💖 Pink Svetlana Gradient - 3 BOJE!
const LinearGradient pinkSvetlanaGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFE91E63), // Hot pink
    Color(0xFFFF4081), // Pink accent
    Color(0xFFFFB74D), // Warm gold
  ],
  stops: [0.0, 0.5, 1.0],
);

// 🎭 THEME DATA ZA 3 TEME

// ⚡ 1. Triple Blue Fashion Theme - OSVETLJENA!
final ThemeData tripleBlueFashionTheme = ThemeData(
  colorScheme: tripleBlueFashionColorScheme,
  useMaterial3: true,
  fontFamily: 'Inter',
  scaffoldBackgroundColor: const Color(0xFFF0F9FF), // Svetla pozadina
  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Color(0xFF1976D2), // Svetliji Electric Blue umesto tamnog
    foregroundColor: Colors.white,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      letterSpacing: 0.5,
    ),
  ),
);

// 🌙 2. Dark Theme
final ThemeData darkTheme = ThemeData(
  colorScheme: darkThemeColorScheme,
  useMaterial3: true,
  fontFamily: 'Inter',
  scaffoldBackgroundColor: const Color(0xFF111827),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Color(0xFF1F2937),
    foregroundColor: Color(0xFFF9FAFB),
    systemOverlayStyle: SystemUiOverlayStyle.light,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Color(0xFFF9FAFB),
      letterSpacing: 0.5,
    ),
  ),
);

// 💖 3. Pink Svetlana Theme
final ThemeData pinkSvetlanaTheme = ThemeData(
  colorScheme: pinkSvetlanaColorScheme,
  useMaterial3: true,
  fontFamily: 'Inter',
  scaffoldBackgroundColor: const Color(0xFFFDF2F8),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Color(0xFFE91E63),
    foregroundColor: Colors.white,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      letterSpacing: 0.5,
    ),
  ),
);

// 🎨 UTILITY STILOVI ZA 3 TEME

// ⚡ Triple Blue Fashion Styles - OSVETLJENI!
class TripleBlueFashionStyles {
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      width: 2,
      color: const Color(0xFF42A5F5).withOpacity(0.4), // Svetliji border
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1976D2).withOpacity(0.2), // Svetlija senka
        blurRadius: 32,
        offset: const Offset(0, 12),
        spreadRadius: 4,
      ),
      BoxShadow(
        color: const Color(0xFF42A5F5).withOpacity(0.1), // Svetlija senka
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ],
  );

  static BoxDecoration gradientBackground = const BoxDecoration(
    gradient: tripleBlueFashionGradient,
  );

  static BoxDecoration gradientButton = BoxDecoration(
    gradient: tripleBlueFashionGradient,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      width: 1.5,
      color: const Color(0xFF42A5F5).withOpacity(0.6), // Svetliji border
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1976D2).withOpacity(0.4), // Svetlija senka
        blurRadius: 24,
        offset: const Offset(0, 12),
        spreadRadius: 2,
      ),
    ],
  );

  static BoxDecoration dropdownDecoration = BoxDecoration(
    color: const Color(0xFFF0F9FF), // Svetla pozadina
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xFF42A5F5).withOpacity(0.4), // Svetliji border
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1976D2).withOpacity(0.2), // Svetlija senka
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );

  static BoxDecoration popupDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: const Color(0xFF42A5F5).withOpacity(0.5), // Svetliji border
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1976D2).withOpacity(0.3), // Svetlija senka
        blurRadius: 36,
        offset: const Offset(0, 16),
        spreadRadius: 6,
      ),
    ],
  );
}

// 🌙 Dark Theme Styles
class DarkThemeStyles {
  static BoxDecoration cardDecoration = BoxDecoration(
    color: const Color(0xFF1F2937),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      width: 2,
      color: const Color(0xFFBB86FC).withOpacity(0.4),
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFBB86FC).withOpacity(0.3),
        blurRadius: 32,
        offset: const Offset(0, 12),
        spreadRadius: 4,
      ),
    ],
  );

  static BoxDecoration gradientBackground = const BoxDecoration(
    gradient: darkThemeGradient,
  );

  static BoxDecoration gradientButton = BoxDecoration(
    gradient: darkThemeGradient,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      width: 1.5,
      color: const Color(0xFFBB86FC).withOpacity(0.6),
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFBB86FC).withOpacity(0.6),
        blurRadius: 24,
        offset: const Offset(0, 12),
        spreadRadius: 2,
      ),
    ],
  );

  static BoxDecoration dropdownDecoration = BoxDecoration(
    color: const Color(0xFF1F2937), // Tamna pozadina
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xFFBB86FC).withOpacity(0.4),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFBB86FC).withOpacity(0.3),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );

  static BoxDecoration popupDecoration = BoxDecoration(
    color: const Color(0xFF1F2937),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: const Color(0xFFBB86FC).withOpacity(0.5),
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFBB86FC).withOpacity(0.4),
        blurRadius: 36,
        offset: const Offset(0, 16),
        spreadRadius: 6,
      ),
    ],
  );
}

// 💖 Pink Svetlana Styles
class PinkSvetlanaStyles {
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      width: 2,
      color: const Color(0xFFFF4081).withOpacity(0.4),
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFE91E63).withOpacity(0.3),
        blurRadius: 32,
        offset: const Offset(0, 12),
        spreadRadius: 4,
      ),
    ],
  );

  static BoxDecoration gradientBackground = const BoxDecoration(
    gradient: pinkSvetlanaGradient,
  );

  static BoxDecoration gradientButton = BoxDecoration(
    gradient: pinkSvetlanaGradient,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      width: 1.5,
      color: const Color(0xFFFF4081).withOpacity(0.6),
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFE91E63).withOpacity(0.6),
        blurRadius: 24,
        offset: const Offset(0, 12),
        spreadRadius: 2,
      ),
    ],
  );

  static BoxDecoration dropdownDecoration = BoxDecoration(
    color: const Color(0xFFFDF2F8), // Pink pozadina
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xFFFF4081).withOpacity(0.4),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFE91E63).withOpacity(0.3),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );

  static BoxDecoration popupDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: const Color(0xFFFF4081).withOpacity(0.5),
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFE91E63).withOpacity(0.4),
        blurRadius: 36,
        offset: const Offset(0, 16),
        spreadRadius: 6,
      ),
    ],
  );
}

// 🎭 THEME SELECTOR - Fleksibilni sistem tema za sve vozače
class ThemeSelector {
  // 🎨 DOSTUPNE TEME - sve teme su dostupne svim vozačima
  static const Map<String, String> availableThemes = {
    'triple_blue': '⚡ Triple Blue Fashion',
    'dark': '🌙 Dark Theme',
    'pink': '💖 Pink Svetlana',
  };

  // 🎨 DEFAULT PREFERENCE - koje teme vozači preferiraju (ali mogu menjati)
  static const Map<String, String> driverDefaultThemes = {
    'Svetlana': 'pink', // Svetlana voli pink, ali može menjati
    'Bojan': 'triple_blue', // Bojan voli blue, ali može menjati
    'Bruda': 'dark', // Bruda voli dark, ali može menjati
    'Bilevski': 'triple_blue', // Bilevski voli blue, ali može menjati
  };

  /// Vraća temu na osnovu ID-ja teme
  static ThemeData getThemeById(String themeId) {
    switch (themeId) {
      case 'triple_blue':
        return tripleBlueFashionTheme;
      case 'dark':
        return darkTheme;
      case 'pink':
        return pinkSvetlanaTheme;
      default:
        return tripleBlueFashionTheme; // Default fallback
    }
  }

  /// Vraća default temu za vozača (ali vozač može menjati)
  static ThemeData getThemeForDriver(String? driverName) {
    if (driverName == null) return tripleBlueFashionTheme;

    final defaultThemeId = driverDefaultThemes[driverName] ?? 'triple_blue';
    return getThemeById(defaultThemeId);
  }

  /// Vraća stilove na osnovu ID-ja teme
  static Type getStylesForThemeId(String themeId) {
    switch (themeId) {
      case 'pink':
        return PinkSvetlanaStyles;
      case 'dark':
        return DarkThemeStyles;
      case 'triple_blue':
      default:
        return TripleBlueFashionStyles;
    }
  }

  /// Vraća stilove na osnovu vozača (default preference)
  static Type getStylesForTheme(String? driverName) {
    if (driverName == null) return TripleBlueFashionStyles;

    final defaultThemeId = driverDefaultThemes[driverName] ?? 'triple_blue';
    return getStylesForThemeId(defaultThemeId);
  }

  /// Helper za vozače - vraća default theme ID
  static String getDefaultThemeIdForDriver(String? driverName) {
    if (driverName == null) return 'triple_blue';
    return driverDefaultThemes[driverName] ?? 'triple_blue';
  }

  /// LEGACY SUPPORT - stare metode za kompatibilnost (uzima driver name)
  static bool isDarkTheme(String? driverName) {
    final themeId = getDefaultThemeIdForDriver(driverName);
    return themeId == 'dark';
  }

  static bool isTripleBlueFashion(String? driverName) {
    final themeId = getDefaultThemeIdForDriver(driverName);
    return themeId == 'triple_blue';
  }

  static bool isPinkSvetlana(String? driverName) {
    final themeId = getDefaultThemeIdForDriver(driverName);
    return themeId == 'pink';
  }

  /// Provera teme na osnovu ID-ja teme (uzima theme ID)
  static bool isDarkThemeById(String themeId) => themeId == 'dark';
  static bool isTripleBlueFashionById(String themeId) => themeId == 'triple_blue';
  static bool isPinkSvetlanaById(String themeId) => themeId == 'pink';
}
