import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class V3BlockingScreenWidget extends StatefulWidget {
  final String grad;
  final String vreme;
  final Future<void> Function() onStartTracking;

  const V3BlockingScreenWidget({
    super.key,
    required this.grad,
    required this.vreme,
    required this.onStartTracking,
  });

  @override
  State<V3BlockingScreenWidget> createState() => _V3BlockingScreenWidgetState();
}

class _V3BlockingScreenWidgetState extends State<V3BlockingScreenWidget> {
  bool _isStarting = false;

  Future<void> _handleStart() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    HapticFeedback.heavyImpact();
    try {
      await widget.onStartTracking();
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
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
                  'Vaš slot ${widget.grad} ${widget.vreme} počinje za 15 minuta',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: _isStarting ? null : _handleStart,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.disabled)
                          ? Colors.green.withValues(alpha: 0.5)
                          : Colors.green,
                    ),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 20,
                      ),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  child: _isStarting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'POKRENI TRACKING',
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
