import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 📳 HAPTIC FEEDBACK SERVICE
/// Dodaje tactile response za bolje user experience
class HapticService {
  /// 💫 Light impact - za obične tap-ove
  static void lightImpact() {
    try {
      HapticFeedback.lightImpact();
      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }

  /// 🔥 Medium impact - za važnije akcije
  static void mediumImpact() {
    try {
      HapticFeedback.mediumImpact();
      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }

  /// ⚡ Heavy impact - za kritične akcije
  static void heavyImpact() {
    try {
      HapticFeedback.heavyImpact();
      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }

  /// ✅ Selection click - za picker wheel i slično
  static void selectionClick() {
    try {
      HapticFeedback.selectionClick();
      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }

  /// 🔔 Success feedback - kad se nešto uspešno završi
  static void success() {
    try {
      HapticFeedback.lightImpact();
      // Double tap za success feeling
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.lightImpact();
      });
      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }

  /// ❌ Error feedback - za greške
  static void error() {
    try {
      HapticFeedback.heavyImpact();
      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }
}

/// 📳 ENHANCED ELEVATED BUTTON sa haptic feedback
class HapticElevatedButton extends StatelessWidget {
  const HapticElevatedButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.hapticType = HapticType.light,
    this.style,
  }) : super(key: key);
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
