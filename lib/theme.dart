import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/theme_manager.dart';

// 🎨 SAMO TRIPLE BLUE FASHION TEMA!

// ⚡🔷💠 TRIPLE BLUE FASHION - Electric + Ice + Neon kombinacija!
const ColorScheme tripleBlueFashionColorScheme = ColorScheme(
  brightness: Brightness.light,
  // Electric Blue Shine kao glavni
  primary: Color(0xFF021B79), // Electric Blue Shine - taman
  onPrimary: Colors.white,
  primaryContainer: Color(0xFF0575E6), // Electric Blue Shine - svetao
  onPrimaryContainer: Colors.white,

  // Blue Ice Metallic kao secondary
  secondary: Color(0xFF1E3A78), // Blue Ice Metallic - početak
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFF4F7CAC), // Blue Ice Metallic - sredina
  onSecondaryContainer: Colors.white,

  // Neon Blue Glow kao tertiary
  tertiary: Color(0xFF1FA2FF), // Neon Blue Glow - početak
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFF12D8FA), // Neon Blue Glow - sredina
  onTertiaryContainer: Colors.white,

  // Surface colors - svetla pozadina
  surface: Color(0xFFF0F9FF), // Svetla pozadina
  onSurface: Color(0xFF1A1A1A),
  surfaceContainerHighest: Color(0xFFE0F2FE),
  onSurfaceVariant: Color(0xFF4B5563),

  outline: Color(0xFF6B7280),
  outlineVariant: Color(0xFFD1D5DB),

  // Error colors
  error: Color(0xFFEF4444),
  onError: Colors.white,
  errorContainer: Color(0xFFFEF2F2),
  onErrorContainer: Color(0xFF991B1B),
);

// 🖤 DARK STEEL GREY - Sive boje umesto plavih!
const ColorScheme darkSteelGreyColorScheme = ColorScheme(
  brightness: Brightness.dark,
  // Steel Grey kao glavni - sive boje
  primary: Color(0xFF404040), // Srednja siva
  onPrimary: Colors.white,
  primaryContainer: Color(0xFF6A6A6A), // Svetlija siva
  onPrimaryContainer: Colors.white,

  // Dark Steel Grey kao secondary
  secondary: Color(0xFF2C2C2C), // Tamno siva
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFF8A8A8A), // Najsvetlija siva
  onSecondaryContainer: Colors.white,

  // Metallic Grey kao tertiary
  tertiary: Color(0xFF606060), // Srednje-svetla siva
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFF9A9A9A), // Svetla siva
  onTertiaryContainer: Colors.white,

  // Surface colors - tamne pozadine
  surface: Color(0xFF1A1A1A), // Tamna pozadina
  onSurface: Colors.white,
  surfaceContainerHighest: Color(0xFF2A2A2A),
  onSurfaceVariant: Color(0xFFB4B4B4),

  outline: Color(0xFF6A6A6A),
  outlineVariant: Color(0xFF404040),

  // Error colors - iste kao plava tema
  error: Color(0xFFEF4444),
  onError: Colors.white,
  errorContainer: Color(0xFFFEF2F2),
  onErrorContainer: Color(0xFF991B1B),
);

// 🎨 CUSTOM COLOR EXTENSIONS za dodatne boje
extension CustomColors on ColorScheme {
  // 👥 Učenik (student) Colors
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

// ⚡ Triple Blue Fashion Gradient - 5 boja!
const LinearGradient tripleBlueFashionGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF0575E6), // Electric Blue Shine - završetak
    Color(0xFF1E3A78), // Blue Ice Metallic - početak
    Color(0xFF4F7CAC), // Blue Ice Metallic - sredina
    Color(0xFFA8D8E8), // Blue Ice Metallic - završetak
    Color(0xFF12D8FA), // Neon Blue Glow - sredina
  ],
  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
);

