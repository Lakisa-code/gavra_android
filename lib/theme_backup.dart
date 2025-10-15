import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🌊💎 GEOCODING BLUE PARADISE - Identične boje kao Geocoding Screen!
const ColorScheme flutterBankColorScheme = ColorScheme(
  brightness: Brightness.light,
  // Geocoding screen identical blue colors
  primary: Color(0xFF1E3A8A), // Blue-900 (gore levo u geocoding)
  onPrimary: Colors.white,
  primaryContainer: Color(0xFF3B82F6), // Blue-500 (sredina u geocoding)
  onPrimaryContainer: Colors.white,

  // Secondary colors - geocoding blue progression
  secondary: Color(0xFF1D4ED8), // Blue-600 (dole desno u geocoding)
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFF60A5FA), // Blue-400 (svetliji accent)
  onSecondaryContainer: Colors.white,

  // Surface colors - blue tinted
  surface: Color(0xFFF0F9FF), // Blue-50 pozadina
  onSurface: Color(0xFF1E3A8A),
  surfaceContainerHighest: Color(0xFFE0F2FE),

  // Error colors - coral accent
  error: Color(0xFFFF4757), // Coral red
  onError: Colors.white,
);

// 💖 SVETLANA'S PINK THEME - Specijalna pink tema samo za Svetlanu!
const ColorScheme svetlanaPinkColorScheme = ColorScheme(
  brightness: Brightness.light,
  // Pink gradient colors - elegantan pink kao glavni
  primary: Color(0xFFE91E63), // Hot pink za glavni
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFF06292), // Svetliji pink
  onPrimaryContainer: Colors.white,

  // Secondary colors za accent
  secondary: Color(0xFFFF4081), // Pink accent
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFFCE4EC), // Veoma svetao pink
  onSecondaryContainer: Color(0xFFAD1457),

  // Surface colors - pink tinted
  surface: Color(0xFFFDF2F8), // Svetlo pink pozadina
  onSurface: Color(0xFF1A1A1A),
  surfaceContainerHighest: Color(0xFFFEF7F0),

  // Error colors
  error: Color(0xFFE57373),
  onError: Colors.white,
);

// �💫 MIDNIGHT SEDUCTION - Seksi dark tema sa prelivima ludila!
const ColorScheme darkSapphirePlatinumColorScheme = ColorScheme(
  brightness: Brightness.dark,
  // Midnight seduction colors - seksi crno/siva sa neon akcentima
  primary: Color(0xFFE5E7EB), // Platinum silver (glavni svetli)
  onPrimary: Color(0xFF000000), // Pure black tekst
  primaryContainer: Color(0xFF1F2937), // Dark charcoal container
  onPrimaryContainer: Color(0xFFF3F4F6),

  // Secondary colors - neon purple/pink accents za seksapil
  secondary: Color(0xFFBB86FC), // Electric purple (seksi akcenat)
  onSecondary: Color(0xFF000000),
  secondaryContainer: Color(0xFF6B46C1), // Deep purple container
  onSecondaryContainer: Color(0xFFE5E7EB),

  // Surface colors - deep black/charcoal progression
  surface: Color(0xFF000000), // Pure black pozadina (najseksi)
  onSurface: Color(0xFFF9FAFB), // Almost white tekst
  surfaceVariant: Color(0xFF111827), // Dark charcoal variant
  onSurfaceVariant: Color(0xFFD1D5DB),

  // Dark theme specific - hot pink accents
  inverseSurface: Color(0xFFF9FAFB),
  onInverseSurface: Color(0xFF000000),
  inversePrimary: Color(0xFF374151),

  outline: Color(0xFF4B5563),
  outlineVariant: Color(0xFF1F2937),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  surfaceTint: Color(0xFF93C5FD),

  // Error colors for dark
  error: Color(0xFFEF4444),
  onError: Color(0xFF1F2937),
  errorContainer: Color(0xFF7F1D1D),
  onErrorContainer: Color(0xFFFECACA),
);

