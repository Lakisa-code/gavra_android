import '../models/mesecni_putnik.dart';

// Funkcija za compute: filtrira i sortira putnike van glavnog threada
// Sada koristi List<Map<String, dynamic>> za kompatibilnost sa compute
List<Map<String, dynamic>> filterAndSortPutnici(Map<String, dynamic> args) {
  final List<Map<String, dynamic>> putniciMap =
      List<Map<String, dynamic>>.from(args['putnici'] as Iterable);
  final String searchTerm = (args['searchTerm'] as String?) ?? '';
  final String filterType = (args['filterType'] as String?) ?? 'svi';

  // Rekonstruiši MesecniPutnik objekte iz mapa
  final putnici = putniciMap.map((m) => MesecniPutnik.fromMap(m)).toList();

  // Prikaz svih putnika (osim ako search/filterType ne filtrira)
  final filtrirani = putnici;

  // Ostatak filtera (search, tip)
  final result = filtrirani.where((putnik) {
    // Filtriraj po search termu
    bool matchesSearch = true;
    if (searchTerm.isNotEmpty) {
      final search = searchTerm.toLowerCase();
      matchesSearch = putnik.putnikIme.toLowerCase().contains(search) ||
          (putnik.brojTelefona?.toLowerCase().contains(search) ?? false) ||
          putnik.tip.toLowerCase().contains(search);
    }

    // Filtriraj po tipu putnika
    bool matchesType = true;
    if (filterType != 'svi') {
      matchesType = putnik.tip == filterType;
    }

    return matchesSearch && matchesType;
  }).toList();

  // Sortiranje: prvo po aktivnosti (aktivni gore), zatim po abecednom redu
  result.sort((a, b) {
    const bolovanje = 'bolovanje';
    const godisnje = 'godišnje';
    bool aBolGod = a.status == bolovanje || a.status == godisnje || !a.aktivan;
    bool bBolGod = b.status == bolovanje || b.status == godisnje || !b.aktivan;
    if (aBolGod && !bBolGod) return 1;
    if (!aBolGod && bBolGod) return -1;
    return a.putnikIme.toLowerCase().compareTo(b.putnikIme.toLowerCase());
  });

  // Vrati rezultat kao listu mapa (za compute kompatibilnost)
  return result.map((p) => _mesecniPutnikToMap(p)).toList();
}

// Helper za serijalizaciju MesecniPutnik u Map
Map<String, dynamic> _mesecniPutnikToMap(MesecniPutnik p) {
  return p.toMap();
}




