import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gps_lokacija.dart';

/// Servis za upravljanje GPS lokacijama vozila
class GPSLokacijaService {
  final SupabaseClient _supabase;

  GPSLokacijaService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  /// Snima novu GPS lokaciju vozila
  Future<GPSLokacija> snimiLokaciju(GPSLokacija lokacija) async {
    final response = await _supabase
        .from('gps_lokacije')
        .insert(lokacija.toMap())
        .select()
        .single();

    return GPSLokacija.fromMap(response);
  }

  /// Snima trenutnu lokaciju vozila
  Future<GPSLokacija> snimiTrenutnuLokaciju({
    required String voziloId,
    String? vozacId,
    required double latitude,
    required double longitude,
    double? brzina,
    double? pravac,
    String? adresa,
  }) async {
    final lokacija = GPSLokacija.sada(
      voziloId: voziloId,
      vozacId: vozacId,
      latitude: latitude,
      longitude: longitude,
      brzina: brzina,
      pravac: pravac,
      adresa: adresa,
    );

    return await snimiLokaciju(lokacija);
  }

  /// Dohvata poslednju lokaciju vozila
  Future<GPSLokacija?> getPoslednjaLokacija(String voziloId) async {
    final response = await _supabase
        .from('gps_lokacije')
        .select()
        .eq('vozilo_id', voziloId)
        .eq('aktivan', true)
        .order('vreme', ascending: false)
        .limit(1);

    if (response.isEmpty) return null;
    return GPSLokacija.fromMap(response.first);
  }

  /// Dohvata istoriju lokacija vozila za dati period
  Future<List<GPSLokacija>> getIstorijaLokacija(
    String voziloId, {
    DateTime? odDatum,
    DateTime? doDatum,
    int limit = 100,
  }) async {
    final response = await _supabase
        .from('gps_lokacije')
        .select()
        .eq('vozilo_id', voziloId)
        .eq('aktivan', true)
        .order('vreme', ascending: false)
        .limit(limit);

    // Filtriramo po datumu u Dart-u jer Supabase SDK ima ograničenja
    var filtrirano = response;
    if (odDatum != null) {
      filtrirano = filtrirano.where((lokacija) {
        final vreme = DateTime.parse(lokacija['vreme'] as String);
        return vreme.isAfter(odDatum) || vreme.isAtSameMomentAs(odDatum);
      }).toList();
    }

    if (doDatum != null) {
      filtrirano = filtrirano.where((lokacija) {
        final vreme = DateTime.parse(lokacija['vreme'] as String);
        return vreme.isBefore(doDatum) || vreme.isAtSameMomentAs(doDatum);
      }).toList();
    }

    return filtrirano.map((json) => GPSLokacija.fromMap(json)).toList();
  }

  /// Dohvata poslednje lokacije svih vozila
  Future<List<GPSLokacija>> getPoslednjeLokacijeSvihVozila() async {
    // Ova query će vratiti poslednju lokaciju za svako vozilo
    final response =
        await _supabase.rpc('get_poslednje_lokacije_vozila').select();

    return response.map((json) => GPSLokacija.fromMap(json)).toList();
  }

  /// Deaktivira GPS lokaciju (za čišćenje starih podataka)
  Future<void> deactivateLokacija(String id) async {
    await _supabase.from('gps_lokacije').update({
      'aktivan': false,
    }).eq('id', id);
  }

  /// Čisti stare GPS lokacije (starije od određenog broja dana)
  Future<int> ocistiStareLokacije(int dana) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: dana));

    final response = await _supabase
        .from('gps_lokacije')
        .update({'aktivan': false}).lt('vreme', cutoffDate.toIso8601String());

    return response.length;
  }

  /// Stream za realtime GPS lokacije vozila
  Stream<List<GPSLokacija>> gpsLokacijeStreamZaVozilo(String voziloId) {
    return _supabase
        .from('gps_lokacije')
        .stream(primaryKey: ['id'])
        .order('vreme', ascending: false)
        .map((data) => data
            .where((lokacija) =>
                lokacija['vozilo_id'] == voziloId &&
                lokacija['aktivan'] == true)
            .take(10) // Samo poslednjih 10 lokacija
            .map((json) => GPSLokacija.fromMap(json))
            .toList());
  }

  /// Stream za realtime lokacije svih vozila
  Stream<List<GPSLokacija>> get sveGPSLokacijeStream {
    return _supabase
        .from('gps_lokacije')
        .stream(primaryKey: ['id'])
        .eq('aktivan', true)
        .order('vreme', ascending: false)
        .map((data) {
          // Grupujemo po vozilu i uzimamo samo poslednju lokaciju po vozilu
          final poVozilu = <String, GPSLokacija>{};
          for (final json in data) {
            final voziloId = json['vozilo_id'] as String;
            if (!poVozilu.containsKey(voziloId)) {
              poVozilu[voziloId] = GPSLokacija.fromMap(json);
            }
          }
          return poVozilu.values.toList();
        });
  }
}
