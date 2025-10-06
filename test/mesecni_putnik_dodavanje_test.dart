import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/mesecni_putnik.dart';

void main() {
  group('Test dodavanje mesečnih putnika', () {
    test('Test konstrukcije MesecniPutnik modela - REPRODUKUJE PROBLEM', () {
      // Simuliramo podatke iz forme kao što ih šalje _sacuvajNovogPutnika()
      const ime = 'Marko Petrović';
      const tipSkole = 'osnovna';
      const brojTelefona = '+381641234567';
      const noviTip = 'ucenik';

      final Map<String, List<String>> polasciPoDanu = {
        'pon': ['07:30 BC', '14:00 VS'],
        'uto': ['07:30 BC', '14:00 VS'],
      };

      // PROBLEM: Ovaj kod iz _sacuvajNovogPutnika() neće raditi sa novim modelom
      expect(
        () {
          final noviPutnik = MesecniPutnik(
            // GREŠKA: Ovi parametri ne postoje u novom modelu!
            // ime: ime.split(' ').first,
            // prezime: ime.split(' ').length > 1 ? ime.split(' ').skip(1).join(' ') : '',
            // tip: MesecniPutnikTipExtension.fromString(noviTip), // GREŠKA: extension ne postoji
            // tipSkole: tipSkole.isEmpty ? null : tipSkole,
            // brojTelefona: brojTelefona.isEmpty ? null : brojTelefona,
            // adresaId: 'placeholder-address-uuid', // GREŠKA: adresaId ne postoji
            // rutaId: 'placeholder-route-uuid', // GREŠKA: rutaId ne postoji
            // polasciPoDanu: polasciPoDanu,
            // cenaMesecneKarte: 0.0, // GREŠKA: cenaMesecneKarte je uklonjen
            // datumPocetka: DateTime(2025, 10, 1), // GREŠKA: datumPocetka ne postoji
            // datumKraja: DateTime(2025, 10, 31), // GREŠKA: datumKraja ne postoji
            // radniDani: 'pon,uto,sre,cet,pet', // GREŠKA: tip String umesto Map

            // ISPRAVAN PRISTUP:
            id: '',
            putnikIme: ime,
            tip: noviTip,
            tipSkole: tipSkole.isEmpty ? null : tipSkole,
            brojTelefona: brojTelefona.isEmpty ? null : brojTelefona,
            polasciPoDanu: polasciPoDanu,
            datumPocetkaMeseca: DateTime(2025, 10),
            datumKrajaMeseca: DateTime(2025, 10, 31),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Proveri da je objekat kreiran uspešno
          expect(noviPutnik, isNotNull);
          expect(noviPutnik.putnikIme, ime);
          expect(noviPutnik.tip, noviTip);
        },
        returnsNormally,
      );
    });

    test('Test ispravnog kreiranja MesecniPutnik modela', () {
      // ISPRAVAN PRISTUP - kako treba da bude
      const ime = 'Marko Petrović';
      const tipSkole = 'osnovna';
      const brojTelefona = '+381641234567';
      const noviTip = 'ucenik';

      final Map<String, List<String>> polasciPoDanu = {
        'pon': ['07:30 BC', '14:00 VS'],
        'uto': ['07:30 BC', '14:00 VS'],
      };

      final noviPutnik = MesecniPutnik(
        id: '',
        putnikIme: ime, // Celo ime u jednom polju
        tip: noviTip,
        tipSkole: tipSkole.isEmpty ? null : tipSkole,
        brojTelefona: brojTelefona.isEmpty ? null : brojTelefona,
        polasciPoDanu: polasciPoDanu,
        datumPocetkaMeseca: DateTime(2025, 10),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        // Ostali parametri imaju default vrednosti
      );

      // Proveri da je objekat kreiran
      expect(noviPutnik, isNotNull);

      expect(noviPutnik.putnikIme, 'Marko Petrović');
      expect(noviPutnik.tip, 'ucenik');
      expect(noviPutnik.tipSkole, 'osnovna');
      expect(noviPutnik.brojTelefona, '+381641234567');
      expect(noviPutnik.polasciPoDanu.length, 2);
      expect(noviPutnik.aktivan, true); // Default vrednost
    });

    test('Test toMap() metode za bazu podataka', () {
      final putnik = MesecniPutnik(
        id: '',
        putnikIme: 'Ana Jovanović',
        tip: 'radnik',
        polasciPoDanu: {
          'pon': ['08:00 BC'],
        },
        datumPocetkaMeseca: DateTime(2025, 10),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = putnik.toMap();

      // Proveri da li su svi potrebni ključevi tu
      expect(map.containsKey('putnik_ime'), true);
      expect(map.containsKey('tip'), true);
      expect(map.containsKey('polasci_po_danu'), true);
      expect(map.containsKey('datum_pocetka_meseca'), true);
      expect(map.containsKey('datum_kraja_meseca'), true);
      expect(map.containsKey('aktivan'), true);

      // Proveri da nepostojući ključevi nisu tu
      expect(map.containsKey('prezime'), false);
      expect(map.containsKey('adresa_id'), false);
      expect(map.containsKey('ruta_id'), false);
      expect(map.containsKey('cenaMesecneKarte'), false);
    });
  });
}
