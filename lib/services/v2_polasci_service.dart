import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/v2_polazak.dart';
import '../utils/v2_grad_adresa_validator.dart';
import 'realtime/v2_master_realtime_manager.dart';

/// Servis za upravljanje aktivnim zahtevima za sedišta (v2_polasci tabela)
class V2PolasciService {
  static SupabaseClient get _supabase => supabase;

  /// ✅ UNIFIKOVANA ULAZNA TAČKA — koriste je svi akteri (V2Putnik, admin, vozač)
  ///
  /// Model: dan + grad + zeljeno_vreme → upsert u v2_polasci
  ///
  /// - [isAdmin] = true → status='odobreno', dodeljeno_vreme=vreme odmah (vozač/admin ručno dodaje)
  /// - [isAdmin] = false → status='obrada' (V2Putnik šalje zahtev, backend obrađuje)
  ///
  /// Nema datuma, nema sedmice, nema predviđanja.
  static Future<void> v2PoSaljiZahtev({
    required String putnikId,
    required String dan,
    required String grad,
    required String vreme,
    int brojMesta = 1,
    bool isAdmin = false,
    String? customAdresaId,
    String? putnikTabela, // v2_radnici / v2_ucenici / v2_dnevni / v2_posiljke
  }) async {
    try {
      final gradKey = GradAdresaValidator.normalizeGrad(grad);
      final normVreme = GradAdresaValidator.normalizeTime(vreme);
      final danKey = dan.toLowerCase();
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final status = isAdmin ? 'odobreno' : 'obrada';

      // Upsert po (putnik_id, dan, grad, zeljeno_vreme) — svaka kombinacija je jedinstvena
      final existing = await _supabase
          .from('v2_polasci')
          .select('id')
          .eq('putnik_id', putnikId)
          .eq('grad', gradKey)
          .eq('dan', danKey)
          .eq('zeljeno_vreme', '$normVreme:00')
          .maybeSingle();

      if (existing != null) {
        await _supabase.from('v2_polasci').update({
          'status': status,
          'broj_mesta': brojMesta,
          if (putnikTabela != null) 'putnik_tabela': putnikTabela,
          if (customAdresaId != null) 'adresa_id': customAdresaId,
          if (isAdmin) 'dodeljeno_vreme': '$normVreme:00',
          'updated_at': nowStr,
        }).eq('id', existing['id']);
        debugPrint('✅ [V2PolasciService] v2PoSaljiZahtev UPDATE $gradKey $normVreme $danKey (isAdmin=$isAdmin)');
      } else {
        await _supabase.from('v2_polasci').insert({
          'putnik_id': putnikId,
          'grad': gradKey,
          'dan': danKey,
          'zeljeno_vreme': '$normVreme:00',
          if (isAdmin) 'dodeljeno_vreme': '$normVreme:00',
          'status': status,
          'broj_mesta': brojMesta,
          if (putnikTabela != null) 'putnik_tabela': putnikTabela,
          if (customAdresaId != null) 'adresa_id': customAdresaId,
          'created_at': nowStr,
          'updated_at': nowStr,
        });
        debugPrint('✅ [V2PolasciService] v2PoSaljiZahtev INSERT $gradKey $normVreme $danKey (isAdmin=$isAdmin)');
      }
    } catch (e) {
      debugPrint('❌ [V2PolasciService] v2PoSaljiZahtev error: $e');
      rethrow;
    }
  }

