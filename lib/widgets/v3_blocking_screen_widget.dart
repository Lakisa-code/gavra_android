import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class V3BlockingScreenWidget extends StatelessWidget {
  final String grad;
  final String vreme;
  final VoidCallback onStartTracking;

  const V3BlockingScreenWidget({
    super.key,
    required this.grad,
    required this.vreme,
    required this.onStartTracking,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 32),
                const Text(
                  'GPS TRACKING',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Vaš slot $grad $vreme počinje za 15 minuta',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    onStartTracking();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '🚀 POKRENI TRACKING',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Morate pokrenuti tracking da nastavite sa aplikacijom',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
