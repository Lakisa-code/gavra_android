import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// 🎨 Flutter Bank Gradient AppBar
/// Beautiful gradient AppBar inspired by the Flutter Bank design
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({
    Key? key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.titleColor,
    this.titleSpacing,
    this.centerTitle = true,
    this.elevation = 0,
  })  : assert(
          title != null || titleWidget != null,
          'Either title or titleWidget must be provided',
        ),
        super(key: key);
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? titleColor;
  final double? titleSpacing;
  final bool centerTitle;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: tripleBlueFashionGradient,
      ),
      child: AppBar(
        title: titleWidget ??
            Text(
              title!,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: titleColor ?? Colors.white,
                letterSpacing: 0.5,
              ),
            ),
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        backgroundColor: Colors.transparent,
        elevation: elevation,
        titleSpacing: titleSpacing,
        centerTitle: centerTitle,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// 🎨 Flutter Bank Scaffold with Gradient
/// Complete scaffold with gradient background and beautiful styling
class GradientScaffold extends StatelessWidget {
  const GradientScaffold({
    Key? key,
    this.appBarTitle,
    required this.body,
    this.appBarActions,
    this.bottomNavigationBar,
    this.drawer,
    this.endDrawer,
    this.extendBodyBehindAppBar = false,
    this.hasGradientBackground = false,
    this.backgroundColor,
  }) : super(key: key);
  final String? appBarTitle;
  final Widget body;
  final List<Widget>? appBarActions;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Widget? endDrawer;
  final bool extendBodyBehindAppBar;
  final bool hasGradientBackground;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarTitle != null
          ? GradientAppBar(
              title: appBarTitle!,
              actions: appBarActions,
            )
          : null,
      body: hasGradientBackground
          ? Container(
              decoration: const BoxDecoration(
                gradient: tripleBlueFashionGradient,
              ),
              child: body,
            )
          : body,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
      endDrawer: endDrawer,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      backgroundColor: backgroundColor,
    );
  }
}

/// 🃏 Flutter Bank Card
/// Beautiful card with consistent styling
class FlutterBankCard extends StatelessWidget {
  const FlutterBankCard({
    Key? key,
    required this.child,
    this.margin,
    this.padding,
    this.elevation,
    this.color,
    this.onTap,
  }) : super(key: key);
  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final double? elevation;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

/// 🎨 Flutter Bank Button Variants
enum FlutterBankButtonVariant { primary, secondary }

/// 🔘 Flutter Bank Button
/// Beautiful gradient button with consistent styling
class FlutterBankButton extends StatelessWidget {
  const FlutterBankButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = FlutterBankButtonVariant.primary,
    this.padding,
    this.width,
  }) : super(key: key);

  // Legacy constructor for backward compatibility
  const FlutterBankButton.secondary({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.padding,
    this.width,
  })  : variant = FlutterBankButtonVariant.secondary,
        super(key: key);
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final FlutterBankButtonVariant variant;
  final EdgeInsets? padding;
  final double? width;

  bool get isSecondary => variant == FlutterBankButtonVariant.secondary;

  @override
  Widget build(BuildContext context) {
    // 🎨 Create theme-aware gradient decoration
    final gradientDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.primaryContainer,
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );

    return Container(
      width: width,
      decoration: isSecondary ? null : gradientDecoration,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary ? Colors.white : Colors.transparent,
          foregroundColor: isSecondary ? Theme.of(context).colorScheme.primary : Colors.white,
          elevation: isSecondary ? 2 : 0,
          shadowColor: Colors.transparent,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isSecondary
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  )
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: isSecondary ? Theme.of(context).colorScheme.primary : Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}





