import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/seat_request.dart';
import '../utils/grad_adresa_validator.dart';
import 'realtime/realtime_manager.dart';

/// Servis za upravljanje aktivnim zahtevima za sedišta (seat_requests tabela)
class SeatRequestService {
  static SupabaseClient get _supabase => supabase;

  /// ✅ UNIFIKOVANA ULAZNA TAČKA — koriste je svi akteri (putnik, admin, vozač)
  ///
  /// Model: dan + grad + zeljeno_vreme → upsert u seat_requests
  ///
  /// - [isAdmin] = true → status='confirmed', dodeljeno_vreme=vreme odmah (vozač/admin ručno dodaje)
  /// - [isAdmin] = false → status='pending' (putnik šalje zahtev, backend obrađuje)
  ///
  /// Nema datuma, nema sedmice, nema predviđanja.
  static Future<void> submitPolazak({
    required String putnikId,
    required String dan,
    required String grad,
    required String vreme,
    int brojMesta = 1,
    bool isAdmin = false,
    String? customAdresaId,
  }) async {
    try {
      final gradKey = GradAdresaValidator.normalizeGrad(grad);
      final normVreme = GradAdresaValidator.normalizeTime(vreme);
      final danKey = dan.toLowerCase();
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final status = isAdmin ? 'confirmed' : 'pending';

      // Upsert po (putnik_id, dan, grad, zeljeno_vreme) — svaka kombinacija je jedinstvena
      final existing = await _supabase
          .from('seat_requests')
          .select('id')
          .eq('putnik_id', putnikId)
          .eq('grad', gradKey)
          .eq('dan', danKey)
          .eq('zeljeno_vreme', '$normVreme:00')
          .maybeSingle();

      if (existing != null) {
        await _supabase.from('seat_requests').update({
          'status': status,
          'broj_mesta': brojMesta,
          if (customAdresaId != null) 'custom_adresa_id': customAdresaId,
          if (isAdmin) 'dodeljeno_vreme': '$normVreme:00',
          'updated_at': nowStr,
        }).eq('id', existing['id']);
        debugPrint('✅ [SeatRequestService] submitPolazak UPDATE $gradKey $normVreme $danKey (isAdmin=$isAdmin)');
      } else {
        await _supabase.from('seat_requests').insert({
          'putnik_id': putnikId,
          'grad': gradKey,
          'dan': danKey,
          'zeljeno_vreme': '$normVreme:00',
          if (isAdmin) 'dodeljeno_vreme': '$normVreme:00',
          'status': status,
          'broj_mesta': brojMesta,
          if (customAdresaId != null) 'custom_adresa_id': customAdresaId,
          'created_at': nowStr,
          'updated_at': nowStr,
        });
        debugPrint('✅ [SeatRequestService] submitPolazak INSERT $gradKey $normVreme $danKey (isAdmin=$isAdmin)');
      }
    } catch (e) {
      debugPrint('❌ [SeatRequestService] submitPolazak error: $e');
      rethrow;
    }
  }

