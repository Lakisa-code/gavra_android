import '../models/mesecni_putnik.dart';
import '../services/mesecni_putnik_service.dart';

// Funkcija za compute: filtrira i sortira putnike van glavnog threada
List<MesecniPutnik> filterAndSortPutnici(Map<String, dynamic> args) {
  final List<MesecniPutnik> putnici = List<MesecniPutnik>.from(args['putnici']);
  final String searchTerm = args['searchTerm'] ?? '';
  final String filterType = args['filterType'] ?? 'svi';

  // PRIMER: filtriraj po polascima za ponedeljak (možeš povezati sa UI)
  final polasciZaDan = ['6 VS', '13 BC'];
  final dan = 'pon';
  final filtrirani = MesecniPutnikService.filterByPolasci(
    putnici,
    dan: dan,
    polasci: polasciZaDan,
  );

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
  return result;
}
