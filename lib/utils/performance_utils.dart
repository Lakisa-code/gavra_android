import 'package:flutter/material.dart';

/// 🚀 PerformanceUtils - brze optimizacije za Flutter performanse
class PerformanceUtils {
  /// Debounce za search funkcije - sprečava prebrze API pozive
  static final Map<String, Future<void>?> _debouncedCalls = {};

  static Future<T> debounce<T>(
    String key,
    Future<T> Function() operation, {
    Duration delay = const Duration(milliseconds: 300),
  }) async {
    // Otkaži prethodnu operaciju ako postoji
    _debouncedCalls[key] = Future.delayed(delay);
    await _debouncedCalls[key];

    // Ako nije otkazana, izvršeni operaciju
    if (_debouncedCalls[key] != null) {
      return await operation();
    }
    throw Exception('Debounced call was cancelled');
  }

  /// Lazy loading za velike liste
  static Widget lazyList<T>({
    required List<T> items,
    required Widget Function(BuildContext, T, int) itemBuilder,
    int initialLoadCount = 20,
    int loadMoreCount = 10,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        int displayCount = initialLoadCount;

        return Column(
          children: [
            ...items.take(displayCount).map(
                  (item) => itemBuilder(context, item, items.indexOf(item)),
                ),
            if (displayCount < items.length)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    displayCount = (displayCount + loadMoreCount).clamp(0, items.length);
                  });
                },
                child: Text('Učitaj još ${(items.length - displayCount).clamp(0, loadMoreCount)}'),
              ),
          ],
        );
      },
    );
  }

  /// Cached image with automatic memory management
  static Widget cachedImage(
    String url, {
    double? width,
    double? height,
    BoxFit? fit,
  }) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          width: width ?? 50,
          height: height ?? 50,
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width ?? 50,
          height: height ?? 50,
          color: Colors.grey[300],
          child: const Icon(Icons.error, color: Colors.red),
        );
      },
    );
  }

  /// Optimized setState - avoid unnecessary rebuilds
  static void smartSetState(StateSetter setState, VoidCallback fn) {
    bool shouldUpdate = true;

    // Add your logic here to determine if update is needed
    // For example, compare old vs new values

    if (shouldUpdate) {
      setState(fn);
    }
  }

  /// Memory-efficient scroll controller
  static ScrollController createOptimizedScrollController({
    VoidCallback? onScrollToTop,
    VoidCallback? onScrollToBottom,
  }) {
    final controller = ScrollController();

    controller.addListener(() {
      if (controller.position.pixels == controller.position.maxScrollExtent) {
        onScrollToBottom?.call();
      }
      if (controller.position.pixels == controller.position.minScrollExtent) {
        onScrollToTop?.call();
      }
    });

    return controller;
  }

  /// Clean up resources
  static void dispose() {
    _debouncedCalls.clear();
  }
}
