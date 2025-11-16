import 'dart:async';

import 'package:flutter/material.dart';

import '../services/performance_optimizer_service.dart';

/// 🚀 WIDGET PERFORMANCE MIXIN
/// Automatski prati performanse widget-a i optimizuje rebuild-ove
mixin WidgetPerformanceMixin<T extends StatefulWidget> on State<T> {
  late Stopwatch _buildStopwatch;
  late String _widgetName;
  int _buildCount = 0;
  DateTime? _lastBuildTime;

  @override
  void initState() {
    super.initState();
    _widgetName = T.toString();
    _buildStopwatch = Stopwatch();
  }

  @override
  Widget build(BuildContext context) {
    _buildStopwatch.reset();
    _buildStopwatch.start();
    _buildCount++;
    _lastBuildTime = DateTime.now();

    final widget = buildOptimized(context);

    _buildStopwatch.stop();

    // Track performance
    PerformanceOptimizerService().trackOperation(
      'widget_build_$_widgetName',
      _buildStopwatch.elapsed,
    );

    // Batch UI update tracking
    PerformanceOptimizerService.batchUIUpdate(
      _widgetName,
      () => _logBuildStats(),
    );

    return widget;
  }

  /// Override this instead of build()
  Widget buildOptimized(BuildContext context);

  void _logBuildStats() {
    if (_buildCount % 10 == 0) {
      // Log every 10 builds
      // Performance tracking without debug prints
    }
  }

  /// Get widget performance stats
  Map<String, dynamic> getPerformanceStats() {
    return {
      'widget_name': _widgetName,
      'build_count': _buildCount,
      'last_build_time': _lastBuildTime?.toIso8601String(),
      'average_build_time': _buildStopwatch.elapsed.inMicroseconds,
    };
  }

  @override
  void dispose() {
    _buildStopwatch.stop();
    super.dispose();
  }
}

/// 🚀 OPTIMIZED STATEFUL WIDGET BASE CLASS
abstract class OptimizedStatefulWidget extends StatefulWidget {
  const OptimizedStatefulWidget({super.key});
}

/// 🚀 OPTIMIZED STATE BASE CLASS
abstract class OptimizedState<T extends OptimizedStatefulWidget>
    extends State<T> with WidgetPerformanceMixin<T> {
  // Cache za expensive operations
  final Map<String, dynamic> _cache = {};

  /// Cache expensive computations
  R cached<R>(String key, R Function() computation) {
    if (_cache.containsKey(key)) {
      return _cache[key] as R;
    }

    final result = computation();
    _cache[key] = result;
    return result;
  }

  /// Clear cache when data changes
  void clearCache([String? specificKey]) {
    if (specificKey != null) {
      _cache.remove(specificKey);
    } else {
      _cache.clear();
    }
  }

  /// Optimized setState that debounces rapid calls
  static final Map<int, Timer?> _setStateTimers = {};

  void optimizedSetState(VoidCallback fn,
      {Duration delay = const Duration(milliseconds: 16)}) {
    final hash = hashCode;

    _setStateTimers[hash]?.cancel();
    _setStateTimers[hash] = Timer(delay, () {
      if (mounted) {
        setState(fn);
      }
      _setStateTimers.remove(hash);
    });
  }

  @override
  void dispose() {
    final hash = hashCode;
    _setStateTimers[hash]?.cancel();
    _setStateTimers.remove(hash);
    _cache.clear();
    super.dispose();
  }
}

/// 🚀 CONST WIDGET HELPERS
/// Helper klase za lakše kreiranje const widget-ova

class ConstText extends StatelessWidget {
  const ConstText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: style,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}

class ConstPadding extends StatelessWidget {
  const ConstPadding({
    super.key,
    required this.padding,
    required this.child,
  });

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: child,
    );
  }
}

class ConstContainer extends StatelessWidget {
  const ConstContainer({
    super.key,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.decoration,
    this.child,
  });

  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Decoration? decoration;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      decoration: decoration,
      child: child,
    );
  }
}

/// 🚀 PERFORMANCE AWARE LIST VIEW
class OptimizedListView extends StatelessWidget {
  const OptimizedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.scrollDirection = Axis.vertical,
    this.shrinkWrap = false,
    this.physics,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Axis scrollDirection;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Track list item builds
        final stopwatch = Stopwatch()..start();
        final widget = itemBuilder(context, index);
        stopwatch.stop();

        PerformanceOptimizerService().trackOperation(
          'listview_item_build',
          stopwatch.elapsed,
        );

        return widget;
      },
      scrollDirection: scrollDirection,
      shrinkWrap: shrinkWrap,
      physics: physics,
      // Performance optimizations
      cacheExtent: 500, // Cache more items for smooth scrolling
      addAutomaticKeepAlives: false, // Reduce memory usage
    );
  }
}

/// 🚀 DEBOUNCED TEXT FIELD
class DebouncedTextField extends StatefulWidget {
  const DebouncedTextField({
    super.key,
    required this.onChanged,
    this.controller,
    this.decoration,
    this.debounceDelay = const Duration(milliseconds: 300),
  });

  final void Function(String) onChanged;
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final Duration debounceDelay;

  @override
  State<DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<DebouncedTextField> {
  Timer? _debounceTimer;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDelay, () {
      widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: widget.decoration,
      onChanged: _onTextChanged,
    );
  }
}
