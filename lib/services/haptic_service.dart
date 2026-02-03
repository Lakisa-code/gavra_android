import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// 📳 HAPTIC FEEDBACK SERVICE
/// Dodaje tactile response za bolje user experience
class HapticService {
  /// 💫 Light impact - za obične tap-ove
  static void lightImpact() {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      // 🔇 Ignore
    }
  }

  /// 🔥 Medium impact - za važnije akcije
  static void mediumImpact() {
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      // 🔇 Ignore
    }
  }

  /// ⚡ Heavy impact - za kritične akcije
  static void heavyImpact() {
    try {
      HapticFeedback.heavyImpact();
    } catch (e) {
      // 🔇 Ignore
    }
  }

  /// ✅ Selection click - za picker wheel i slično
  static void selectionClick() {
    try {
      HapticFeedback.selectionClick();
    } catch (e) {
      // 🔇 Ignore
    }
  }

  /// 🔔 Success feedback - kad se nešto uspešno završi
  static void success() {
    try {
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.lightImpact();
      });
    } catch (e) {
      // 🔇 Ignore
    }
  }

  /// ❌ Error feedback - za greške
  static void error() {
    try {
      HapticFeedback.heavyImpact();
    } catch (e) {
      // 🔇 Ignore
    }
  }

  /// 📳 POKUPLJEN VIBRACIJA - jača vibracija kad se putnik pokupi
  /// Koristi Vibration paket za duže trajanje (200ms)
  static Future<void> putnikPokupljen() async {
    try {
      // Proveri da li uređaj podržava vibraciju
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // Dva kratka pulsa - "bip-bip" efekat
        await Vibration.vibrate(pattern: [0, 150, 100, 150], intensities: [0, 255, 0, 255]);
      } else {
        // Fallback na haptic feedback
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      // Fallback
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}
    }
  }
}

/// 📳 ENHANCED ELEVATED BUTTON sa haptic feedback
class HapticElevatedButton extends StatelessWidget {
  const HapticElevatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.hapticType = HapticType.light,
    this.style,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final HapticType hapticType;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: style,
      onPressed: onPressed == null
          ? null
          : () {
              // Trigger haptic
              switch (hapticType) {
                case HapticType.light:
                  HapticService.lightImpact();
                  break;
                case HapticType.medium:
                  HapticService.mediumImpact();
                  break;
                case HapticType.heavy:
                  HapticService.heavyImpact();
                  break;
                case HapticType.selection:
                  HapticService.selectionClick();
                  break;
                case HapticType.success:
                  HapticService.success();
                  break;
                case HapticType.error:
                  HapticService.error();
                  break;
              }
              onPressed?.call();
            },
      child: child,
    );
  }
}

/// 📱 Tipovi haptic feedback-a
enum HapticType {
  light,
  medium,
  heavy,
  selection,
  success,
  error,
}
