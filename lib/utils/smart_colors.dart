import 'package:flutter/material.dart';

/// SMART COLORS EXTENSION - Pametne boje koje prate temu!
/// Koristi umesto hardkovanih Colors.red, Colors.green itd.
extension SmartColors on ColorScheme {
  // ERROR COLORS - Pametna crvena za greške
  Color get smartError {
    switch (brightness) {
      case Brightness.light:
        // Light tema - standardna error boja
        return error;
      case Brightness.dark:
        // Dark tema - mutna crvena (ne zaslepljuje)
        return const Color(0xFFCF6679);
    }
  }

  Color get smartErrorContainer {
    switch (brightness) {
      case Brightness.light:
        return errorContainer;
      case Brightness.dark:
        return const Color(0xFF93000A);
    }
  }

  // SUCCESS COLORS - Pametna zelena za uspeh
  Color get smartSuccess {
    switch (brightness) {
      case Brightness.light:
        // Ako je pink tema, koristi pink umesto zelene
        if (primary.value == 0xFFE91E63) {
          // Pink tema
          return const Color(0xFF4CAF50); // Blaza zelena za pink temu
        }
        return const Color(0xFF4CAF50); // Standardna zelena
      case Brightness.dark:
        return const Color(0xFF81C784); // Mutna zelena za dark
    }
  }

  Color get smartSuccessContainer {
    switch (brightness) {
      case Brightness.light:
        if (primary.value == 0xFFE91E63) {
          // Pink tema
          return const Color(0xFFC8E6C9);
        }
        return const Color(0xFFC8E6C9);
      case Brightness.dark:
        return const Color(0xFF2E7D32);
    }
  }

  // WARNING COLORS - Pametna žuta/narandžasta za upozorenja
  Color get smartWarning {
    switch (brightness) {
      case Brightness.light:
        if (primary.value == 0xFFE91E63) {
          // Pink tema
          return const Color(0xFFFF9800); // Narandžasta za pink
        }
        return const Color(0xFFFF9800); // Standardna narandžasta
      case Brightness.dark:
        return const Color(0xFFFFB74D); // Mutna narandžasta
    }
  }

  Color get smartWarningContainer {
    switch (brightness) {
      case Brightness.light:
        return const Color(0xFFFFF3E0);
      case Brightness.dark:
        return const Color(0xFFE65100);
    }
  }

  // INFO COLORS - Pametna plava za informacije
  Color get smartInfo {
    switch (brightness) {
      case Brightness.light:
        if (primary.value == 0xFFE91E63) {
          // Pink tema
          return const Color(0xFF2196F3); // Plava za pink temu
        }
        return primary; // Koristi primary boju teme
      case Brightness.dark:
        return const Color(0xFF64B5F6); // Mutna plava
    }
  }

  Color get smartInfoContainer {
    switch (brightness) {
      case Brightness.light:
        return primaryContainer;
      case Brightness.dark:
        return const Color(0xFF1565C0);
    }
  }

  // COMMUNICATION COLORS - Za pozive, SMS
  Color get smartPhone {
    switch (brightness) {
      case Brightness.light:
        return smartSuccess; // Koristi smart success boju
      case Brightness.dark:
        return const Color(0xFF81C784);
    }
  }

  Color get smartSms {
    switch (brightness) {
      case Brightness.light:
        return smartInfo; // Koristi smart info boju
      case Brightness.dark:
        return const Color(0xFF64B5F6);
    }
  }

  // GENDER COLORS - Za muško/žensko
  Color get smartMale {
    switch (brightness) {
      case Brightness.light:
        if (primary.value == 0xFFE91E63) {
          // Pink tema
          return const Color(0xFF2196F3);
        }
        return const Color(0xFF2196F3);
      case Brightness.dark:
        return const Color(0xFF64B5F6);
    }
  }

  Color get smartFemale {
    switch (brightness) {
      case Brightness.light:
        if (primary.value == 0xFFE91E63) {
          // Pink tema
          return primary; // Koristi pink
        }
        return const Color(0xFFE91E63); // Pink za non-pink teme
      case Brightness.dark:
        return const Color(0xFFF48FB1);
    }
  }
}

/// SMART SNACKBAR HELPER - Pametni SnackBar-ovi
class SmartSnackBar {
  /// Success SnackBar sa pametnim bojama
  static SnackBar success(String message, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: colorScheme.smartSuccess,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.all(16),
    );
  }

  /// Error SnackBar sa pametnim bojama
  static SnackBar error(String message, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: colorScheme.smartError,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.all(16),
    );
  }

  /// Warning SnackBar sa pametnim bojama
  static SnackBar warning(String message, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: colorScheme.smartWarning,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.all(16),
    );
  }

  /// Info SnackBar sa pametnim bojama
  static SnackBar info(String message, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: colorScheme.smartInfo,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.all(16),
    );
  }
}
