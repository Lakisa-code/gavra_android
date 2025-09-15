import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar_letnji.dart';
import '../widgets/bottom_nav_bar_zimski.dart';

class SeasonalNavBarWrapper extends StatelessWidget {
  final List<String> sviPolasci;
  final String selectedGrad;
  final String selectedVreme;
  final Function(String grad, String vreme) onPolazakChanged;
  final Function(String grad, String vreme) getPutnikCount;

  const SeasonalNavBarWrapper({
    super.key,
    required this.sviPolasci,
    required this.selectedGrad,
    required this.selectedVreme,
    required this.onPolazakChanged,
    required this.getPutnikCount,
  });

  /// Određuje da li je trenutno letnji period
  /// Letnji period: 1. jul - 31. avgust
  /// Zimski period: 1. septembar - 30. jun
  bool _isLetniPeriod() {
    final now = DateTime.now();
    final month = now.month;

    // Letnji period: jul (7) i avgust (8)
    return month >= 7 && month <= 8;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLetniPeriod()) {
      return BottomNavBarLetnji(
        sviPolasci: sviPolasci,
        selectedGrad: selectedGrad,
        selectedVreme: selectedVreme,
        onPolazakChanged: onPolazakChanged,
        getPutnikCount: getPutnikCount,
      );
    } else {
      return BottomNavBarZimski(
        sviPolasci: sviPolasci,
        selectedGrad: selectedGrad,
        selectedVreme: selectedVreme,
        onPolazakChanged: onPolazakChanged,
        getPutnikCount: getPutnikCount,
      );
    }
  }
}
