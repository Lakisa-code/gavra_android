import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Konstante za background servis
const String _kVozacId = 'vozac_id';
const String _kActionStop = 'stop';
const Duration _kInterval = Duration(seconds: 30);

/// Globalni mutable state za background isolate — Dart dozvoljava top-level promenljive u entry-point fajlu.
String? _bgVozacId;
Timer? _bgTimer;
bool _bgInFlight = false;

/// Top-level callback za flutter_background_service.
/// Pokreće se u posebnom isolate-u i šalje GPS lokaciju svakih 30 sekundi.
@pragma('vm:entry-point')
Future<void> onBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Učitaj .env i inicijalizuj Supabase u ovom isolate-u
  try {
    await dotenv.load(fileName: '.env');
    final url = dotenv.maybeGet('SUPABASE_URL')?.trim() ?? '';
    final anonKey = dotenv.maybeGet('SUPABASE_ANON_KEY')?.trim() ?? '';
    if (url.isNotEmpty && anonKey.isNotEmpty) {
      await Supabase.initialize(url: url, anonKey: anonKey);
    }
  } catch (e) {
    debugPrint('[BG] Supabase init error: $e');
  }

  service.on(_kActionStop).listen((event) {
    _bgTimer?.cancel();
    _bgTimer = null;
    _bgVozacId = null;
    service.stopSelf();
  });

  // Glavni isolate šalje vozac_id preko invoke
  service.on('set_vozac_id').listen((event) {
    final id = (event?[_kVozacId] as String?)?.trim();
    if (id != null && id.isNotEmpty) {
      _bgVozacId = id;
      _bgStartTimer();
    }
  });
}

void _bgStartTimer() {
  _bgTimer?.cancel();
  _bgTimer = Timer.periodic(_kInterval, (_) {
    unawaited(_bgSendLocation());
  });
  // Prvo slanje odmah
  unawaited(_bgSendLocation());
}

Future<void> _bgSendLocation() async {
  final vozacId = _bgVozacId;
  if (vozacId == null || vozacId.isEmpty || _bgInFlight) return;

  final client = Supabase.instance.client;
  if (client.auth.currentSession == null && client.auth.currentUser == null) {
    return;
  }

  _bgInFlight = true;
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[BG] GPS isključen');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('[BG] Dozvola za lokaciju odbijena');
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );

    await client.functions.invoke(
      'v3-compute-eta',
      body: <String, dynamic>{
        'vozac_id': vozacId,
        'lat': position.latitude,
        'lng': position.longitude,
      },
    );
    debugPrint('[BG] Lokacija poslata: ${position.latitude}, ${position.longitude}');
  } catch (e) {
    debugPrint('[BG] Greška pri slanju lokacije: $e');
  } finally {
    _bgInFlight = false;
  }
}
