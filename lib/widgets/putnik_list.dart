import 'package:flutter/material.dart';

import '../models/putnik.dart';
import '../utils/putnik_helpers.dart';
import 'putnik_card.dart';

/// Widget koji prikazuje listu putnika koristeći PutnikCard za svaki element.

class PutnikList extends StatelessWidget {
  const PutnikList({
    Key? key,
    this.putnici,
    this.putniciStream,
    this.showActions = true,
    required this.currentDriver,
    this.bcVremena,
    this.vsVremena,
    this.useProvidedOrder = false,
    this.onPutnikStatusChanged,
    this.onPokupljen,
    this.selectedGrad,
    this.selectedVreme,
  }) : super(key: key);
  final bool showActions;
  final String currentDriver;
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
  // Prioritet: Moji/Nedodeljeni (beli) → Tuđi (sivi) → Plavi → Zeleni → Crveni → Žuti
  int _putnikSortKey(Putnik p, String currentDriver) {
    // 🟡 ŽUTE - Odsustvo ima najveći sort key (na dno)
    if (p.jeOdsustvo) {
      return 7; // žute na dno liste
    }

    // 🔴 CRVENE - Otkazane
    if (p.jeOtkazan) {
      return 6; // crvene pre žutih
    }

    // Pokupljeni putnici (plavi/zeleni ostaju normalno)
    if (p.jePokupljen) {
      // 🟢 ZELENE - Plaćeni ili mesečni
      final bool isPlaceno = (p.iznosPlacanja ?? 0) > 0;
      final bool isMesecniTip = p.isMesecniTip;
      if (isPlaceno || isMesecniTip) {
        return 5; // zelene
      }
      // 🔵 PLAVE - Pokupljeni neplaćeni (dnevni tip)
      return 4;
    }

    // 🔘 SIVI - Tuđi putnici (dodeljen DRUGOM vozaču) - NEPOKUPLJENI
    final bool isTudji = p.dodaoVozac != null && p.dodaoVozac!.isNotEmpty && p.dodaoVozac != currentDriver;
    if (isTudji) {
      return 3; // sivi - tuđi putnici
    }

    // ⚪ BELI - Moji (dodeljen meni) ili Nedodeljeni (vozac_id = null)
    // Moji idu prvi, pa nedodeljeni
    final bool isMoj = p.dodaoVozac == currentDriver;
    if (isMoj) {
      return 1; // moji na vrh
    }

    // Nedodeljeni
    return 2;
  }

  // Helper za proveru da li putnik treba da ima redni broj
  // 🔧 REFAKTORISANO: Koristi PutnikHelpers za konzistentnu logiku
  bool _imaRedniBroj(Putnik p) {
    return PutnikHelpers.shouldHaveOrdinalNumber(p);
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
          // SORTIRANJE: Moji → Nedodeljeni → Tuđi (sivi) → Plavi → Zeleni → Crveni → Žuti
          filteredPutnici.sort((a, b) {
            final aSortKey = _putnikSortKey(a, currentDriver);
            final bSortKey = _putnikSortKey(b, currentDriver);

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
        final moji = <Putnik>[]; // moji putnici (dodeljen = ja)
        final nedodeljeni = <Putnik>[]; // nedodeljeni (vozac_id = null)
        final sivi = <Putnik>[]; // tuđi putnici (dodeljen drugom vozaču)
        final plavi = <Putnik>[]; // pokupljeni neplaćeni
        final zeleni = <Putnik>[]; // pokupljeni plaćeni/mesečni
        final crveni = <Putnik>[]; // otkazani
        final zuti = <Putnik>[]; // odsustvo

        for (final p in filteredPutnici) {
          final sortKey = _putnikSortKey(p, currentDriver);
          switch (sortKey) {
            case 1:
              moji.add(p); // moji zadržavaju originalni geografski redosled
              break;
            case 2:
              nedodeljeni.add(p);
              break;
            case 3:
              sivi.add(p); // tuđi putnici
              break;
            case 4:
              plavi.add(p);
              break;
            case 5:
              zeleni.add(p);
              break;
            case 6:
              crveni.add(p);
              break;
            case 7:
              zuti.add(p);
              break;
          }
        }

        // Spoji sve grupe: MOJI → NEDODELJENI → SIVI (tuđi) → PLAVI → ZELENI → CRVENI → ŽUTI
        final prikaz = [...moji, ...nedodeljeni, ...sivi, ...plavi, ...zeleni, ...crveni, ...zuti];

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

      // SORTIRAJ: Moji → Nedodeljeni → Tuđi (sivi) → Plavi → Zeleni → Crveni → Žuti
      filteredPutnici.sort((a, b) {
        final aSortKey = _putnikSortKey(a, currentDriver);
        final bSortKey = _putnikSortKey(b, currentDriver);
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
