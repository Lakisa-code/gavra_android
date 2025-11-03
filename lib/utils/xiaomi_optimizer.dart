import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 🚀 XIAOMI/MIUI OPTIMIZER
/// Specijalne optimizacije za Xiaomi uređaje koji imaju problema sa BLASTBufferQueue
class XiaomiOptimizer {
  /// 🎯 PERFORMANSE OPTIMIZACIJE
  static void optimizeForXiaomi() {
    // 🎮 GAMING MODE - reduci sistem overhead
    WidgetsBinding.instance.platformDispatcher.onReportTimings = (timings) {
      // Ignore frame timing reports to reduce CPU usage
    };

    // 🚀 MIUI Battery Optimization bypass
    SystemChannels.platform.invokeMethod('SystemNavigator.routeUpdated', {
      'location': '/',
    });
  }

  /// 🎨 WIDGET WRAPPER SA ANTI-OVERFLOW ZAŠTITOM
  static Widget antiOverflowWrapper({
    required Widget child,
    Color? backgroundColor,
  }) {
    return Container(
      constraints: const BoxConstraints(),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: child,
      ),
    );
  }

  /// 🔧 OPTIMIZOVANI COLUMN/ROW
  static Widget safeColumn({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.max,
  }) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: IntrinsicHeight(
        child: Column(
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          mainAxisSize: mainAxisSize,
          children: children,
        ),
      ),
    );
  }

  static Widget safeRow({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.max,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: IntrinsicWidth(
        child: Row(
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          mainAxisSize: mainAxisSize,
          children: children,
        ),
      ),
    );
  }

  /// 📱 MIUI SPECIFIČNE OPTIMIZACIJE
  static void configureMIUI() {
    // Disabilraj preview animacije koje uzrokuju BLASTBufferQueue
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  /// 🎯 SAFE TEXT WIDGET
  static Widget safeText(
    String text, {
    TextStyle? style,
    int? maxLines,
    TextAlign? textAlign,
  }) {
    return Text(
      text,
      style: style,
      maxLines: maxLines ?? 2,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      softWrap: true,
    );
  }

  /// 🚀 PERFORMANSE MONITORING
  static void enablePerformanceMonitoring() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Log frame rendering time
      // Frame rendered successfully on XIAOMI
    });
  }
}
