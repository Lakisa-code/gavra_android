import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logging.dart';
import '../models/putovanja_istorija.dart';
import '../models/mesecni_putnik.dart';

// Use centralized logger

class PutovanjaIstorijaService {
  static final _supabase = Supabase.instance.client;

  // 📱 REALTIME STREAM svih putovanja
  static Stream<List<PutovanjaIstorija>> streamPutovanjaIstorija() {
    try {
      return _supabase
          .from('putovanja_istorija')
          .stream(primaryKey: ['id'])
          .order('datum', ascending: false)
          .order('vreme_polaska', ascending: false)
          .map((data) =>
              data.map((json) => PutovanjaIstorija.fromMap(json)).toList());
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška u stream: $e');
      return Stream.value([]);
    }
  }

  // 📱 REALTIME STREAM putovanja za određeni datum
  static Stream<List<PutovanjaIstorija>> streamPutovanjaZaDatum(
      DateTime datum) {
    try {
      final datumStr = datum.toIso8601String().split('T')[0];

      return _supabase
          .from('putovanja_istorija')
          .stream(primaryKey: ['id'])
          .eq('datum', datumStr)
          .order('vreme_polaska')
          .map((data) =>
              data.map((json) => PutovanjaIstorija.fromMap(json)).toList());
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška u stream za datum: $e');
      return Stream.value([]);
    }
  }

  // 📱 REALTIME STREAM putovanja za mesečnog putnika
  static Stream<List<PutovanjaIstorija>> streamPutovanjaMesecnogPutnika(
      String mesecniPutnikId) {
    try {
      return _supabase
          .from('putovanja_istorija')
          .stream(primaryKey: ['id'])
          .eq('mesecni_putnik_id', mesecniPutnikId)
          .order('datum', ascending: false)
          .map((data) =>
              data.map((json) => PutovanjaIstorija.fromMap(json)).toList());
    } catch (e) {
      dlog(
          '❌ [PUTOVANJA ISTORIJA SERVICE] Greška u stream za mesečnog putnika: $e');
      return Stream.value([]);
    }
  }

  // 🔍 DOBIJ sva putovanja
  static Future<List<PutovanjaIstorija>> getAllPutovanjaIstorija() async {
    try {
      final response = await _supabase
          .from('putovanja_istorija')
          .select()
          .order('datum', ascending: false)
          .order('vreme_polaska', ascending: false);

      return response
          .map<PutovanjaIstorija>((json) => PutovanjaIstorija.fromMap(json))
          .toList();
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dohvatanju svih: $e');
      return [];
    }
  }

  // 🔍 DOBIJ putovanja za određeni datum
  static Future<List<PutovanjaIstorija>> getPutovanjaZaDatum(
      DateTime datum) async {
    try {
      final datumStr = datum.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('putovanja_istorija')
          .select()
          .eq('datum', datumStr)
          .order('vreme_polaska');

      return response
          .map<PutovanjaIstorija>((json) => PutovanjaIstorija.fromMap(json))
          .toList();
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dohvatanju za datum: $e');
      return [];
    }
  }

  // 🔍 DOBIJ putovanja za vremenski opseg
  static Future<List<PutovanjaIstorija>> getPutovanjaZaOpseg(
      DateTime odDatuma, DateTime doDatuma) async {
    try {
      final odStr = odDatuma.toIso8601String().split('T')[0];
      final doStr = doDatuma.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('putovanja_istorija')
          .select()
          .gte('datum', odStr)
          .lte('datum', doStr)
          .order('datum', ascending: false)
          .order('vreme_polaska');

      return response
          .map<PutovanjaIstorija>((json) => PutovanjaIstorija.fromMap(json))
          .toList();
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dohvatanju za opseg: $e');
      return [];
    }
  }

  // 🔍 DOBIJ putovanja po ID
  static Future<PutovanjaIstorija?> getPutovanjeById(String id) async {
    try {
      final response = await _supabase
          .from('putovanja_istorija')
          .select()
          .eq('id', id)
          .single();

      return PutovanjaIstorija.fromMap(response);
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dohvatanju po ID: $e');
      return null;
    }
  }

