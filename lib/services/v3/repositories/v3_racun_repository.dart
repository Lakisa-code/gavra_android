import '../../../globals.dart';

class V3RacunRepository {
  Future<List<dynamic>> listRedniBrojByGodinaDescLimit1(int godina) {
    return supabase
        .from('v3_racuni')
        .select('redni_broj')
        .eq('godina', godina)
        .order('redni_broj', ascending: false)
        .limit(1);
  }

  Future<void> insertRacun(Map<String, dynamic> payload) async {
    await supabase.from('v3_racuni').insert(payload);
  }
}
