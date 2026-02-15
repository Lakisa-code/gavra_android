import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import 'realtime_notification_service.dart';

/// Servis za upravljanje aktivnim zahtevima za sedišta (seat_requests tabela)
class SeatRequestService {
  static SupabaseClient get _supabase => supabase;

  /// 📥 INSERT U SEAT_REQUESTS TABELU ZA BACKEND OBRADU
  static Future<void> insertSeatRequest({
    required String putnikId,
    required String dan,
    required String vreme,
    required String grad,
    int brojMesta = 1,
    String status = 'pending',
    String? fixedDate, // 📅 Opciono: Tačan datum ako nije potreban proračun sutrašnjice
  }) async {
    try {
      final datum = fixedDate != null ? DateTime.parse(fixedDate) : getNextDateForDay(DateTime.now(), dan);
      final datumStr = datum.toIso8601String().split('T')[0];

      // 🛡️ PROVERA: Da li već postoji aktivan zahtev za OVAJ GRAD i DATUM (pending ili manual)?
      // Razdvojeni BC i VS zahtevi po danima - putnik može imati jedan aktivan po smeru za svaki dan
      final activeResp = await _supabase
          .from('seat_requests')
          .select('id')
          .eq('putnik_id', putnikId)
          .eq('grad', grad.toUpperCase())
          .eq('datum', datumStr)
          .inFilter('status', ['pending', 'manual']).maybeSingle();

      if (activeResp != null) {
        debugPrint(
            '⚠️ [SeatRequestService] Putnik $putnikId već ima aktivan ${grad.toUpperCase()} zahtev za $datumStr. Blokiram novi.');
        return;
      }

      await _supabase.from('seat_requests').insert({
        'putnik_id': putnikId,
        'grad': grad.toUpperCase(),
        'datum': datumStr,
        'zeljeno_vreme': vreme,
        'status': status,
        'broj_mesta': brojMesta,
      });
      debugPrint('✅ [SeatRequestService] Inserted for $grad $vreme on $dan (Datum: $datumStr)');

      // 🔔 AKO JE STATUS 'manual' (Dnevni putnici), POŠALJI NOTIFIKACIJU ADMINU
      if (status == 'manual') {
        try {
          final putnikData =
              await _supabase.from('registrovani_putnici').select('putnik_ime').eq('id', putnikId).single();
          final imePutnika = putnikData['putnik_ime'] ?? 'Putnik';

          await RealtimeNotificationService.sendNotificationToAdmins(
            title: '🆕 Novi zahtev (Dnevni putnik)',
            body: '$imePutnika želi $grad u $vreme ($dan)',
            data: {'type': 'new_manual_request', 'putnik_id': putnikId},
          );
        } catch (e) {
          debugPrint('⚠️ [SeatRequestService] Greška pri slanju notifikacije adminu: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error inserting seat request: $e');
    }
  }

  /// Dohvata aktivne zahteve
  static Future<List<Map<String, dynamic>>> getActiveRequests() async {
    try {
      final response = await _supabase.from('seat_requests').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Dohvata aktivne zahteve sa statusom 'manual' za admina
  static Future<List<Map<String, dynamic>>> getManualRequests() async {
    try {
      final response = await _supabase
          .from('seat_requests')
          .select('*, registrovani_putnici(ime_prezime, telefon)')
          .eq('status', 'manual');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error getting manual requests: $e');
      return [];
    }
  }

  /// Odobrava zahtev
  static Future<bool> approveRequest(String id) async {
    try {
      // 1. Dohvati podatke o zahtevu pre nego što ga ažuriramo
      final zahtevResp = await _supabase.from('seat_requests').select().eq('id', id).single();
      final putnikId = zahtevResp['putnik_id'];
      final vreme = zahtevResp['zeljeno_vreme'];

      // 2. Ažuriraj status
      await _supabase.from('seat_requests').update({
        'status': 'approved',
        'processed_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      // 3. Pošalji notifikaciju putniku
      await RealtimeNotificationService.sendNotificationToPutnik(
        putnikId: putnikId,
        title: '✅ Mesto osigurano!',
        body: '✅ Mesto osigurano! Vaša rezervacija za $vreme je potvrđena. Želimo vam ugodnu vožnju! 🚌',
        data: {'type': 'seat_request_approved', 'vreme': vreme, 'id': id},
      );

      return true;
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error approving request: $e');
      return false;
    }
  }

  /// Odbija zahtev
  static Future<bool> rejectRequest(String id) async {
    try {
      // 1. Dohvati podatke o zahtevu
      final zahtevResp = await _supabase.from('seat_requests').select().eq('id', id).single();
      final putnikId = zahtevResp['putnik_id'];
      final vreme = zahtevResp['zeljeno_vreme'];

      // 2. Ažuriraj status
      await _supabase.from('seat_requests').update({
        'status': 'rejected',
        'processed_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      // 3. Pošalji notifikaciju putniku
      await RealtimeNotificationService.sendNotificationToPutnik(
        putnikId: putnikId,
        title: '❌ Termin popunjen',
        body: 'Nažalost, u terminu $vreme više nema slobodnih mesta. Molimo Vas da odaberete drugi polazak. ❌',
        data: {'type': 'seat_request_rejected', 'vreme': vreme},
      );

      return true;
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error rejecting request: $e');
      return false;
    }
  }

  /// Stream za manual zahteve (realtime)
  static Stream<List<Map<String, dynamic>>> streamManualRequests() {
    return _supabase
        .from('seat_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'manual')
        .order('created_at', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  /// 🔢 Stream za broj manual zahteva (za bedž na Home ekranu)
  static Stream<int> streamManualRequestCount() {
    return streamManualRequests().map((list) => list.length);
  }

  /// 🤖 POKREĆE DIGITALNOG DISPEČERA U BAZI
  /// Poziva SQL funkciju koja obrađuje pending zahteve starije od 10 min
  static Future<int> triggerDigitalDispecer() async {
    try {
      final List<dynamic> response = await _supabase.rpc('dispecer_cron_obrada');

      if (response.isNotEmpty) {
        debugPrint('🤖 [Digitalni Dispečer] Obrađeno zahteva: ${response.length}');

        // 📲 Pošalji notifikacije za svako automatsko odobrenje/odbijanje
        for (var item in response) {
          final id = item['id'];
          final putnikId = item['putnik_id'];
          final vreme = item['zeljeno_vreme'];
          final status = item['status'];
          final grad = item['grad'];
          final datum = item['datum']; // Novo iz SQL-a
          final imePutnika = item['ime_putnika'] ?? 'Putnik';

          if (status == 'approved') {
            await RealtimeNotificationService.sendNotificationToPutnik(
              putnikId: putnikId,
              title: '✅ Mesto osigurano!',
              body: '✅ Mesto osigurano! Vaša rezervacija za $vreme je potvrđena. Želimo vam ugodnu vožnju! 🚌',
              data: {
                'notification_id': 'seat_request_approval_$putnikId', // 🎯 FIX: Deduplikacija
                'type': 'seat_request_approved',
                'vreme': vreme,
                'id': id
              },
            );
          } else if (status == 'rejected') {
            final List<dynamic>? alternatives = item['alternatives'];
            String body =
                'Nažalost, u terminu $vreme više nema slobodnih mesta. Molimo Vas da odaberete drugi polazak. ❌';
            String type = 'seat_request_rejected';

            if (alternatives != null && alternatives.isNotEmpty) {
              type = 'seat_request_alternatives';
              final formattedAlts = alternatives.map((a) {
                if (a.toString().contains(':')) {
                  final parts = a.toString().split(':');
                  if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
                }
                return a.toString();
              }).join(', ');
              body =
                  'Termin u $vreme je pun ❌, ali imamo mesta u: $formattedAlts. Da li Vam odgovara neki od ovih termina?';
            }

            await RealtimeNotificationService.sendNotificationToPutnik(
              putnikId: putnikId,
              title: '❌ Termin popunjen',
              body: body,
              data: {
                'notification_id': 'seat_request_rejection_$putnikId', // 🎯 FIX: Deduplikacija
                'type': type,
                'vreme': vreme,
                'id': id,
                'putnik_id': putnikId,
                'grad': grad,
                'datum': datum,
                'alternatives': alternatives,
              },
            );
          }
        }
      }
      return response.length;
    } catch (e) {
      debugPrint('❌ [Digitalni Dispečer] Greška pri pozivanju: $e');
      return 0;
    }
  }

  /// 🎫 Prihvata alternativni termin - ODMAH ODOBRAVA (nije fer da čeka ponovnu obradu)
  static Future<bool> acceptAlternative({
    String? requestId, // 🆔 ID originalnog zahteva
    required String putnikId,
    required String novoVreme,
    required String grad,
    required String datum, // Fiksni datum originalnog zahteva
  }) async {
    try {
      final gradUpper = grad.toUpperCase();
      final nowStr = DateTime.now().toUtc().toIso8601String();

      // 1. 🚀 Ažuriraj ili insertuj SEAT REQUEST sa statusom 'approved' (ODMAH!)
      if (requestId != null && requestId.isNotEmpty) {
        await _supabase.from('seat_requests').update({
          'zeljeno_vreme': novoVreme,
          'status': 'approved',
          'processed_at': nowStr,
        }).eq('id', requestId);
        debugPrint('✅ [SeatRequestService] Request $requestId ažuriran na APPROVED ($novoVreme)');
      } else {
        await _supabase.from('seat_requests').insert({
          'putnik_id': putnikId,
          'grad': gradUpper,
          'datum': datum,
          'zeljeno_vreme': novoVreme,
          'status': 'approved',
          'processed_at': nowStr,
        });
        debugPrint('✅ [SeatRequestService] Novi APPROVED zahtev insertovan ($novoVreme)');
      }

      // 2. 📅 Ažuriraj REGISTROVANI_PUTNICI (JSON polasci_po_danu) direktno
      // Ovo osigurava da putnik VIDI promenu odmah u kalendaru/profilu
      try {
        final date = DateTime.parse(datum);
        const daniMap = {
          DateTime.monday: 'pon',
          DateTime.tuesday: 'uto',
          DateTime.wednesday: 'sre',
          DateTime.thursday: 'cet',
          DateTime.friday: 'pet',
          DateTime.saturday: 'sub',
          DateTime.sunday: 'ned'
        };
        final dan = daniMap[date.weekday] ?? 'pon';

        final resp =
            await _supabase.from('registrovani_putnici').select('polasci_po_danu').eq('id', putnikId).maybeSingle();

        if (resp != null && resp['polasci_po_danu'] != null) {
          final polasci = Map<String, dynamic>.from(resp['polasci_po_danu'] as Map);
          if (polasci[dan] != null) {
            final danData = Map<String, dynamic>.from(polasci[dan] as Map);

            // Koristi lowercase za ključeve jer RegistrovaniHelpers tako očekuje
            final g = grad.toLowerCase();
            danData[g] = novoVreme;
            danData['${g}_status'] = 'confirmed';
            danData.remove('${g}_napomena');
            danData.remove('${g}_ceka_od');
            danData.remove('${g}_otkazano_vreme');

            polasci[dan] = danData;
            await _supabase.from('registrovani_putnici').update({'polasci_po_danu': polasci}).eq('id', putnikId);
            debugPrint('✅ [SeatRequestService] Kalendar putnika ažuriran za $dan $g -> $novoVreme');
          }
        }
      } catch (e) {
        debugPrint('⚠️ [SeatRequestService] Greška pri ažuriranju kalendara (JSON): $e');
      }

      return true;
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error accepting alternative: $e');
      return false;
    }
  }

  /// Pomoćna funkcija za dobijanje skraćenice dana
  static String getDanKratica(DateTime date) {
    const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    return dani[date.weekday - 1];
  }

  /// 📅 Helper: Računa sledeći datum za dati dan u nedelji
  static DateTime getNextDateForDay(DateTime fromDate, String danKratica) {
    const daniMap = {'pon': 1, 'uto': 2, 'sre': 3, 'cet': 4, 'pet': 5, 'sub': 6, 'ned': 7};
    final targetWeekday = daniMap[danKratica.toLowerCase()] ?? 1;
    final currentWeekday = fromDate.weekday;

    int daysToAdd = targetWeekday - currentWeekday;
    if (daysToAdd < 0) daysToAdd += 7;

    return fromDate.add(Duration(days: daysToAdd));
  }
}
