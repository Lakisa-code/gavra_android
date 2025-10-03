import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/mesecni_putnik.dart';

void main() {
  group('Test ISPRAVNOG dodavanja mesečnih putnika', () {
    test('Test konstrukcije sa svim potrebnim parametrima', () {
      // Simuliramo podatke kako ih sada šalje ispravljena _sacuvajNovogPutnika()
      final ime = 'Marko Petrović';
      final tipSkole = 'osnovna';
      final brojTelefona = '+381641234567';
      final noviTip = 'ucenik';
      final radniDani = 'pon,uto,sre,cet,pet';

      final Map<String, List<String>> polasciPoDanu = {
        'pon': ['07:30 BC', '14:00 VS'],
        'uto': ['07:30 BC', '14:00 VS'],
        'sre': ['07:30 BC', '14:00 VS'],
        'cet': ['07:30 BC', '14:00 VS'],
        'pet': ['07:30 BC', '14:00 VS'],
      };

      // ISPRAVAN PRISTUP - kako sada treba da bude u _sacuvajNovogPutnika()
      final noviPutnik = MesecniPutnik(
        id: '', // Biće generisan od strane baze
        putnikIme: ime, // Celo ime u jednom polju
        tip: noviTip, // Direktno string
        tipSkole: tipSkole.isEmpty ? null : tipSkole,
        brojTelefona: brojTelefona.isEmpty ? null : brojTelefona,
        polasciPoDanu: polasciPoDanu,
        radniDani: radniDani,
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Proveri da je objekat kreiran sa ispravnim vrednostima
      expect(noviPutnik.putnikIme, 'Marko Petrović');
      expect(noviPutnik.tip, 'ucenik');
      expect(noviPutnik.tipSkole, 'osnovna');
      expect(noviPutnik.brojTelefona, '+381641234567');
      expect(noviPutnik.radniDani, 'pon,uto,sre,cet,pet');
      expect(noviPutnik.polasciPoDanu.length, 5);
      expect(noviPutnik.aktivan, true); // Default vrednost
      expect(noviPutnik.obrisan, false); // Default vrednost
    });

    test('Test toMap() za insert u bazu podataka', () {
      final putnik = MesecniPutnik(
        id: '',
        putnikIme: 'Ana Jovanović',
        tip: 'radnik',
        polasciPoDanu: {
          'pon': ['08:00 BC']
        },
        radniDani: 'pon',
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = putnik.toMap();

      // Proveri da li su svi potrebni ključevi za bazu tu
      expect(map.containsKey('putnik_ime'), true);
      expect(map.containsKey('tip'), true);
      expect(map.containsKey('polasci_po_danu'), true);
      expect(map.containsKey('radni_dani'), true);
      expect(map.containsKey('datum_pocetka_meseca'), true);
      expect(map.containsKey('datum_kraja_meseca'), true);
      expect(map.containsKey('aktivan'), true);
      expect(map.containsKey('created_at'), true);
      expect(map.containsKey('updated_at'), true);

      // Proveri vrednosti
      expect(map['putnik_ime'], 'Ana Jovanović');
      expect(map['tip'], 'radnik');
      expect(map['radni_dani'], 'pon');
      expect(map['aktivan'], true);

      // Proveri da id nije tu ako je prazan (biće generisan od strane baze)
      expect(map.containsKey('id'), false);
    });

    test('Test fromMap() nakon čitanja iz baze', () {
      final mapIzBaze = {
        'id': 'test-uuid-123',
        'putnik_ime': 'Petar Nikolić',
        'tip': 'radnik',
        'tip_skole': null,
        'broj_telefona': '+381641234567',
        'polasci_po_danu': {
          'pon': [
            {'bc': '07:30', 'vs': ''},
            {'bc': '', 'vs': '14:00'}
          ]
        },
        'radni_dani': 'pon,uto,sre,cet,pet',
        'aktivan': true,
        'status': 'aktivan',
        'datum_pocetka_meseca': '2025-10-01',
        'datum_kraja_meseca': '2025-10-31',
        'cena': 3000.0,
        'created_at': '2025-10-03T12:00:00Z',
        'updated_at': '2025-10-03T12:00:00Z',
        'obrisan': false,
      };

      final putnik = MesecniPutnik.fromMap(mapIzBaze);

      expect(putnik.id, 'test-uuid-123');
      expect(putnik.putnikIme, 'Petar Nikolić');
      expect(putnik.tip, 'radnik');
      expect(putnik.brojTelefona, '+381641234567');
      expect(putnik.radniDani, 'pon,uto,sre,cet,pet');
      expect(putnik.aktivan, true);
      expect(putnik.obrisan, false);
    });
  });
}
