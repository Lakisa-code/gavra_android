import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

// 🖤💎 BLACK SAPPHIRE METALLIC - DARK SEKSI TEMA!
const ColorScheme blackSapphireMetallicColorScheme = ColorScheme(
  brightness: Brightness.dark,
  // Deep Black Steel kao glavni
  primary: Color(0xFF0A0A0A), // Deep Black Steel - najcrnja
  onPrimary: Color(0xFFE8E8E8), // svetlo siva za kontrast
  primaryContainer: Color(0xFF1A1A2E), // Midnight Sapphire
  onPrimaryContainer: Color(0xFFD1D5DB),

  // Dark Sapphire kao secondary
  secondary: Color(0xFF16213E), // Dark Sapphire Core
  onSecondary: Color(0xFFE8E8E8),
  secondaryContainer: Color(0xFF3D52A0), // Electric Sapphire
  onSecondaryContainer: Color(0xFFE8E8E8),

  // Purple Metallic kao tertiary
  tertiary: Color(0xFF7209B7), // Purple Metallic Glow
  onTertiary: Color(0xFFE8E8E8),
  tertiaryContainer: Color(0xFF9333EA), // Svetliji purple
  onTertiaryContainer: Color(0xFFE8E8E8),

  // Dark surface colors
  surface: Color(0xFF0F0F0F), // Tamna pozadina
  onSurface: Color(0xFFE8E8E8),
  surfaceVariant: Color(0xFF1A1A1A),
  onSurfaceVariant: Color(0xFFB8BCC8),
  surfaceContainerHighest: Color(0xFF2A2A2A),

  outline: Color(0xFF6B7280),
  outlineVariant: Color(0xFF374151),

  // Error colors za dark
  error: Color(0xFFEF4444),
  onError: Color(0xFFE8E8E8),
  errorContainer: Color(0xFF7F1D1D),
  onErrorContainer: Color(0xFFF87171),
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

// 🖤💎 BLACK SAPPHIRE METALLIC GRADIENT - SEKSI DARK!
const LinearGradient blackSapphireMetallicGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF0A0A0A), // ⚫ Deep Black Steel (0% - GORE) - najcrnja
    Color(0xFF1A1A2E), // 🌑 Midnight Sapphire (25%) - tamno safir
    Color(0xFF16213E), // 💎 Dark Sapphire Core (50% - CENTAR) - metalik safir
    Color(0xFF3D52A0), // ✨ Electric Sapphire (75%) - svetliji safir
    Color(0xFF7209B7), // 🔮 Purple Metallic Glow (100% - DOLE) - seksi purple shine
  ],
  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
);

// 🎨 TEMA EKSTENZIJA - dodaje gradijent pozadinu
extension ThemeGradients on ThemeData {
  LinearGradient get backgroundGradient => tripleBlueFashionGradient;

  // Glassmorphism kontejner boje
  Color get glassContainer => Colors.white.withOpacity(0.06);
  Color get glassBorder => Colors.white.withOpacity(0.13);
  BoxShadow get glassShadow => BoxShadow(
        color: Colors.black.withOpacity(0.22),
        blurRadius: 24,
        offset: const Offset(0, 8),
      );
}

// ⚡ Triple Blue Fashion Theme
final ThemeData tripleBlueFashionTheme = ThemeData(
  colorScheme: tripleBlueFashionColorScheme,
  useMaterial3: true,
  fontFamily: 'Inter',
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

// 🖤💎 Black Sapphire Metallic Theme - DARK SEKSI!
final ThemeData blackSapphireMetallicTheme = ThemeData(
  colorScheme: blackSapphireMetallicColorScheme,
  useMaterial3: true,
  fontFamily: 'Inter',
  scaffoldBackgroundColor: const Color(0xFF0F0F0F), // Tamno crna pozadina
  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Color(0xFF0A0A0A), // Deep Black Steel
    foregroundColor: Color(0xFFE8E8E8), // Svetlo siva
    systemOverlayStyle: SystemUiOverlayStyle.light,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Color(0xFFE8E8E8),
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
      color: const Color(0xFF1FA2FF).withOpacity(0.4),
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF021B79).withOpacity(0.3),
        blurRadius: 32,
        offset: const Offset(0, 12),
        spreadRadius: 4,
      ),
      BoxShadow(
        color: const Color(0xFF4F7CAC).withOpacity(0.2),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: const Color(0xFFE91E63).withOpacity(0.4),
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
      color: const Color(0xFF1FA2FF).withOpacity(0.6),
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF021B79).withOpacity(0.4),
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

// 🖤💎 Black Sapphire Metallic Styles - DARK SEKSI STILOVI!
class BlackSapphireMetallicStyles {
  static BoxDecoration cardDecoration = BoxDecoration(
    color: const Color(0xFF1A1A1A), // Tamna karta
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      width: 2,
      color: const Color(0xFF7209B7).withOpacity(0.6), // Purple glow border
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF0A0A0A).withOpacity(0.8), // Deep black shadow
        blurRadius: 32,
        offset: const Offset(0, 12),
        spreadRadius: 4,
      ),
      BoxShadow(
        color: const Color(0xFF7209B7).withOpacity(0.3), // Purple glow
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: const Color(0xFF3D52A0).withOpacity(0.4), // Sapphire glow
        blurRadius: 36,
        offset: const Offset(0, 16),
        spreadRadius: 6,
      ),
    ],
  );

  static BoxDecoration gradientBackground = const BoxDecoration(
    gradient: blackSapphireMetallicGradient,
  );

  static BoxDecoration gradientButton = BoxDecoration(
    gradient: blackSapphireMetallicGradient,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      width: 1.5,
      color: const Color(0xFF7209B7).withOpacity(0.8), // Purple metallic border
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF0A0A0A).withOpacity(0.6),
        blurRadius: 24,
        offset: const Offset(0, 12),
        spreadRadius: 2,
      ),
    ],
  );

  static BoxDecoration dropdownDecoration = BoxDecoration(
    color: const Color(0xFF1A1A1A), // Tamna pozadina
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xFF3D52A0).withOpacity(0.6), // Electric sapphire border
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF16213E).withOpacity(0.4), // Dark sapphire shadow
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );

  static BoxDecoration popupDecoration = BoxDecoration(
    color: const Color(0xFF0F0F0F), // Najcrnja pozadina
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: const Color(0xFF7209B7).withOpacity(0.7), // Purple metallic border
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF0A0A0A).withOpacity(0.8), // Deep black shadow
        blurRadius: 36,
        offset: const Offset(0, 16),
        spreadRadius: 6,
      ),
      BoxShadow(
        color: const Color(0xFF7209B7).withOpacity(0.3), // Purple glow
        blurRadius: 48,
        offset: const Offset(0, 20),
        spreadRadius: 8,
      ),
    ],
  );
}