// ⚡🔷💠 TRIPLE BLUE FUSION - Electric + Ice + Neon kombinacija!
const ColorScheme tripleBlueFusionColorScheme = ColorScheme(
  brightness: Brightness.light,
  // Electric Blue Shine kao glavni
  primary: Color(0xFF021B79), // Electric Blue Shine - taman
  onPrimary: Colors.white,
  primaryContainer: Color(0xFF0575E6), // Electric Blue Shine - svetao
  onPrimaryContainer: Colors.white,

  // Blue Ice Metallic kao secondary
  secondary: Color(0xFF1E3A78), // Blue Ice početak
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFF4F7CAC), // Blue Ice sredina
  onSecondaryContainer: Colors.white,

  // Neon Blue Glow za tertiary i accente
  tertiary: Color(0xFF1FA2FF), // Neon Blue početak
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFF12D8FA), // Neon Blue sredina
  onTertiaryContainer: Color(0xFF003844),

  // Surface colors - kombinacija svih 3 
  surface: Color(0xFFF0FFFE), // Svetlo neon pozadina
  onSurface: Color(0xFF021B79),
  surfaceVariant: Color(0xFFE1F8FF), // Ice blue tint
  onSurfaceVariant: Color(0xFF1E3A78),
  
  surfaceContainerHighest: Color(0xFFCCF2FF),
  surfaceContainer: Color(0xFFE8F9FF),
  surfaceContainerHigh: Color(0xFFEAFAFF),
  surfaceContainerLow: Color(0xFFF5FDFF),
  surfaceContainerLowest: Color(0xFFFAFEFF),

  // Outline colors
  outline: Color(0xFF4F7CAC),
  outlineVariant: Color(0xFFA8D8E8),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  surfaceTint: Color(0xFF12D8FA),

  // Error colors
  error: Color(0xFFFF4757),
  onError: Colors.white,
  errorContainer: Color(0xFFFFEBEE),
  onErrorContainer: Color(0xFFC62828),
);

// 🌟 Custom Color Extensions for App-Specific Colors
extension AppColors on ColorScheme {
  // 🧑‍🎓 Student Colors
  Color get studentPrimary => const Color(0xFFFF9800); // Orange
  Color get studentSecondary => const Color(0xFFFFA726);
  Color get studentContainer => const Color(0xFFFFF3E0);
  Color get onStudentContainer => const Color(0xFFE65100);

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

// � Main Metallic Blue Theme - Preliva se kao metalni sjaj!
final ThemeData flutterBankTheme = ThemeData(
  colorScheme: flutterBankColorScheme,
  useMaterial3: true,
  fontFamily: 'Inter', // Modern, clean font
  scaffoldBackgroundColor: const Color(0xFFF8FBFF), // � Svetla metalik pozadina

  // 📱 AppBar Theme - Metallic blue gradient sa prelivom
  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Color(0xFF4A90E2), // � Steel blue pozadina
    foregroundColor: Colors.white,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      letterSpacing: 0.5,
    ),
    // iconTheme: skipped for Flutter 3.24.3 compatibility
  ),

  // 🃏 Card Theme - skipped for Flutter 3.24.3 compatibility

  // 📝 Text Theme - Modern typography
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1A1A1A),
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1A1A1A),
      letterSpacing: -0.3,
    ),
    headlineLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1A1A1A),
      letterSpacing: 0,
    ),
    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1A1A1A),
      letterSpacing: 0.1,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1A1A1A),
      letterSpacing: 0.1,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Color(0xFF1A1A1A),
      letterSpacing: 0.2,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: Color(0xFF1A1A1A),
      letterSpacing: 0.3,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: Color(0xFF424242),
      letterSpacing: 0.3,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: Color(0xFF757575),
      letterSpacing: 0.4,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Color(0xFF1A1A1A),
      letterSpacing: 0.5,
    ),
  ),

  // 💎 Button Themes - Sapphire Platinum Flow
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF0F1B4C), // Deep sapphire navy
      foregroundColor: Colors.white,
      elevation: 15,
      shadowColor: const Color(0xFF0F1B4C).withOpacity(0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFF0F1B4C), // Deep sapphire text
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
  ),

  // 📄 Input Decoration Theme
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF8F9FA),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: Color(0xFF0F1B4C),
        width: 2,
      ), // Sapphire focus
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    labelStyle: const TextStyle(
      color: Color(0xFF757575),
      fontWeight: FontWeight.w500,
    ),
  ),

  // 🎭 Dialog Theme - skipped for Flutter 3.24.3 compatibility

  // 📊 Other component themes - skipped for Flutter 3.24.3 compatibility

  // iconTheme: skipped for Flutter 3.24.3 compatibility
);

// 🌊💎 GEOCODING IDENTICAL Gradient - Identičan kao u Geocoding Screen!
const LinearGradient flutterBankGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF1E3A8A), // Blue-900 (gore levo - identično)
    Color(0xFF3B82F6), // Blue-500 (sredina - identično)
    Color(0xFF1D4ED8), // Blue-600 (dole desno - identično)
  ],
  stops: [0.0, 0.5, 1.0],
);

