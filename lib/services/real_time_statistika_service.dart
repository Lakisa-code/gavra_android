import 'dart:async';
import '../utils/logging.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/putnik.dart';
import '../models/mesecni_putnik_novi.dart';
import 'putnik_service.dart';
import 'mesecni_putnik_service_novi.dart';
import 'statistika_service.dart';
import 'realtime_service.dart';
import 'supabase_safe.dart';

// Use centralized logger via dlog directly

/// 🔄 CENTRALIZOVANI REAL-TIME STATISTIKA SERVIS
/// Rešava probleme sa duplikovanim stream-ovima i cache-om
class RealTimeStatistikaService {
  static RealTimeStatistikaService? _instance;
  static RealTimeStatistikaService get instance =>
      _instance ??= RealTimeStatistikaService._internal();

  RealTimeStatistikaService._internal();

  // 🎯 CENTRALIUZOVANI STREAM CACHE
  final Map<String, Stream> _streamCache = {};

  // 🔄 KOMBINOVANI STREAM za sve putnic (dnevne + mesečne)
  Stream<List<dynamic>>? _kombinovaniStream;

  /// 🔄 GLAVNI KOMBINOVANI STREAM - koristi se svugde
  Stream<List<dynamic>> get kombinovaniPutniciStream {
    if (_kombinovaniStream == null) {
      dlog('🆕 KREIRANJE NOVOG KOMBINOVANOG STREAM-A');

      _kombinovaniStream = CombineLatestStream.combine2(
        PutnikService().streamKombinovaniPutniciFiltered(),
        MesecniPutnikServiceNovi.streamAktivniMesecniPutnici(),
        (List<Putnik> putnici, List<MesecniPutnik> mesecni) {
          return [putnici, mesecni];
        },
      ).shareReplay(maxSize: 1); // 🔧 SHARE REPLAY za cache
    }

    return _kombinovaniStream!;
  }

  /// 💰 REAL-TIME PAZAR STREAM ZA SVE VOZAČE
  Stream<Map<String, double>> getPazarStream({
    DateTime? from,
    DateTime? to,
  }) {
    final now = DateTime.now();
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    final cacheKey =
        'pazar_${fromDate.millisecondsSinceEpoch}_${toDate.millisecondsSinceEpoch}';

    if (!_streamCache.containsKey(cacheKey)) {
      dlog('🆕 KREIRANJE PAZAR STREAM-A: $cacheKey');

      _streamCache[cacheKey] = kombinovaniPutniciStream
          .map((data) {
            final putnici = data[0] as List<Putnik>;
            final mesecniPutnici = data[1] as List<MesecniPutnik>;

            return StatistikaService.calculateKombinovanPazarSync(
              putnici,
              mesecniPutnici,
              fromDate,
              toDate,
            );
          })
          .distinct() // 🚫 Eliminiši duplikate
          .shareReplay(maxSize: 1);
    }

    return _streamCache[cacheKey]! as Stream<Map<String, double>>;
  }

  /// 📊 REAL-TIME DETALJNE STATISTIKE STREAM
  Stream<Map<String, Map<String, dynamic>>> getDetaljneStatistikeStream({
    DateTime? from,
    DateTime? to,
  }) {
    final now = DateTime.now();
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    final cacheKey =
        'detaljne_${fromDate.millisecondsSinceEpoch}_${toDate.millisecondsSinceEpoch}';

    if (!_streamCache.containsKey(cacheKey)) {
      dlog('🆕 KREIRANJE DETALJNE STATISTIKE STREAM-A: $cacheKey');

      _streamCache[cacheKey] = kombinovaniPutniciStream
          .map((data) {
            final putnici = data[0] as List<Putnik>;
            final mesecniPutnici = data[1] as List<MesecniPutnik>;

            return StatistikaService.calculateDetaljneStatistikeSinhronno(
              putnici,
              mesecniPutnici,
              fromDate,
              toDate,
            );
          })
          .distinct() // 🚫 Eliminiši duplikate
          .shareReplay(maxSize: 1);
    }

    return _streamCache[cacheKey]! as Stream<Map<String, Map<String, dynamic>>>;
  }

  /// 📊 REAL-TIME STATISTIKE ZA ODREĐENOG PUTNIKA
  Stream<Map<String, dynamic>> getPutnikStatistikeStream(String putnikId) {
    final cacheKey = 'putnik_$putnikId';

    if (!_streamCache.containsKey(cacheKey)) {
      dlog('🆕 KREIRANJE PUTNIK STATISTIKE STREAM-A: $putnikId');

      // Kombinuj centralizovani putovanja_istorija stream i filtriraj lokalno po putnikId
      _streamCache[cacheKey] = RealtimeService.instance
          .tableStream('putovanja_istorija')
          .map((data) {
            final List<dynamic> items =
                data is List ? List<dynamic>.from(data) : <dynamic>[];
            final filtered = items.where((row) {
              try {
                return row['putnik_id']?.toString() == putnikId.toString();
              } catch (_) {
                return false;
              }
            }).toList();
            return filtered;
          })
          .asyncMap((_) async {
            // Recompute statistics when relevant changes arrive
            return await _calculatePutnikStatistike(putnikId);
          })
          .distinct()
          .shareReplay(maxSize: 1);
    }

    return _streamCache[cacheKey]! as Stream<Map<String, dynamic>>;
  }

  /// 🧹 OČISTI CACHE
  void clearCache() {
    dlog('🧹 BRISANJE REAL-TIME STATISTIKA CACHE-A');
    _streamCache.clear();
    _kombinovaniStream = null;
  }

  /// 📊 PRIVATNA METODA - Računaj statistike za putnika
  Future<Map<String, dynamic>> _calculatePutnikStatistike(
      String putnikId) async {
    try {
      // Dohvati sva putovanja za putnika (safely)
      final response = await SupabaseSafe.run(
          () => Supabase.instance.client
              .from('putovanja_istorija')
              .select()
              .eq('putnik_id', putnikId)
              .order('created_at', ascending: false),
          fallback: <dynamic>[]);

      final putovanja = response is List ? response : <dynamic>[];

      // Osnovne statistike
      int ukupnoPutovanja = 0;
      int otkazi = 0;
      double ukupanPrihod = 0;

      for (final putovanje in putovanja) {
        if (putovanje['status'] == 'pokupljen') {
          ukupnoPutovanja++;
          ukupanPrihod += (putovanje['cena'] ?? 0.0);
        } else if (putovanje['status'] == 'otkazan') {
          otkazi++;
        }
      }

      final ukupno = ukupnoPutovanja + otkazi;
      final uspesnost =
          ukupno > 0 ? ((ukupnoPutovanja / ukupno) * 100).round() : 0;

      return {
        'ukupnoPutovanja': ukupnoPutovanja,
        'otkazi': otkazi,
        'ukupanPrihod': ukupanPrihod,
        'uspesnost': uspesnost,
        'poslednje':
            putovanja.isNotEmpty ? putovanja.first['created_at'] : null,
      };
    } catch (e) {
      dlog('❌ Greška pri računanju statistika za putnika $putnikId: $e');
      return {
        'ukupnoPutovanja': 0,
        'otkazi': 0,
        'ukupanPrihod': 0.0,
        'uspesnost': 0,
        'poslednje': null,
      };
    }
  }
}
