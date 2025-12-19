import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// 🗺️ OPENROUTESERVICE - Za realtime ETA
/// Koristi OpenRouteService Directions API za izračunavanje ETA tokom vožnje
/// API Key se čita iz environment varijable
///
/// Limit: 2000 zahteva/dan, 40/min
class OpenRouteService {
  OpenRouteService._();

  static const String _baseUrl = 'https://api.openrouteservice.org/v2/directions/driving-car';

  // API key - hardkodiran jer je besplatan i nema sigurnosni rizik
  // Ako treba promeniti, promeni ovde
  static const String _apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjAyNjhjZTg0YzQ5ZTRjMGE5YmJmNmI2NmNmM2IwOTIwIiwiaCI6Im11cm11cjY0In0=';

  /// 🆕 REALTIME ETA: Koristi Directions API za brzo osvežavanje ETA tokom vožnje
  /// Poziva se periodično (svakih 2 min) dok vozač vozi
  static Future<RealtimeEtaResult> getRealtimeEta({
    required Position currentPosition,
    required List<String> putnikImena,
    required Map<String, Position> putnikCoordinates,
  }) async {
    if (putnikImena.isEmpty) {
      return RealtimeEtaResult.failure('Nema putnika');
    }

    try {
      // Pripremi koordinate: vozač -> putnici u redosledu
      // OpenRouteService POST format: [[lon, lat], [lon, lat], ...]
      final coordinates = <List<double>>[];
      coordinates.add([currentPosition.longitude, currentPosition.latitude]);

      final validPutnici = <String>[];
      for (final ime in putnikImena) {
        final pos = putnikCoordinates[ime];
        if (pos != null) {
          coordinates.add([pos.longitude, pos.latitude]);
          validPutnici.add(ime);
        }
      }

      if (validPutnici.isEmpty) {
        return RealtimeEtaResult.failure('Nema putnika sa koordinatama');
      }

      // POST request sa JSON body
      final body = json.encode({'coordinates': coordinates});

      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': _apiKey,
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return RealtimeEtaResult.failure('ORS error: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      // Parsiraj GeoJSON response
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        return RealtimeEtaResult.failure('Nema rute');
      }

      final segments = routes[0]['segments'] as List?;
      if (segments == null || segments.isEmpty) {
        return RealtimeEtaResult.failure('Nema segmenata');
      }

      // Izračunaj kumulativni ETA za svakog putnika
      final putniciEta = <String, int>{};
      double cumulativeSec = 0;

      for (int i = 0; i < segments.length && i < validPutnici.length; i++) {
        final segment = segments[i] as Map<String, dynamic>;
        final duration = (segment['duration'] as num?)?.toDouble() ?? 0;
        cumulativeSec += duration;
        putniciEta[validPutnici[i]] = (cumulativeSec / 60).round();
      }

      return RealtimeEtaResult.success(putniciEta);
    } catch (e) {
      return RealtimeEtaResult.failure('Greška: $e');
    }
  }
}

/// Rezultat realtime ETA poziva
class RealtimeEtaResult {
  final bool success;
  final Map<String, int>? putniciEta; // ime -> ETA u minutama
  final String? error;

  RealtimeEtaResult._({
    required this.success,
    this.putniciEta,
    this.error,
  });

  factory RealtimeEtaResult.success(Map<String, int> eta) {
    return RealtimeEtaResult._(success: true, putniciEta: eta);
  }

  factory RealtimeEtaResult.failure(String error) {
    return RealtimeEtaResult._(success: false, error: error);
  }
}
