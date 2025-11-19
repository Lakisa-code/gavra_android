import 'package:flutter/material.dart';

import '../theme.dart';

/// Uniform glassmorphism AppBar komponenta za celу aplikaciju
class GlassmorphismAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassmorphismAppBar({
    super.key,
    this.title,
    this.centerTitle = true,
    this.showBackButton = true,
    this.actions,
    this.height = 80.0,
    this.backgroundColor,
    this.elevation = 0,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  final Widget? title;
  final bool centerTitle;
  final bool showBackButton;
  final List<Widget>? actions;
  final double height;
  final Color? backgroundColor;
  final double elevation;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    // Proverava da li treba prikazati back button
    final bool canPop = Navigator.of(context).canPop();
    final bool shouldShowBackButton = showBackButton && canPop && automaticallyImplyLeading;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).glassContainer,
        border: Border.all(
          color: Theme.of(context).glassBorder,
          width: 1.5,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              // Leading widget (back button ili custom)
              if (leading != null)
                leading!
              else if (shouldShowBackButton)
                const GradientBackButton()
              else
                const SizedBox(width: 40), // Placeholder za spacing

              // Title
              if (title != null)
                Expanded(
                  child: centerTitle
                      ? Center(child: title!)
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: title!,
                          ),
                        ),
                )
              else
                const Spacer(),

              // Actions
              if (actions != null) ...actions! else const SizedBox(width: 40),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height);
}

/// Gradient back button komponenta
class GradientBackButton extends StatelessWidget {
  const GradientBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).glassBorder,
          width: 1,
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: Theme.of(context).colorScheme.onSurface,
          size: 18,
        ),
      ),
    );
  }
}