// 🖤 Dark Steel Grey Gradient - SAMO GRADIJENT!
const LinearGradient darkSteelGreyGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF4A4A4A), // Srednja siva - početak svetliji
    Color(0xFF1A1A1A), // Tamna siva
    Color(0xFF3A3A3A), // Srednja siva
    Color(0xFF6A6A6A), // Svetlija siva
    Color(0xFF9A9A9A), // Najsvetlija siva - neon efekat
  ],
  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
);

// ❤️ PASSIONATE ROSE GRADIENT - Electric Red + Ruby + Crimson + Pink Ice + Neon Rose!
const LinearGradient passionateRoseGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFDC143C), // Crimson - početak svetliji
    Color(0xFF8B0000), // Dark Red
    Color(0xFFB22222), // Ruby Metallic
    Color(0xFFFF69B4), // Pink Ice Glow
    Color(0xFFFFC0CB), // Neon Rose Shine
  ],
  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
);

// 💖 DARK PINK GRADIENT - Tamna sa neon pink akcentima!
const LinearGradient darkPinkGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF8B2F6B), // Rich pink - početak svetliji
    Color(0xFF1A0A14), // Skoro crna sa pink undertone
    Color(0xFF4A1942), // Deep magenta
    Color(0xFF9B4F8B), // Lighter pink
    Color(0xFFE91E8C), // Neon pink akcent
  ],
  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
);

// 💖 DARK PINK COLOR SCHEME
const ColorScheme darkPinkColorScheme = ColorScheme(
  brightness: Brightness.dark,

  // Neon Pink kao glavni
  primary: Color(0xFFE91E8C), // Neon pink
  onPrimary: Colors.white,
  primaryContainer: Color(0xFF8B2F6B), // Deep pink
  onPrimaryContainer: Colors.white,

  // Magenta kao secondary
  secondary: Color(0xFF4A1942), // Deep magenta
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFFF69B4), // Hot pink
  onSecondaryContainer: Color(0xFF1A0A14),

  // Light pink kao tertiary
  tertiary: Color(0xFFFFC0CB), // Light pink
  onTertiary: Color(0xFF1A0A14),
  tertiaryContainer: Color(0xFFFFB6C1), // Baby pink
  onTertiaryContainer: Color(0xFF1A0A14),

  // Tamne površine
  surface: Color(0xFF1A0A14), // Skoro crna
  onSurface: Colors.white,
  surfaceContainerHighest: Color(0xFF2D1F2D),
  onSurfaceVariant: Color(0xFFE8B4D0), // Svetlo pink tekst

  outline: Color(0xFF8B2F6B),
  outlineVariant: Color(0xFF4A1942),

  error: Color(0xFFFF4444),
  onError: Colors.white,
  errorContainer: Color(0xFF3D0A0A),
  onErrorContainer: Color(0xFFFF8888),
);

// 🎨 TEMA EKSTENZIJA - dodaje gradijent pozadinu
extension ThemeGradients on ThemeData {
  LinearGradient get backgroundGradient => ThemeManager().currentGradient;

  // Glassmorphism kontejner boje
  Color get glassContainer => Colors.transparent;
  Color get glassBorder => Colors.white.withValues(alpha: 0.13);
  BoxShadow get glassShadow => BoxShadow(
        color: Colors.black.withValues(alpha: 0.22),
        blurRadius: 24,
        offset: const Offset(0, 8),
      );
}

