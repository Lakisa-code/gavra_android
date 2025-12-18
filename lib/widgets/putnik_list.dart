import 'package:flutter/material.dart';

import '../models/putnik.dart';
import 'putnik_card.dart';

/// Widget koji prikazuje listu putnika koristeći PutnikCard za svaki element.

class PutnikList extends StatelessWidget {
  const PutnikList({
    Key? key,
    this.putnici,
    this.putniciStream,
    this.showActions = true,
    this.currentDriver,
    this.bcVremena,
    this.vsVremena,
    this.useProvidedOrder = false,
    this.onPutnikStatusChanged,
    this.onPokupljen,
    this.selectedGrad,
    this.selectedVreme,
  }) : super(key: key);
  final bool showActions;
  final String? currentDriver;
  final Stream<List<Putnik>>? putniciStream;
  final List<Putnik>? putnici;
  final List<String>? bcVremena;
  final List<String>? vsVremena;
  final bool useProvidedOrder;
  final VoidCallback? onPutnikStatusChanged;
  final VoidCallback? onPokupljen;
  final String? selectedGrad;
  final String? selectedVreme;

  // Helper metoda za sortiranje putnika po grupama
  // SINHRONIZOVANO sa CardColorHelper.getCardState() prioritetom
  int _putnikSortKey(Putnik p) {
    // PRIORITET (isti kao CardColorHelper):
    // 1. Odsustvo (žuto) - na dno
    // 2. Otkazano (crveno) - pre žutih
    // 3. Plaćeno/Mesečno (zeleno)
    // 4. Pokupljeno neplaćeno (plavo)
    // 5. Nepokupljeno (belo) - na vrh

    // 🟡 ŽUTE - Odsustvo ima najveći sort key (na dno)
    if (p.jeOdsustvo) {
      return 5; // žute na dno liste
    }

    // 🔴 CRVENE - Otkazane (koristi jeOtkazan getter koji proverava i obrisan flag)
    if (p.jeOtkazan) {
      return 4; // crvene pre žutih
    }

    // Pokupljeni putnici
    if (p.jePokupljen) {
      // 🟢 ZELENE - Plaćeni ili mesečni
      final bool isPlaceno = (p.iznosPlacanja ?? 0) > 0;
      final bool isMesecna = p.mesecnaKarta == true;
      if (isPlaceno || isMesecna) {
        return 3; // zelene
      }
      // 🔵 PLAVE - Pokupljeni neplaćeni
      return 2;
    }

    // ⚪ BELE - Nepokupljeni (na vrh liste)
    return 1;
  }

  // Helper za proveru da li putnik treba da ima redni broj
  bool _imaRedniBroj(Putnik p) {
    return !p.jeOdsustvo && !(p.status?.toLowerCase() == 'otkazano' || p.status?.toLowerCase() == 'otkazan');
  }

  // Vraća početni redni broj za putnika (prvi broj od njegovih mesta)
  int _pocetniRedniBroj(List<Putnik> putnici, int currentIndex) {
    int redniBroj = 1;
    for (int i = 0; i < currentIndex; i++) {
      final p = putnici[i];
      if (_imaRedniBroj(p)) {
        redniBroj += p.brojMesta;
      }
    }
    return redniBroj;
  }

