import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Picture-in-Picture (PiP) service za Gavra app
/// Omogućava mali prozor gore desno dok korisnik koristi druge aplikacije
///
/// Zahteva Android 8.0+ (API 26+)
class PipService {
  static const _channel = MethodChannel('com.gavra013.gavra_android/pip');

  static final PipService _instance = PipService._internal();
  factory PipService() => _instance;
  PipService._internal() {
    _setupCallbackHandler();
  }

  /// Callback kada se PiP mode promeni
  final ValueNotifier<bool> isPipActive = ValueNotifier(false);

  void _setupCallbackHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipChanged') {
        final isInPip = call.arguments as bool;
        isPipActive.value = isInPip;
      }
    });
  }

  /// Proveri da li uređaj podržava PiP (Android 8.0+)
  Future<bool> isPipSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('isPipSupported');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Ulazak u PiP mode - mali prozor gore desno
  /// Vraća true ako je uspešno ušao u PiP
  Future<bool> enterPip() async {
    try {
      final result = await _channel.invokeMethod<bool>('enterPip');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Proveri da li je trenutno u PiP modu
  Future<bool> checkIsPipActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isPipActive');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Helper metoda - uđi u PiP sa validacijom
  Future<PipResult> tryEnterPip() async {
    // Proveri podršku
    final supported = await isPipSupported();
    if (!supported) {
      return PipResult(
        success: false,
        message: 'PiP nije podržan na ovom uređaju (potreban Android 8.0+)',
      );
    }

    // Pokušaj ulazak
    final entered = await enterPip();
    if (entered) {
      return PipResult(
        success: true,
        message: 'Uspešno ušao u PiP mode',
      );
    } else {
      return PipResult(
        success: false,
        message: 'Nije moguće ući u PiP mode. Proverite da li je PiP omogućen u podešavanjima.',
      );
    }
  }
}

class PipResult {
  final bool success;
  final String message;

  PipResult({required this.success, required this.message});
}