// ⚡ Triple Blue Fashion Theme
final ThemeData tripleBlueFashionTheme = ThemeData(
  colorScheme: tripleBlueFashionColorScheme,
  useMaterial3: true,
  textTheme: GoogleFonts.montserratTextTheme(), // 🇷🇸 Montserrat font sa srpskim slovima
  scaffoldBackgroundColor: const Color(0xFFF0F9FF),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Color(0xFF021B79), // Originalna tamna Electric Blue boja
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

// ⚡ Triple Blue Fashion Styles - OSVETLJENI!
class TripleBlueFashionStyles {
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      width: 2,
      color: const Color(0xFF1FA2FF).withValues(alpha: 0.4),
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF021B79).withValues(alpha: 0.3),
        blurRadius: 32,
        offset: const Offset(0, 12),
        spreadRadius: 4,
      ),
      BoxShadow(
        color: const Color(0xFF4F7CAC).withValues(alpha: 0.2),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: const Color(0xFFE91E63).withValues(alpha: 0.4),
        blurRadius: 36,
        offset: const Offset(0, 16),
        spreadRadius: 6,
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
      color: const Color(0xFF1FA2FF).withValues(alpha: 0.6),
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF021B79).withValues(alpha: 0.4),
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
      color: const Color(0xFF1FA2FF).withValues(alpha: 0.4), // Plavi border
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF021B79).withValues(alpha: 0.2), // Plava senka
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );

  static BoxDecoration popupDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: const Color(0xFF1FA2FF).withValues(alpha: 0.5), // Plavi border
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF021B79).withValues(alpha: 0.3), // Plava senka
        blurRadius: 36,
        offset: const Offset(0, 16),
        spreadRadius: 8,
      ),
    ],
  );
}

// 🖤 Dark Steel Grey Styles - BEZ SHADOW-A!
class DarkSteelGreyStyles {
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      width: 2,
      color: Colors.grey.withValues(alpha: 0.4), // Siva boja umesto plave
    ),
    // BEZ SHADOW-A!
  );

  static BoxDecoration gradientBackground = const BoxDecoration(
    gradient: darkSteelGreyGradient,
  );

  static BoxDecoration gradientButton = BoxDecoration(
    gradient: darkSteelGreyGradient,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      width: 1.5,
      color: Colors.grey.withValues(alpha: 0.6), // Siva boja umesto plave
    ),
    // BEZ SHADOW-A!
  );

  static BoxDecoration dropdownDecoration = BoxDecoration(
    color: Colors.grey[800], // Tamno siva pozadina
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Colors.grey.withValues(alpha: 0.4), // Siva boja umesto plave
      width: 1.5,
    ),
    // BEZ SHADOW-A!
  );

  static BoxDecoration popupDecoration = BoxDecoration(
    color: Colors.grey[900], // Tamno siva pozadina
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: Colors.grey.withValues(alpha: 0.5), // Siva boja umesto plave
      width: 2,
    ),
    // BEZ SHADOW-A!
  );
}

// 💖 Dark Pink Styles - Tamna sa neon pink akcentima!
class DarkPinkStyles {
  static BoxDecoration cardDecoration = BoxDecoration(
    color: const Color(0xFF2D1F2D), // Tamno ljubičasta pozadina
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      width: 2,
      color: const Color(0xFFE91E8C).withValues(alpha: 0.5), // Neon pink border
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFE91E8C).withValues(alpha: 0.3), // Pink glow
        blurRadius: 24,
        offset: const Offset(0, 8),
        spreadRadius: 2,
      ),
    ],
  );

  static BoxDecoration gradientBackground = const BoxDecoration(
    gradient: darkPinkGradient,
  );

  static BoxDecoration gradientButton = BoxDecoration(
    gradient: darkPinkGradient,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      width: 1.5,
      color: const Color(0xFFE91E8C).withValues(alpha: 0.6), // Neon pink border
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFE91E8C).withValues(alpha: 0.4), // Pink glow
        blurRadius: 20,
        offset: const Offset(0, 8),
        spreadRadius: 2,
      ),
    ],
  );

  static BoxDecoration dropdownDecoration = BoxDecoration(
    color: const Color(0xFF2D1F2D), // Tamno ljubičasta pozadina
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xFFE91E8C).withValues(alpha: 0.4), // Pink border
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFE91E8C).withValues(alpha: 0.2), // Pink glow
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration popupDecoration = BoxDecoration(
    color: const Color(0xFF1A0A14), // Skoro crna pozadina
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: const Color(0xFFE91E8C).withValues(alpha: 0.5), // Pink border
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFE91E8C).withValues(alpha: 0.3), // Pink glow
        blurRadius: 32,
        offset: const Offset(0, 12),
        spreadRadius: 4,
      ),
    ],
  );
}