  @override
  Widget build(BuildContext context) {
    bool prikaziPutnika(Putnik p) {
      // Prikazuj SVE putnike, ali otkazane šalji na dno i ne broji u rednim brojevima
      return true;
    }

    // Helper za deduplikaciju po id (ako nema id, koristi ime+dan+polazak)
    List<Putnik> deduplicatePutnici(List<Putnik> putnici) {
      final seen = <dynamic, bool>{};
      return putnici.where((p) {
        final key = p.id ?? '${p.ime}_${p.dan}_${p.polazak}';
        if (seen.containsKey(key)) {
          return false;
        } else {
          seen[key] = true;
          return true;
        }
      }).toList();
    }

    if (putniciStream != null) {
      return StreamBuilder<List<Putnik>>(
        stream: putniciStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nema putnika za prikaz.'));
          }
          var filteredPutnici = snapshot.data!.where(prikaziPutnika).toList();
          filteredPutnici = deduplicatePutnici(filteredPutnici);
          // UVEK KORISTI STANDARDNO GRUPNO SORTIRANJE: 1-BELI, 2-PLAVI, 3-ZELENI, 4-CRVENI, 5-ŽUTI
          // Ovo je prioritet nad optimizovanom rutom jer korisnik želi striktne grupe
          filteredPutnici.sort((a, b) {
            final aSortKey = _putnikSortKey(a);
            final bSortKey = _putnikSortKey(b);

            final cmp = aSortKey.compareTo(bSortKey);
            if (cmp != 0) return cmp;

            // Ako su u istoj grupi, sortiraj alfabetski po imenu
            return a.ime.compareTo(b.ime);
          });

          final prikaz = filteredPutnici;
          if (prikaz.isEmpty) {
            return const Center(child: Text('Nema putnika za prikaz.'));
          }
          return ListView.builder(
            itemCount: prikaz.length,
            itemBuilder: (context, index) {
              final putnik = prikaz[index];
              // Redni broj: računa sa brojem mesta svakog putnika
              int? redniBroj;
              if (_imaRedniBroj(putnik)) {
                redniBroj = _pocetniRedniBroj(prikaz, index);
              }

              return PutnikCard(
                putnik: putnik,
                showActions: showActions,
                currentDriver: currentDriver,
                redniBroj: redniBroj,
                bcVremena: bcVremena,
                vsVremena: vsVremena,
                selectedGrad: selectedGrad,
                selectedVreme: selectedVreme,
                onChanged: onPutnikStatusChanged,
                onPokupljen: onPokupljen,
              );
            },
          );
        },
      );
    } else if (putnici != null) {
      if (putnici!.isEmpty) {
        return const Center(child: Text('Nema putnika za prikaz.'));
      }
      var filteredPutnici = putnici!.where(prikaziPutnika).toList();
      filteredPutnici = deduplicatePutnici(filteredPutnici);
      // NOVI VIZUELNI REDOSLED U LISTI:
      // 1) BELE - Nepokupljeni (na vrhu)
      // 2) PLAVE - Pokupljeni neplaćeni
      // 3) ZELENE - Pokupljeni mesečne i pokupljeni plaćeno
      // 4) CRVENE - Otkazani
      // 5) ŽUTE - Odsustvo (godišnji/bolovanje) (na dnu)

      // HIBRIDNO SORTIRANJE ZA OPTIMIZOVANU RUTU:
      // Bele kartice (nepokupljeni) → zadržavaju geografski redosled
      // Plave/Zelene/Crvene/Žute → sortiraju se po grupama ispod belih
      if (useProvidedOrder) {
        // Razdvoji putnike po grupama
        final beli = <Putnik>[]; // nepokupljeni - zadržavaju geografski redosled
        final plavi = <Putnik>[]; // pokupljeni neplaćeni
        final zeleni = <Putnik>[]; // pokupljeni plaćeni/mesečni
        final crveni = <Putnik>[]; // otkazani
        final zuti = <Putnik>[]; // odsustvo

        for (final p in filteredPutnici) {
          final sortKey = _putnikSortKey(p);
          switch (sortKey) {
            case 1:
              beli.add(p); // beli zadržavaju originalni geografski redosled
              break;
            case 2:
              plavi.add(p);
              break;
            case 3:
              zeleni.add(p);
              break;
            case 4:
              crveni.add(p);
              break;
            case 5:
              zuti.add(p);
              break;
          }
        }

        // Spoji sve grupe: BELI (geografski) → PLAVI → ZELENI → CRVENI → ŽUTI
        final prikaz = [...beli, ...plavi, ...zeleni, ...crveni, ...zuti];

        if (prikaz.isEmpty) {
          return const Center(child: Text('Nema putnika za prikaz.'));
        }
        return ListView.builder(
          itemCount: prikaz.length,
          itemBuilder: (context, index) {
            final putnik = prikaz[index];
            // Redni broj: računa sa brojem mesta svakog putnika
            int? redniBroj;
            if (_imaRedniBroj(putnik)) {
              redniBroj = _pocetniRedniBroj(prikaz, index);
            }
            return PutnikCard(
              putnik: putnik,
              showActions: showActions,
              currentDriver: currentDriver,
              redniBroj: redniBroj,
              bcVremena: bcVremena,
              vsVremena: vsVremena,
              selectedGrad: selectedGrad,
              selectedVreme: selectedVreme,
              onChanged: onPutnikStatusChanged,
              onPokupljen: onPokupljen,
            );
          },
        );
      }

      // SORTIRAJ PO GRUPAMA: 1-BELI, 2-PLAVI, 3-ZELENI, 4-CRVENI, 5-ŽUTI
      filteredPutnici.sort((a, b) {
        final aSortKey = _putnikSortKey(a);
        final bSortKey = _putnikSortKey(b);
        final cmp = aSortKey.compareTo(bSortKey);
        if (cmp != 0) return cmp;
        return a.ime.compareTo(b.ime);
      });

      if (filteredPutnici.isEmpty) {
        return const Center(child: Text('Nema putnika za prikaz.'));
      }
      return ListView.builder(
        itemCount: filteredPutnici.length,
        itemBuilder: (context, index) {
          final putnik = filteredPutnici[index];
          // Redni broj: računa sa brojem mesta svakog putnika
          int? redniBroj;
          if (_imaRedniBroj(putnik)) {
            redniBroj = _pocetniRedniBroj(filteredPutnici, index);
          }
          return PutnikCard(
            putnik: putnik,
            showActions: showActions,
            currentDriver: currentDriver,
            redniBroj: redniBroj,
            bcVremena: bcVremena,
            vsVremena: vsVremena,
            selectedGrad: selectedGrad,
            selectedVreme: selectedVreme,
            onChanged: onPutnikStatusChanged,
            onPokupljen: onPokupljen,
          );
        },
      );
    } else {
      return const Center(child: Text('Nema podataka.'));
    }
  }
}