// 🌙💙 DARK Midnight Seduction Gradient - Seksi Black/Gray Ludilo
const LinearGradient darkSapphirePlatinumGradient = LinearGradient(
  colors: [
    Color(0xFF000000), // Pure black seksapil (levo)
    Color(0xFF111111), // Tamno charcoal
    Color(0xFF1F2937), // Rich dark gray (srednja)
    Color(0xFF374151), // Medium gray
    Color(0xFF6B7280), // Light platinum gray
    Color(0xFFBB86FC), // Electric purple seksapil (desno)
  ],
  stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
);

// ⚡🔷💠 TRIPLE BLUE FUSION - Electric Blue + Ice Metallic + Neon Glow
const LinearGradient tripleBlueGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF021B79), // ⚡ Electric Blue Shine - početak
    Color(0xFF0575E6), // ⚡ Electric Blue Shine - završetak
    Color(0xFF1E3A78), // 🔷 Blue Ice Metallic - početak
    Color(0xFF4F7CAC), // 🔷 Blue Ice Metallic - sredina
    Color(0xFFA8D8E8), // 🔷 Blue Ice Metallic - završetak
    Color(0xFF1FA2FF), // 💠 Neon Blue Glow - početak
    Color(0xFF12D8FA), // 💠 Neon Blue Glow - sredina
    Color(0xFFA6FFCB), // 💠 Neon Blue Glow - završetak
  ],
  stops: [0.0, 0.14, 0.28, 0.42, 0.56, 0.7, 0.85, 1.0],
);

// 🌊💎 Utility class for geocoding blue styles
class FlutterBankStyles {
  // Card decoration with geocoding blue glow and borders
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      width: 2,
      color: const Color(0xFF1D4ED8).withOpacity(0.4), // Blue-600 border
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1E3A8A).withOpacity(0.3), // Blue-900 glow
        blurRadius: 32,
        offset: const Offset(0, 12),
        spreadRadius: 4,
      ),
      BoxShadow(
        color: const Color(0xFF3B82F6).withOpacity(0.25), // Blue-500 shimmer
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: const Color(0xFF1D4ED8).withOpacity(0.2), // Blue-600 glow
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: const Color(0xFF60A5FA).withOpacity(0.15), // Blue-400 accent
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // Geocoding gradient background
  static BoxDecoration gradientBackground = const BoxDecoration(
    gradient: flutterBankGradient,
  );

  // Button with geocoding blue gradient
  static BoxDecoration gradientButton = BoxDecoration(
    gradient: flutterBankGradient,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      width: 1.5,
      color: const Color(0xFF1D4ED8).withOpacity(0.6), // Blue-600 border
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1E3A8A).withOpacity(0.6), // Blue-900 shadow
        blurRadius: 24,
        offset: const Offset(0, 12),
        spreadRadius: 2,
      ),
      BoxShadow(
        color: const Color(0xFF3B82F6).withOpacity(0.4), // Blue-500 shimmer
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: const Color(0xFF1D4ED8).withOpacity(0.3), // Blue-600 glow
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: const Color(0xFF60A5FA).withOpacity(0.2), // Blue-400 accent
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ],
  );

  // Popup/Dialog decoration with geocoding blue styling
  static BoxDecoration popupDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: const Color(0xFF1D4ED8).withOpacity(0.5), // Blue-600 border
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1E3A8A).withOpacity(0.4), // Blue-900 glow
        blurRadius: 36,
        offset: const Offset(0, 16),
        spreadRadius: 6,
      ),
      BoxShadow(
        color: const Color(0xFF3B82F6).withOpacity(0.3), // Blue-500 shimmer
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: const Color(0xFF1D4ED8).withOpacity(0.2), // Blue-600 accent
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );

  // Dropdown decoration for light theme
  static BoxDecoration dropdownDecoration = BoxDecoration(
    color: const Color(0xFFF0F9FF), // Blue-50 background
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xFF1D4ED8).withOpacity(0.4),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1E3A8A).withOpacity(0.3),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: const Color(0xFF3B82F6).withOpacity(0.2),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

