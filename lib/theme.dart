import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🎨 Flutter Bank Inspired Theme - Based on the beautiful design from the image
const ColorScheme flutterBankColorScheme = ColorScheme(
  brightness: Brightness.light,
  // Primary blue gradient colors inspired by the bank app
  primary: Color(0xFF4F7EFC), // Main blue from the image
  onPrimary: Colors.white,
  primaryContainer: Color(0xFF6B93FD), // Lighter blue
  onPrimaryContainer: Colors.white,

  // Secondary colors for accents
  secondary: Color(0xFF4CAF50), // Green for success states
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFE8F5E8),
  onSecondaryContainer: Color(0xFF2E7D32),

  // Surface colors - clean whites and subtle grays
  surface: Color(0xFFF8F9FD), // Svetlo plava pozadina
  onSurface: Color(0xFF1A1A1A),
  surfaceContainerHighest: Color(0xFFF8F9FA),

  // Error colors
  error: Color(0xFFFF5252),
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

// � Custom Color Extensions for App-Specific Colors
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

// �🎯 Main Flutter Bank Theme
final ThemeData flutterBankTheme = ThemeData(
  colorScheme: flutterBankColorScheme,
  useMaterial3: true,
  fontFamily: 'Inter', // Modern, clean font
  scaffoldBackgroundColor: const Color(0xFFF8F9FD), // 🎨 Seksi svetla pozadina

  // 📱 AppBar Theme - Beautiful gradient like in the image
  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Color(0xFF4F7EFC), // 🎨 Seksi plava pozadina
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

  // 🔘 Button Themes
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF4F7EFC),
      foregroundColor: Colors.white,
      elevation: 6,
      shadowColor: const Color(0xFF4F7EFC).withOpacity(0.3),
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
      foregroundColor: const Color(0xFF4F7EFC),
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

  // 🎯 FloatingActionButton Theme
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFF4F7EFC),
    foregroundColor: Colors.white,
    elevation: 8,
    shape: CircleBorder(),
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
      borderSide: const BorderSide(color: Color(0xFF4F7EFC), width: 2),
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

// 🌈 Custom gradient for AppBar (like in the Flutter Bank image)
const LinearGradient flutterBankGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF4F7EFC), // Main blue
    Color(0xFF6B93FD), // Lighter blue
    Color(0xFF8BB5FF), // Even lighter blue
  ],
  stops: [0.0, 0.5, 1.0],
);

// 🎯 Utility class for common styles
class FlutterBankStyles {
  // Card decoration with subtle shadow
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // Gradient background for screens
  static BoxDecoration gradientBackground = const BoxDecoration(
    gradient: flutterBankGradient,
  );

  // Button with gradient
  static BoxDecoration gradientButton = BoxDecoration(
    gradient: flutterBankGradient,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF4F7EFC).withOpacity(0.3),
        blurRadius: 12,
        offset: const Offset(0, 6),
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
    return tip == 'ucenik'
        ? colorScheme.studentPrimary
        : colorScheme.workerPrimary;
  }

  /// Vraća kontejner boju na osnovu tipa putnika
  static Color getTypeContainerColor(String tip, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return tip == 'ucenik'
        ? colorScheme.studentContainer
        : colorScheme.workerContainer;
  }

  /// Vraća on-container boju na osnovu tipa putnika
  static Color getTypeOnContainerColor(String tip, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return tip == 'ucenik'
        ? colorScheme.onStudentContainer
        : colorScheme.onWorkerContainer;
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
