import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// 🌟 SHIMMER LOADING WIDGETS
/// Profesionalni loading effects za sve liste i kartice
class ShimmerWidgets {
  /// 💳 Shimmer za putnik kartice
  static Widget putnikCardShimmer(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.surfaceVariant,
        highlightColor: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ime putnika
              Container(
                width: double.infinity,
                height: 18,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              // Adresa
              Container(
                width: 200,
                height: 14,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Polazak
                  Container(
                    width: 60,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  // Dugmići
                  Container(
                    width: 80,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 80,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 📊 Shimmer za statistike
  static Widget statistikaShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceVariant,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 📋 Shimmer za liste
  static Widget listItemShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceVariant,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        title: Container(
          height: 16,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Container(
          height: 12,
          width: 100,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  /// 🎯 Shimmer za cele liste putnika
  static Widget putnikListShimmer({int itemCount = 5}) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) => putnikCardShimmer(context),
    );
  }

  /// 💎 Custom shimmer wrapper
  static Widget shimmerWrapper({
    required BuildContext context,
    required Widget child,
    Color? baseColor,
    Color? highlightColor,
  }) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? Theme.of(context).colorScheme.surfaceVariant,
      highlightColor: highlightColor ?? Theme.of(context).colorScheme.surface,
      child: child,
    );
  }
}

/// 🔄 Shimmer Loading State Manager
class ShimmerState {
  static Widget buildShimmerOrContent({
    required bool isLoading,
    required Widget content,
    required Widget shimmer,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isLoading ? shimmer : content,
    );
  }
}