// 🌙� Dark Utility class for Midnight Seduction styles
class DarkSapphirePlatinumStyles {
  // Card decoration with sexy dark glow and purple accents
  static BoxDecoration cardDecoration = BoxDecoration(
    color: const Color(0xFF111111), // Rich charcoal background
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: const Color(0xFFBB86FC).withOpacity(0.3), // Electric purple border
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFBB86FC).withOpacity(0.2), // Purple seduction glow
        blurRadius: 32,
        offset: const Offset(0, 12),
        spreadRadius: 4,
      ),
      BoxShadow(
        color: const Color(0xFF6B7280).withOpacity(0.15), // Platinum gray shimmer
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: const Color(0xFF000000).withOpacity(0.8), // Deep black depth
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // Dark midnight seduction gradient background
  static BoxDecoration gradientBackground = const BoxDecoration(
    gradient: darkSapphirePlatinumGradient,
  );

  // Button with sexy dark gradient and purple glow
  static BoxDecoration gradientButton = BoxDecoration(
    gradient: darkSapphirePlatinumGradient,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFBB86FC).withOpacity(0.4), // Electric purple glow
        blurRadius: 28,
        offset: const Offset(0, 12),
        spreadRadius: 3,
      ),
      BoxShadow(
        color: const Color(0xFF6B7280).withOpacity(0.2), // Platinum gray elegance
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: const Color(0xFF374151).withOpacity(0.3), // Dark gray depth
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: const Color(0xFF000000).withOpacity(0.6), // Pure black seksapil
        blurRadius: 6,
        offset: const Offset(0, 3),
      ),
    ],
  );

  // Popup/Dialog decoration with dark seduction styling
  static BoxDecoration popupDecoration = BoxDecoration(
    color: const Color(0xFF111111), // Rich charcoal background
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: const Color(0xFFBB86FC).withOpacity(0.4), // Electric purple border
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFBB86FC).withOpacity(0.3), // Purple glow
        blurRadius: 40,
        offset: const Offset(0, 16),
        spreadRadius: 6,
      ),
      BoxShadow(
        color: const Color(0xFF000000).withOpacity(0.9), // Deep black shadow
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ],
  );

  // Dropdown decoration for dark theme
  static BoxDecoration dropdownDecoration = BoxDecoration(
    color: const Color(0xFF1F2937), // Dark gray background
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xFFBB86FC).withOpacity(0.3),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFBB86FC).withOpacity(0.2),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: const Color(0xFF000000).withOpacity(0.7),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

// ⚡🔷💠 Triple Blue Fusion Utility class - Electric + Ice + Neon kombinacija!
class TripleBlueFusionStyles {
  // Card decoration sa triple blue glow effect-om
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      width: 2,
      color: const Color(0xFF1FA2FF).withOpacity(0.4), // Neon blue border
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF021B79).withOpacity(0.3), // Electric blue glow
        blurRadius: 32,
        offset: const Offset(0, 12),
        spreadRadius: 4,
      ),
      BoxShadow(
        color: const Color(0xFF4F7CAC).withOpacity(0.2), // Ice metallic shimmer
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: const Color(0xFF12D8FA).withOpacity(0.15), // Neon glow accent
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );

  // Gradient background sa triple blue fusion
  static BoxDecoration gradientBackground = const BoxDecoration(
    gradient: tripleBlueGradient,
  );

  // Button sa triple blue gradient effect-om
  static BoxDecoration gradientButton = BoxDecoration(
    gradient: tripleBlueGradient,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      width: 1.5,
      color: const Color(0xFF1FA2FF).withOpacity(0.6), // Neon blue border
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF021B79).withOpacity(0.6), // Electric blue shadow
        blurRadius: 24,
        offset: const Offset(0, 12),
        spreadRadius: 2,
      ),
      BoxShadow(
        color: const Color(0xFF4F7CAC).withOpacity(0.4), // Ice metallic shimmer
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: const Color(0xFF12D8FA).withOpacity(0.3), // Neon glow
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: const Color(0xFFA6FFCB).withOpacity(0.2), // Neon green accent
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ],
  );

  // Popup/Dialog decoration sa triple blue styling
  static BoxDecoration popupDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: const Color(0xFF1FA2FF).withOpacity(0.5), // Neon blue border
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF021B79).withOpacity(0.4), // Electric blue glow
        blurRadius: 36,
        offset: const Offset(0, 16),
        spreadRadius: 6,
      ),
      BoxShadow(
        color: const Color(0xFF4F7CAC).withOpacity(0.3), // Ice metallic shimmer
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: const Color(0xFF12D8FA).withOpacity(0.2), // Neon glow accent
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );

  // Dropdown decoration za triple blue
  static BoxDecoration dropdownDecoration = BoxDecoration(
    color: const Color(0xFFF0F9FF), // Svetla pozadina
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xFF1FA2FF).withOpacity(0.4),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF021B79).withOpacity(0.3),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: const Color(0xFF12D8FA).withOpacity(0.2),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