  // 🔍 DOBIJ putovanja mesečnog putnika
  static Future<List<PutovanjaIstorija>> getPutovanjaMesecnogPutnika(
      String mesecniPutnikId) async {
    try {
      final response = await _supabase
          .from('putovanja_istorija')
          .select()
          .eq('mesecni_putnik_id', mesecniPutnikId)
          .order('datum', ascending: false);

      return response
          .map<PutovanjaIstorija>((json) => PutovanjaIstorija.fromMap(json))
          .toList();
    } catch (e) {
      dlog(
          '❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dohvatanju za mesečnog putnika: $e');
      return [];
    }
  }

  // ➕ DODAJ novo putovanje
  static Future<PutovanjaIstorija?> dodajPutovanje(
      PutovanjaIstorija putovanje) async {
    try {
      final response = await _supabase
          .from('putovanja_istorija')
          .insert(putovanje.toMap())
          .select()
          .single();

      dlog(
          '✅ [PUTOVANJA ISTORIJA SERVICE] Dodato putovanje: ${putovanje.putnikIme}');

      return PutovanjaIstorija.fromMap(response);
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dodavanju: $e');
      return null;
    }
  }

  // ➕ DODAJ novo putovanje za mesečnog putnika
  static Future<PutovanjaIstorija?> dodajPutovanjeMesecnogPutnika({
    required MesecniPutnik mesecniPutnik,
    required DateTime datum,
    required String vremePolaska,
    required String adresaPolaska,
    String statusBelaCrkvaVrsac = 'nije_se_pojavio',
    String statusVrsacBelaCrkva = 'nije_se_pojavio',
    double cena = 0.0,
  }) async {
    try {
      final putovanje = PutovanjaIstorija(
        id: '', // Biće generisan od strane baze
        mesecniPutnikId: mesecniPutnik.id,
        tipPutnika: 'mesecni',
        datum: datum,
        vremePolaska: vremePolaska,
        vremeAkcije: DateTime.now(),
        adresaPolaska: adresaPolaska,
        statusBelaCrkvaVrsac: statusBelaCrkvaVrsac,
        statusVrsacBelaCrkva: statusVrsacBelaCrkva,
        putnikIme: mesecniPutnik.putnikIme,
        brojTelefona: mesecniPutnik.brojTelefona,
        cena: cena,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return await dodajPutovanje(putovanje);
    } catch (e) {
      dlog(
          '❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dodavanju mesečnog putovanja: $e');
      return null;
    }
  }

  // ➕ DODAJ novo putovanje za dnevnog putnika
  static Future<PutovanjaIstorija?> dodajPutovanjeDnevnogPutnika({
    required String putnikIme,
    required DateTime datum,
    required String vremePolaska,
    required String adresaPolaska,
    String? brojTelefona,
    String statusBelaCrkvaVrsac = 'nije_se_pojavio',
    String statusVrsacBelaCrkva = 'nije_se_pojavio',
    double cena = 0.0,
  }) async {
    try {
      final putovanje = PutovanjaIstorija(
        id: '', // Biće generisan od strane baze
        mesecniPutnikId: null,
        tipPutnika: 'dnevni',
        datum: datum,
        vremePolaska: vremePolaska,
        vremeAkcije: DateTime.now(),
        adresaPolaska: adresaPolaska,
        statusBelaCrkvaVrsac: statusBelaCrkvaVrsac,
        statusVrsacBelaCrkva: statusVrsacBelaCrkva,
        putnikIme: putnikIme,
        brojTelefona: brojTelefona,
        cena: cena,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return await dodajPutovanje(putovanje);
    } catch (e) {
      dlog(
          '❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dodavanju dnevnog putovanja: $e');
      return null;
    }
  }

  // ✏️ AŽURIRAJ putovanje
  static Future<PutovanjaIstorija?> azurirajPutovanje(
      PutovanjaIstorija putovanje) async {
    try {
      final response = await _supabase
          .from('putovanja_istorija')
          .update(putovanje.toMap())
          .eq('id', putovanje.id)
          .select()
          .single();

      dlog(
          '✅ [PUTOVANJA ISTORIJA SERVICE] Ažurirano putovanje: ${putovanje.putnikIme}');

      return PutovanjaIstorija.fromMap(response);
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri ažuriranju: $e');
      return null;
    }
  }

  // ✏️ AŽURIRAJ status putovanja
  static Future<bool> azurirajStatus({
    required String putovanjeId,
    String? statusBelaCrkvaVrsac,
    String? statusVrsacBelaCrkva,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Jednostavno ažuriranje - koristi jednu status kolonu
      if (statusBelaCrkvaVrsac != null || statusVrsacBelaCrkva != null) {
        // Ako je bilo koji status dat, koristi ga kao glavnog statusa
        final noviStatus = statusBelaCrkvaVrsac ?? statusVrsacBelaCrkva;
        updateData['status'] = noviStatus;
        updateData['pokupljen'] = noviStatus == 'pokupljen';

        if (noviStatus == 'pokupljen') {
          updateData['vreme_pokupljenja'] = DateTime.now().toIso8601String();
        }
      }

      await _supabase
          .from('putovanja_istorija')
          .update(updateData)
          .eq('id', putovanjeId);

      dlog(
          '✅ [PUTOVANJA ISTORIJA SERVICE] Ažuriran status putovanja: $putovanjeId');

      return true;
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri ažuriranju statusa: $e');
      return false;
    }
  }

  // 🗑️ OBRIŠI putovanje
  static Future<bool> obrisiPutovanje(String id) async {
    try {
      await _supabase.from('putovanja_istorija').delete().eq('id', id);

      dlog('✅ [PUTOVANJA ISTORIJA SERVICE] Obrisano putovanje: $id');

      return true;
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri brisanju: $e');
      return false;
    }
  }

  // 📊 STATISTIKE - ukupan broj putovanja
  static Future<int> getBrojPutovanja({
    DateTime? odDatuma,
    DateTime? doDatuma,
    String? tipPutnika,
    String? mesecniPutnikId,
  }) async {
    try {
      var query = _supabase.from('putovanja_istorija').select();

      if (odDatuma != null) {
        query = query.gte('datum', odDatuma.toIso8601String().split('T')[0]);
      }
      if (doDatuma != null) {
        query = query.lte('datum', doDatuma.toIso8601String().split('T')[0]);
      }
      if (tipPutnika != null) {
        query = query.eq('tip_putnika', tipPutnika);
      }
      if (mesecniPutnikId != null) {
        query = query.eq('mesecni_putnik_id', mesecniPutnikId);
      }

      final response = await query;
      return response.length;
    } catch (e) {
      dlog(
          '❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dobijanju broja putovanja: $e');
      return 0;
    }
  }

  // 📊 STATISTIKE - ukupna zarada
  static Future<double> getUkupnaZarada({
    DateTime? odDatuma,
    DateTime? doDatuma,
    String? tipPutnika,
    String? mesecniPutnikId,
  }) async {
    try {
      var query = _supabase.from('putovanja_istorija').select('cena');

      if (odDatuma != null) {
        query = query.gte('datum', odDatuma.toIso8601String().split('T')[0]);
      }
      if (doDatuma != null) {
        query = query.lte('datum', doDatuma.toIso8601String().split('T')[0]);
      }
      if (tipPutnika != null) {
        query = query.eq('tip_putnika', tipPutnika);
      }
      if (mesecniPutnikId != null) {
        query = query.eq('mesecni_putnik_id', mesecniPutnikId);
      }

      final response = await query;
      double ukupno = 0.0;
      for (final item in response) {
        ukupno += (item['cena'] as num?)?.toDouble() ?? 0.0;
      }

      return ukupno;
    } catch (e) {
      dlog(
          '❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dobijanju ukupne zarade: $e');
      return 0.0;
    }
  }
}
