import 'package:flutter/material.dart';

/// 🔙 CUSTOM BACK BUTTON WIDGET
/// Konzistentno back dugme za sve AppBar-ove u aplikaciji
/// Sprečava overflow probleme i osigurava konzistentnu navigaciju
class CustomBackButton extends StatelessWidget {
  const CustomBackButton({
    Key? key,
    this.onPressed,
    this.color = Colors.white,
    this.size = 24,
    this.tooltip = 'Nazad',
    this.padding,
  }) : super(key: key);

  /// Callback funkcija za back akciju
  final VoidCallback? onPressed;

  /// Boja ikone (default: bela)
  final Color? color;

  /// Veličina ikone (default: 24)
  final double? size;

  /// Tooltip tekst (default: 'Nazad')
  final String? tooltip;

  /// Padding oko dugmeta
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? () => Navigator.pop(context),
      icon: Icon(
        Icons.arrow_back,
        color: color,
        size: size,
      ),
      tooltip: tooltip,
      padding: padding ?? const EdgeInsets.all(8.0),
      constraints: const BoxConstraints(
        minWidth: 48,
        minHeight: 48,
      ),
      splashRadius: 24,
    );
  }
}

/// 🎨 GRADIENT BACK BUTTON VARIANT
/// Specijalna varijanta za gradijent AppBar-ove
class GradientBackButton extends StatelessWidget {
  const GradientBackButton({
    Key? key,
    this.onPressed,
    this.tooltip = 'Nazad',
  }) : super(key: key);
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? () => Navigator.pop(context),
      icon: const Icon(
        Icons.arrow_back,
        color: Colors.white,
        size: 24,
      ),
      tooltip: tooltip,
      padding: const EdgeInsets.all(8.0),
      constraints: const BoxConstraints(
        minWidth: 48,
        minHeight: 48,
      ),
      splashRadius: 24,
    );
  }
}