// 💖 SVETLANA'S EXCLUSIVE PINK THEME - samo za Svetlanu!
final ThemeData svetlanaPinkTheme = ThemeData(
  colorScheme: svetlanaPinkColorScheme,
  useMaterial3: true,
  fontFamily: 'Inter',
  scaffoldBackgroundColor: const Color(0xFFFDF2F8), // Pink-tinted pozadina

  // 💖 Pink AppBar za Svetlanu
  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Color(0xFFE91E63), // Hot pink
    foregroundColor: Colors.white,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      letterSpacing: 0.5,
    ),
    // iconTheme: skipped for Flutter 3.24.3 compatibility
  ),

  // 💖 Pink Card Theme - skipped for Flutter 3.24.3 compatibility

  // 💖 Pink Text Theme (isti kao originalni)
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1A1A1A),
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1A1A1A),
      letterSpacing: -0.3,
    ),
    headlineLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1A1A1A),
      letterSpacing: 0,
    ),
    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1A1A1A),
      letterSpacing: 0.1,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1A1A1A),
      letterSpacing: 0.1,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Color(0xFF1A1A1A),
      letterSpacing: 0.2,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: Color(0xFF1A1A1A),
      letterSpacing: 0.3,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: Color(0xFF424242),
      letterSpacing: 0.3,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: Color(0xFF757575),
      letterSpacing: 0.4,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Color(0xFF1A1A1A),
      letterSpacing: 0.5,
    ),
  ),

  // 💖 Pink Button Themes
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFE91E63), // Hot pink
      foregroundColor: Colors.white,
      elevation: 6,
      shadowColor: const Color(0xFFE91E63).withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFFE91E63), // Pink text buttons
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFE91E63),
      side: const BorderSide(color: Color(0xFFE91E63), width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    ),
  ),

  // 💖 Pink Input Decoration
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE91E63), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 16),
    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
  ),

  // 💖 Pink Switch Theme
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const Color(0xFFE91E63);
      }
      return Colors.grey.shade400;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const Color(0xFFE91E63).withOpacity(0.3);
      }
      return Colors.grey.shade300;
    }),
  ),
);

// 💖 Pink gradijent za Svetlanu
const LinearGradient svetlanaPinkGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFE91E63), // Hot pink
    Color(0xFFF06292), // Medium pink
    Color(0xFFFF80AB), // Light pink
  ],
  stops: [0.0, 0.5, 1.0],
);

// 💖 Pink styles za Svetlanu
class SvetlanaPinkStyles {
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFE91E63).withOpacity(0.1),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration gradientBackground = const BoxDecoration(
    gradient: svetlanaPinkGradient,
  );

  static BoxDecoration gradientButton = BoxDecoration(
    gradient: svetlanaPinkGradient,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFE91E63).withOpacity(0.3),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

// � DYNAMIC THEME HELPERS for Popups
class AppThemeHelpers {
  /// Vraća boju na osnovu tipa putnika (učenik/radnik)
  static Color getTypeColor(String tip, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return tip == 'ucenik' ? colorScheme.studentPrimary : colorScheme.workerPrimary;
  }

  /// Vraća kontejner boju na osnovu tipa putnika
  static Color getTypeContainerColor(String tip, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return tip == 'ucenik' ? colorScheme.studentContainer : colorScheme.workerContainer;
  }

  /// Vraća on-container boju na osnovu tipa putnika
  static Color getTypeOnContainerColor(String tip, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return tip == 'ucenik' ? colorScheme.onStudentContainer : colorScheme.onWorkerContainer;
  }

  /// Vraća gradijent na osnovu tipa putnika
  static LinearGradient getTypeGradient(String tip, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (tip == 'ucenik') {
      return LinearGradient(
        colors: [
          colorScheme.studentContainer,
          colorScheme.studentSecondary.withOpacity(0.3),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return LinearGradient(
        colors: [
          colorScheme.workerContainer,
          colorScheme.workerSecondary.withOpacity(0.3),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  /// Vraća ikonu na osnovu tipa putnika
  static IconData getTypeIcon(String tip) {
    return tip == 'ucenik' ? Icons.school : Icons.business;
  }

  /// Vraća emoji na osnovu tipa putnika
  static String getTypeEmoji(String tip) {
    return tip == 'ucenik' ? '🏫' : '🏢';
  }
}

// �🎭 THEME SELECTOR - bira temu na osnovu vozača
class ThemeSelector {
  /// Vraća odgovarajuću temu na osnovu imena vozača
  static ThemeData getThemeForDriver(String? driverName) {
    if (driverName?.toLowerCase() == 'svetlana') {
      return svetlanaPinkTheme; // 💖 Pink tema za Svetlanu!
    }
    return flutterBankTheme; // 🎨 Default plava tema za sve ostale
  }
}




