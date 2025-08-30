import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// 📳 HAPTIC FEEDBACK SERVICE
/// Dodaje tactile response za bolje user experience
class HapticService {
  static final _logger = Logger();

  /// 💫 Light impact - za obične tap-ove
  static void lightImpact() {
    try {
      HapticFeedback.lightImpact();
      _logger.d('🔸 Light haptic feedback triggered');
    } catch (e) {
      _logger.w('⚠️ Haptic feedback failed: $e');
    }
  }

  /// 🔥 Medium impact - za važnije akcije
  static void mediumImpact() {
    try {
      HapticFeedback.mediumImpact();
      _logger.d('🔹 Medium haptic feedback triggered');
    } catch (e) {
      _logger.w('⚠️ Haptic feedback failed: $e');
    }
  }

  /// ⚡ Heavy impact - za kritične akcije
  static void heavyImpact() {
    try {
      HapticFeedback.heavyImpact();
      _logger.d('🔸 Heavy haptic feedback triggered');
    } catch (e) {
      _logger.w('⚠️ Haptic feedback failed: $e');
    }
  }

  /// ✅ Selection click - za picker wheel i slično
  static void selectionClick() {
    try {
      HapticFeedback.selectionClick();
      _logger.d('🎯 Selection haptic feedback triggered');
    } catch (e) {
      _logger.w('⚠️ Haptic feedback failed: $e');
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
      _logger.d('✅ Success haptic pattern triggered');
    } catch (e) {
      _logger.w('⚠️ Haptic feedback failed: $e');
    }
  }

  /// ❌ Error feedback - za greške
  static void error() {
    try {
      HapticFeedback.heavyImpact();
      _logger.d('❌ Error haptic feedback triggered');
    } catch (e) {
      _logger.w('⚠️ Haptic feedback failed: $e');
    }
  }

  /// 🎵 Custom pattern - za specijalne slučajeve
  static void customPattern({
    int pulses = 3,
    int delayMs = 100,
  }) {
    try {
      for (int i = 0; i < pulses; i++) {
        Future.delayed(Duration(milliseconds: delayMs * i), () {
          HapticFeedback.lightImpact();
        });
      }
      _logger.d('🎵 Custom haptic pattern triggered ($pulses pulses)');
    } catch (e) {
      _logger.w('⚠️ Haptic feedback failed: $e');
    }
  }
}

/// 📳 HAPTIC BUTTON WRAPPER
/// Automatski dodaje haptic feedback na dugmad
class HapticButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final HapticType hapticType;

  const HapticButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.hapticType = HapticType.light,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed == null
          ? null
          : () {
              // Trigger haptic feedback
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
              // Execute callback
              onPressed?.call();
            },
      child: child,
    );
  }
}

/// 📳 ENHANCED ELEVATED BUTTON sa haptic feedback
class HapticElevatedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final HapticType hapticType;
  final ButtonStyle? style;

  const HapticElevatedButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.hapticType = HapticType.light,
    this.style,
  }) : super(key: key);

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