  /// Odobrava zahtev — kopira zeljeno_vreme u dodeljeno_vreme
  static Future<bool> approveRequest(String id, {String? approvedBy}) async {
    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();

      // 1. Dohvati zeljeno_vreme za ovaj zahtev
      final row = await _supabase.from('seat_requests').select('zeljeno_vreme').eq('id', id).single();

      final zeljenoVreme = row['zeljeno_vreme'];

      // 2. Odobri i upisi dodeljeno_vreme = zeljeno_vreme
      await _supabase.from('seat_requests').update({
        'status': 'approved',
        'dodeljeno_vreme': zeljenoVreme, // kopira zeljeno_vreme u dodeljeno_vreme
        'updated_at': nowStr,
        'processed_at': nowStr,
        if (approvedBy != null) 'approved_by': approvedBy,
      }).eq('id', id);

      return true;
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error approving request: $e');
      return false;
    }
  }

  /// Odbija zahtev
  static Future<bool> rejectRequest(String id, {String? rejectedBy}) async {
    try {
      await _supabase.from('seat_requests').update({
        'status': 'rejected',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'processed_at': DateTime.now().toUtc().toIso8601String(),
        if (rejectedBy != null) 'cancelled_by': rejectedBy,
      }).eq('id', id);

      return true;
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error rejecting request: $e');
      return false;
    }
  }

  /// Stream za zahteve koji čekaju ručnu obradu admina (samo tip=dnevni, status=pending)
  /// Koristi select+JOIN sa registrovani_putnici da bi dobio putnik_ime i broj_telefona
  static Stream<List<SeatRequest>> streamManualRequests() {
    final controller = StreamController<List<SeatRequest>>.broadcast();

    Future<void> fetch() async {
      try {
        final data = await _supabase
            .from('seat_requests')
            .select('*, registrovani_putnici(putnik_ime, broj_telefona)')
            .eq('status', 'pending')
            .eq('tip_putnika', 'dnevni')
            .order('created_at', ascending: false);
        if (!controller.isClosed) {
          controller.add(data.map((json) => SeatRequest.fromJson(json)).toList());
        }
      } catch (e) {
        debugPrint('❌ [SeatRequestService] streamManualRequests fetch error: $e');
      }
    }

    fetch();
    final sub = RealtimeManager.instance.subscribe('seat_requests').listen((_) => fetch());
    controller.onCancel = () {
      sub.cancel();
      RealtimeManager.instance.unsubscribe('seat_requests');
    };

    return controller.stream;
  }

  /// 📋 Stream za SVE zahteve — audit/log ekran za admina
  /// Podržava filtere: [statusFilter] lista statusa, [gradFilter] 'BC'/'VS'/null, [limit] broj zapisa
  static Stream<List<SeatRequest>> streamSviZahtevi({
    List<String>? statusFilter,
    String? gradFilter,
    int limit = 200,
  }) {
    final controller = StreamController<List<SeatRequest>>.broadcast();

    Future<void> fetch() async {
      try {
        var query = _supabase.from('seat_requests').select('*, registrovani_putnici(putnik_ime, broj_telefona)');

        if (statusFilter != null && statusFilter.isNotEmpty) {
          query = query.inFilter('status', statusFilter);
        }
        if (gradFilter != null) {
          query = query.eq('grad', gradFilter);
        }

        final data = await query.order('created_at', ascending: false).limit(limit);

        if (!controller.isClosed) {
          controller.add(data.map((json) => SeatRequest.fromJson(json)).toList());
        }
      } catch (e) {
        debugPrint('❌ [SeatRequestService] streamSviZahtevi fetch error: $e');
      }
    }

    fetch();
    final sub = RealtimeManager.instance.subscribe('seat_requests').listen((_) => fetch());
    controller.onCancel = () {
      sub.cancel();
      RealtimeManager.instance.unsubscribe('seat_requests');
    };

    return controller.stream;
  }

  /// 🔢 Stream za broj zahteva koji čekaju ručnu obradu (za bedž na Home ekranu - samo dnevni)
  static Stream<int> streamManualRequestCount() {
    final controller = StreamController<int>.broadcast();

    Future<void> fetch() async {
      try {
        final data =
            await _supabase.from('seat_requests').select('id').eq('status', 'pending').eq('tip_putnika', 'dnevni');
        if (!controller.isClosed) {
          controller.add((data as List).length);
        }
      } catch (e) {
        debugPrint('❌ [SeatRequestService] streamManualRequestCount fetch error: $e');
      }
    }

    fetch();
    final sub = RealtimeManager.instance.subscribe('seat_requests').listen((_) => fetch());
    controller.onCancel = () {
      sub.cancel();
      RealtimeManager.instance.unsubscribe('seat_requests');
    };

    return controller.stream;
  }

  /// 🤖 DIGITALNI DISPEČER — replicira dispecer_cron_obrada + obradi_seat_request SQL logiku
  static Future<int> triggerDigitalDispecer() async {
    try {
      // 1. Dohvati sve pending zahteve (osim dnevnih putnika)
      final pendingRows = await _supabase
          .from('seat_requests')
          .select('id, grad, dan, updated_at, zeljeno_vreme, broj_mesta, putnik_id, created_at, '
              'registrovani_putnici!inner(tip)')
          .eq('status', 'pending')
          .neq('registrovani_putnici.tip', 'dnevni');

      if (pendingRows.isEmpty) return 0;

      // 2. Dohvati kapacitete svih polazaka odjednom
      final kapacitetRows =
          await _supabase.from('kapacitet_polazaka').select('grad, vreme, max_mesta').eq('aktivan', true);

      final Map<String, int> kapacitetMap = {};
      for (final k in kapacitetRows) {
        final key = '${k['grad']}_${k['vreme']}';
        kapacitetMap[key] = (k['max_mesta'] as num).toInt();
      }

      // 3. Dohvati zauzetost za sve relevantne dan+grad+vreme kombinacije
      final dani = pendingRows.map((r) => r['dan'].toString()).toSet().toList();
      final zauzetoRows = await _supabase
          .from('seat_requests')
          .select('grad, zeljeno_vreme, dan, broj_mesta')
          .inFilter('dan', dani)
          .inFilter('status', ['pending', 'manual', 'approved', 'confirmed']);

      // Grupišemo zauzetost po "GRAD_vreme_dan"
      final Map<String, int> zauzetoMap = {};
      for (final z in zauzetoRows) {
        final key = '${z['grad']}_${z['zeljeno_vreme']}_${z['dan']}';
        zauzetoMap[key] = (zauzetoMap[key] ?? 0) + ((z['broj_mesta'] as num?)?.toInt() ?? 1);
      }

      int processedCount = 0;
      final now = DateTime.now().toUtc();

      for (final req in pendingRows) {
        final String reqId = req['id'].toString();
        final String grad = req['grad'].toString().toUpperCase();
        final String dan = req['dan'].toString().toLowerCase();
        final String tip = (req['registrovani_putnici']?['tip'] ?? '').toString().toLowerCase();
        final DateTime updatedAt = DateTime.parse(req['updated_at'].toString()).toUtc();
        final String createdAtStr = req['created_at']?.toString() ?? req['updated_at'].toString();
        final DateTime createdAt = DateTime.parse(createdAtStr).toUtc();
        final String zeljeno = req['zeljeno_vreme'].toString();
        final int brojMesta = (req['broj_mesta'] as num?)?.toInt() ?? 1;

        // --- get_cekanje_pravilo logika ---
        int minutaCekanja;
        bool proveraKapaciteta;
        if (grad == 'BC') {
          if (tip == 'ucenik' && createdAt.hour < 16) {
            minutaCekanja = 5;
            proveraKapaciteta = false;
          } else if (tip == 'radnik') {
            minutaCekanja = 5;
            proveraKapaciteta = true;
          } else if (tip == 'ucenik' && createdAt.hour >= 16) {
            minutaCekanja = 0;
            proveraKapaciteta = true;
          } else if (tip == 'posiljka') {
            minutaCekanja = 10;
            proveraKapaciteta = false;
          } else {
            minutaCekanja = 5;
            proveraKapaciteta = true;
          }
        } else if (grad == 'VS') {
          if (tip == 'posiljka') {
            minutaCekanja = 10;
            proveraKapaciteta = false;
          } else {
            minutaCekanja = 10;
            proveraKapaciteta = true;
          }
        } else {
          minutaCekanja = 5;
          proveraKapaciteta = true;
        }

        // --- dispecer_cron_obrada uslov za obradu ---
        final minutesWaiting = now.difference(updatedAt).inSeconds / 60.0;
        final bcUcenikNocni = tip == 'ucenik' && grad == 'BC' && createdAt.hour >= 16 && now.hour >= 20;
        final regularTimeout =
            minutesWaiting >= minutaCekanja && !(tip == 'ucenik' && grad == 'BC' && createdAt.hour >= 16);

        if (!bcUcenikNocni && !regularTimeout) continue;

        // --- obradi_seat_request logika ---
        bool imaMesta;
        if (tip == 'ucenik' && grad == 'BC' && createdAt.hour < 16) {
          imaMesta = true; // garantovano mesto
        } else if (!proveraKapaciteta) {
          imaMesta = true;
        } else {
          final kapKey = '${grad}_$zeljeno';
          final maxMesta = kapacitetMap[kapKey] ?? 8;
          final zauzeto = zauzetoMap['${grad}_${zeljeno}_$dan'] ?? 0;
          imaMesta = (maxMesta - zauzeto) >= brojMesta;
        }

        String noviStatus;
        String? alt1;
        String? alt2;

        if (imaMesta) {
          noviStatus = 'approved';
        } else {
          noviStatus = 'rejected';
          // Pronađi alternativna vremena
          final svaVremena = kapacitetRows
              .where((k) => k['grad'].toString().toUpperCase() == grad)
              .map((k) => k['vreme'].toString())
              .toList()
            ..sort();

          for (final v in svaVremena.reversed) {
            if (v.compareTo(zeljeno) < 0) {
              final maxM = kapacitetMap['${grad}_$v'] ?? 8;
              final zau = zauzetoMap['${grad}_${v}_$dan'] ?? 0;
              if ((maxM - zau) >= brojMesta) {
                alt1 = v;
                break;
              }
            }
          }
          for (final v in svaVremena) {
            if (v.compareTo(zeljeno) > 0) {
              final maxM = kapacitetMap['${grad}_$v'] ?? 8;
              final zau = zauzetoMap['${grad}_${v}_$dan'] ?? 0;
              if ((maxM - zau) >= brojMesta) {
                alt2 = v;
                break;
              }
            }
          }
        }

        final nowStr = now.toIso8601String();
        await _supabase.from('seat_requests').update({
          'status': noviStatus,
          'processed_at': nowStr,
          'updated_at': nowStr,
          if (noviStatus == 'approved') 'dodeljeno_vreme': zeljeno,
          if (alt1 != null) 'alternative_vreme_1': alt1,
          if (alt2 != null) 'alternative_vreme_2': alt2,
        }).eq('id', reqId);

        debugPrint('🤖 [Dispecer] $reqId → $noviStatus (tip=$tip, grad=$grad, dan=$dan)');
        processedCount++;
      }

      return processedCount;
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error u digitalnom dispečeru: $e');
      return 0;
    }
  }

  /// 🎫 Prihvata alternativni termin - ODMAH ODOBRAVA
  static Future<bool> acceptAlternative({
    String? requestId,
    required String putnikId,
    required String novoVreme,
    required String grad,
    required String dan,
  }) async {
    try {
      final gradKey = GradAdresaValidator.normalizeGrad(grad);
      final danKey = dan.toLowerCase();
      final nowStr = DateTime.now().toUtc().toIso8601String();

      // Atomski UPDATE — direktno postavi novo vreme bez međukoraka 'cancelled'
      if (requestId != null && requestId.isNotEmpty) {
        await _supabase.from('seat_requests').update({
          'zeljeno_vreme': novoVreme, // cekaonica → premestamo na novi termin
          'dodeljeno_vreme': novoVreme, // stvarni termin putovanja → novi termin
          'status': 'approved',
          'processed_at': nowStr,
          'updated_at': nowStr,
        }).eq('id', requestId);
      } else {
        // Ako nema requestId, kreiraj novi zahtev (fallback)
        await _supabase.from('seat_requests').insert({
          'putnik_id': putnikId,
          'grad': gradKey,
          'dan': danKey,
          'zeljeno_vreme': novoVreme, // cekaonica
          'dodeljeno_vreme': novoVreme, // stvarni termin putovanja
          'status': 'approved',
          'processed_at': nowStr,
        });
      }
      return true;
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error accepting alternative: $e');
      return false;
    }
  }
}