  /// Odobrava zahtev — kopira zeljeno_vreme u dodeljeno_vreme
  static Future<bool> v2OdobriZahtev(String id, {String? approvedBy}) async {
    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();

      // 1. Dohvati zeljeno_vreme za ovaj zahtev
      final row = await _supabase.from('v2_polasci').select('zeljeno_vreme').eq('id', id).single();

      final zeljenoVreme = row['zeljeno_vreme'];

      // 2. Odobri i upisi dodeljeno_vreme = zeljeno_vreme
      await _supabase.from('v2_polasci').update({
        'status': 'odobreno',
        'dodeljeno_vreme': zeljenoVreme, // kopira zeljeno_vreme u dodeljeno_vreme
        'updated_at': nowStr,
        'processed_at': nowStr,
        if (approvedBy != null) 'approved_by': approvedBy,
      }).eq('id', id);

      return true;
    } catch (e) {
      debugPrint('❌ [V2PolasciService] Error approving request: $e');
      return false;
    }
  }

  /// Odbija zahtev
  static Future<bool> v2OdbijZahtev(String id, {String? rejectedBy}) async {
    try {
      await _supabase.from('v2_polasci').update({
        'status': 'odbijeno',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'processed_at': DateTime.now().toUtc().toIso8601String(),
        if (rejectedBy != null) 'cancelled_by': rejectedBy,
      }).eq('id', id);

      return true;
    } catch (e) {
      debugPrint('❌ [V2PolasciService] Error rejecting request: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // JAVNI STREAMOVI — čitaju direktno iz V2MasterRealtimeManager cache-a
  // ---------------------------------------------------------------------------

  /// Čita polasciCache iz mastera, enrichuje iz putnici cacheova — 0 DB upita.
  ///
  /// - [statusFilter] = null → samo `'obrada'`; lista → filtriraj po tim statusima
  /// - [gradFilter] = opcioni filter po gradu (`'BC'` / `'VS'`)
  static Stream<List<V2Polazak>> v2StreamZahteviObrada({
    List<String>? statusFilter,
    String? gradFilter,
  }) {
    final rm = V2MasterRealtimeManager.instance;
    final controller = StreamController<List<V2Polazak>>.broadcast();

    // Čita iz cache-a i emituje — bez ijednog DB upita
    void emit() {
      if (controller.isClosed) return;
      final statusi = statusFilter != null && statusFilter.isNotEmpty ? statusFilter : const ['obrada'];

      final result = rm.polasciCache.values.where((row) {
        if (!statusi.contains(row['status'])) return false;
        if (gradFilter != null && row['grad'] != gradFilter) return false;
        return true;
      }).map((row) {
        final putnikId = row['putnik_id']?.toString();
        final putnikTabela = row['putnik_tabela']?.toString();

        // Enrichuj iz putnici cache-a — sve u memoriji
        final putnikRow = putnikId == null
            ? null
            : switch (putnikTabela) {
                'v2_radnici' => rm.radniciCache[putnikId],
                'v2_ucenici' => rm.uceniciCache[putnikId],
                'v2_dnevni' => rm.dnevniCache[putnikId],
                'v2_posiljke' => rm.posiljkeCache[putnikId],
                _ => rm.getPutnikById(putnikId),
              };

        final enriched = putnikRow == null
            ? row
            : {
                ...row,
                'putnik_ime': putnikRow['ime'],
                'broj_telefona': putnikRow['broj_telefona'],
                if (putnikTabela == null) 'putnik_tabela': putnikRow['_tabela'],
              };

        return V2Polazak.fromJson(enriched);
      }).toList()
        ..sort((a, b) {
          final ca = a.createdAt ?? DateTime(0);
          final cb = b.createdAt ?? DateTime(0);
          return cb.compareTo(ca); // najnoviji prvi
        });

      controller.add(result);
    }

    // Emituj odmah (cache je već popunjen pri initialize())
    Future.microtask(emit);

    // Svakim realtime eventom na v2_polasci master ažurira polasciCache,
    // a mi samo ponovo čitamo iz tog cache-a
    final sub = rm.subscribe('v2_polasci').listen((_) => emit());
    controller.onCancel = () {
      sub.cancel();
      rm.unsubscribe('v2_polasci');
    };
    return controller.stream;
  }

  /// Broj zahteva u statusu `'obrada'` — za bedž na Home ekranu.
  static Stream<int> v2StreamBrojZahteva() => v2StreamZahteviObrada().map((list) => list.length);

  /// 🤖 DIGITALNI DISPEČER — replicira dispecer_cron_obrada + obrada v2_polasci logiku
  static Future<int> v2PokreniDispecera() async {
    try {
      // 1. Dohvati sve pending zahteve (ORDER BY created_at ASC — jedino pravilo redosleda)
      final pendingRows = await _supabase
          .from('v2_polasci')
          .select('id, grad, dan, updated_at, zeljeno_vreme, broj_mesta, putnik_id, putnik_tabela, created_at')
          .eq('status', 'obrada')
          .order('created_at', ascending: true);

      if (pendingRows.isEmpty) return 0;

      // 2. Dohvati kapacitete svih polazaka odjednom
      final kapacitetRows =
          await _supabase.from('v2_kapacitet_polazaka').select('grad, vreme, max_mesta').eq('aktivan', true);

      final Map<String, int> kapacitetMap = {};
      for (final k in kapacitetRows) {
        final key = '${k['grad']}_${k['vreme']}';
        kapacitetMap[key] = (k['max_mesta'] as num).toInt();
      }

      // 3. Dohvati zauzetost za sve relevantne dan+grad+vreme kombinacije
      final dani = pendingRows.map((r) => r['dan'].toString()).toSet().toList();
      final zauzetoRows = await _supabase
          .from('v2_polasci')
          .select('grad, zeljeno_vreme, dan, broj_mesta')
          .inFilter('dan', dani)
          .inFilter('status', ['obrada', 'odobreno']);

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
        final String putnikTabela = req['putnik_tabela']?.toString() ?? '';
        final String tip = switch (putnikTabela) {
          'v2_radnici' => 'radnik',
          'v2_ucenici' => 'ucenik',
          'v2_dnevni' => 'dnevni',
          'v2_posiljke' => 'posiljka',
          _ => 'dnevni',
        };

        // ⛔ Dnevni putnici NIKAD ne prolaze auto-obradu → uvek 'obrada' za admin ručno
        if (tip == 'dnevni') continue;

        final DateTime updatedAt = DateTime.parse(req['updated_at'].toString()).toUtc();
        final String createdAtStr = req['created_at']?.toString() ?? req['updated_at'].toString();
        final DateTime createdAt = DateTime.parse(createdAtStr).toUtc();
        final String zeljeno = req['zeljeno_vreme'].toString();
        final int brojMesta = (req['broj_mesta'] as num?)?.toInt() ?? 1;

        // --- get_cekanje_pravilo (dispecer.sql) ---
        int minutaCekanja;
        bool proveraKapaciteta;
        if (grad == 'BC') {
          if (tip == 'ucenik' && createdAt.hour < 16) {
            // BC učenik pre 16h: 5 min, BEZ provere kapaciteta (garantovano mesto)
            minutaCekanja = 5;
            proveraKapaciteta = false;
          } else if (tip == 'radnik') {
            // BC radnik: 5 min, SA proverom kapaciteta
            minutaCekanja = 5;
            proveraKapaciteta = true;
          } else if (tip == 'ucenik' && createdAt.hour >= 16) {
            // BC učenik posle 16h: čeka do 20h (specijalni slučaj), SA proverom
            minutaCekanja = 0; // obrađuje se u 20h (bcUcenikNocni uslov)
            proveraKapaciteta = true;
          } else if (tip == 'posiljka') {
            // BC pošiljka: 10 min, BEZ provere (ne zauzima mesto)
            minutaCekanja = 10;
            proveraKapaciteta = false;
          } else {
            // BC default: 5 min, SA proverom
            minutaCekanja = 5;
            proveraKapaciteta = true;
          }
        } else if (grad == 'VS') {
          if (tip == 'posiljka') {
            // VS pošiljka: 10 min, BEZ provere (ne zauzima mesto)
            minutaCekanja = 10;
            proveraKapaciteta = false;
          } else if (tip == 'radnik' || tip == 'ucenik') {
            // VS radnik/učenik: 10 min, SA proverom kapaciteta
            minutaCekanja = 10;
            proveraKapaciteta = true;
          } else {
            // VS default: 10 min, SA proverom
            minutaCekanja = 10;
            proveraKapaciteta = true;
          }
        } else {
          // Nepoznat grad: 5 min, SA proverom
          minutaCekanja = 5;
          proveraKapaciteta = true;
        }

        // --- dispecer_cron_obrada uslov za obradu ---
        final minutesWaiting = now.difference(updatedAt).inSeconds / 60.0;
        final bcUcenikNocni = tip == 'ucenik' && grad == 'BC' && createdAt.hour >= 16 && now.hour >= 20;
        final regularTimeout =
            minutesWaiting >= minutaCekanja && !(tip == 'ucenik' && grad == 'BC' && createdAt.hour >= 16);

        if (!bcUcenikNocni && !regularTimeout) continue;

        // --- obrada v2_polasci logika ---
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
          noviStatus = 'odobreno';
        } else {
          noviStatus = 'odbijeno';
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
        await _supabase.from('v2_polasci').update({
          'status': noviStatus,
          'processed_at': nowStr,
          'updated_at': nowStr,
          if (noviStatus == 'odobreno') 'dodeljeno_vreme': zeljeno,
          if (alt1 != null) 'alternative_vreme_1': alt1,
          if (alt2 != null) 'alternative_vreme_2': alt2,
        }).eq('id', reqId);

        debugPrint('🤖 [Dispecer] $reqId → $noviStatus (tip=$tip, grad=$grad, dan=$dan)');
        processedCount++;
      }

      return processedCount;
    } catch (e) {
      debugPrint('❌ [V2PolasciService] Error u digitalnom dispečeru: $e');
      return 0;
    }
  }

  /// 🎫 Prihvata alternativni termin - ODMAH ODOBRAVA
  static Future<bool> v2PrihvatiAlternativu({
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
        await _supabase.from('v2_polasci').update({
          'zeljeno_vreme': novoVreme, // cekaonica → premestamo na novi termin
          'dodeljeno_vreme': novoVreme, // stvarni termin putovanja → novi termin
          'status': 'odobreno',
          'processed_at': nowStr,
          'updated_at': nowStr,
        }).eq('id', requestId);
      } else {
        // Ako nema requestId, kreiraj novi zahtev (fallback)
        await _supabase.from('v2_polasci').insert({
          'putnik_id': putnikId,
          'grad': gradKey,
          'dan': danKey,
          'zeljeno_vreme': novoVreme, // cekaonica
          'dodeljeno_vreme': novoVreme, // stvarni termin putovanja
          'status': 'odobreno',
          'processed_at': nowStr,
        });
      }
      return true;
    } catch (e) {
      debugPrint('❌ [V2PolasciService] Error accepting alternative: $e');
      return false;
    }
  }
}
