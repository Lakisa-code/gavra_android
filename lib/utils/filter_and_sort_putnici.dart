import '../models/mesecni_putnik.dart';

// Funkcija za compute: filtrira i sortira putnike van glavnog threada
// Sada koristi List<Map<String, dynamic>> za kompatibilnost sa compute
List<Map<String, dynamic>> filterAndSortPutnici(Map<String, dynamic> args) {
  final List<Map<String, dynamic>> putniciMap =
      List<Map<String, dynamic>>.from(args['putnici']);
  final String searchTerm = args['searchTerm'] ?? '';
  final String filterType = args['filterType'] ?? 'svi';

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
  // Ovdje možeš koristiti toMap() ako postoji, ili ručno mapirati polja
  // Za sada koristimo samo polja potrebna za prikaz
  return {
    'id': p.id,
    'putnik_ime': p.putnikIme,
    'tip': p.tip,
    'tip_skole': p.tipSkole,
    'broj_telefona': p.brojTelefona,
    'polasci_po_danu': p.polasciPoDanu,
    'adresa_bela_crkva': p.adresaBelaCrkva,
    'adresa_vrsac': p.adresaVrsac,
    // legacy single-time fields removed
    'tip_prikazivanja': p.tipPrikazivanja,
    'radni_dani': p.radniDani,
    'aktivan': p.aktivan,
    'status': p.status,
    'datum_pocetka_meseca': p.datumPocetkaMeseca.toIso8601String(),
    'datum_kraja_meseca': p.datumKrajaMeseca.toIso8601String(),
    'cena': p.cena,
    'ukupna_cena_meseca': p.ukupnaCenaMeseca,
    'broj_putovanja': p.brojPutovanja,
    'broj_otkazivanja': p.brojOtkazivanja,
    'poslednje_putovanje': p.poslednjiPutovanje?.toIso8601String(),
    'created_at': p.createdAt.toIso8601String(),
    'updated_at': p.updatedAt.toIso8601String(),
    'obrisan': p.obrisan,
    'vreme_placanja': p.vremePlacanja?.toIso8601String(),
    'placeni_mesec': p.placeniMesec,
    'placena_godina': p.placenaGodina,
    'naplata_vozac': p.vozac,
    'pokupljen': p.pokupljen,
    'vreme_pokupljenja': p.vremePokupljenja?.toIso8601String(),
  };
}
