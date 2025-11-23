import 'package:flutter/widgets.dart';

/// Small responsive helpers used to scale text and layout across different
/// screen sizes and device pixel ratios.
class Responsive {
  /// Breakpoints in logical pixels (width)
  static const double small = 360; // phones
  static const double medium = 600; // large phones / small tablets
  static const double large = 800; // tablets

  static bool isSmallScreen(BuildContext context) => MediaQuery.of(context).size.width <= small;
  static bool isMediumScreen(BuildContext context) =>
      MediaQuery.of(context).size.width > small && MediaQuery.of(context).size.width <= medium;
  static bool isLargeScreen(BuildContext context) => MediaQuery.of(context).size.width > medium;

  /// Scale factor for fonts and spacing based on a baseline width (375: typical phone)
  static double _scaleFactor(BuildContext context, {double baseline = 375}) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    // Limit scaling between 0.8 and 1.3 to prevent extreme sizes
    final factor = (width / baseline).clamp(0.8, 1.3);
    // Respect user's textScaleFactor but avoid exploding sizes
    // Some SDKs deprecate MediaQuery.textScaleFactor; keep it for compatibility
    // ignore: deprecated_member_use
    final textScale = mq.textScaleFactor.clamp(0.8, 1.4);
    return factor * textScale;
  }

  /// Use for font sizes. Pass a base size (designed for baseline width) and this will return scaled size.
  static double fontSize(BuildContext context, double base) => base * _scaleFactor(context);

  /// Use for spacing / padding. Returns scaled size with stricter clamp to keep layout stable.
  static double spacing(BuildContext context, double base) {
    final mqFactor = _scaleFactor(context);
    // reduce the extremes for spacing
    final factor = mqFactor.clamp(0.9, 1.15);
    return base * factor;
  }

  /// A convenience helper to compute adaptive widths (fractional)
  static double adaptiveWidth(BuildContext context, double fraction) => MediaQuery.of(context).size.width * fraction;

  /// A convenience helper to compute adaptive heights (fractional)
  static double adaptiveHeight(BuildContext context, double fraction) => MediaQuery.of(context).size.height * fraction;
}
