import 'package:flutter/material.dart';

import '../models/putnik.dart';
import '../utils/text_utils.dart';
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
    this.onPutnikStatusChanged, // 🎯 NOVO: callback kad se promeni status
    this.onPokupljen, // 🔊 NOVO: callback za glasovnu najavu sledećeg
    this.selectedGrad, // 📍 NOVO: za GPS navigaciju mesečnih putnika
    this.selectedVreme, // 📍 NOVO: za GPS navigaciju
  }) : super(key: key);
  final bool showActions;
  final String? currentDriver;
  final Stream<List<Putnik>>? putniciStream;
  final List<Putnik>? putnici;
  final List<String>? bcVremena;
  final List<String>? vsVremena;
  final bool useProvidedOrder;
  final VoidCallback? onPutnikStatusChanged; // 🎯 NOVO
  final VoidCallback? onPokupljen; // 🔊 NOVO: za glasovnu najavu
  final String? selectedGrad; // 📍 NOVO: za GPS navigaciju mesečnih putnika
  final String? selectedVreme; // 📍 NOVO: za GPS navigaciju

  // Helper metoda za sortiranje putnika po grupama
  int _putnikSortKey(Putnik p) {
    final status = TextUtils.normalizeText(p.status ?? '');

    // ŽUTE - Odsustvo ima najveći sort key (na dno)
    if (p.jeOdsustvo) {
      return 5; // žute na dno liste
    }

    // CRVENE - Otkazane
    if (status == 'otkazano' || status == 'otkazan') {
      return 4; // crvene pre žutih
    }

    // MESEČNI PUTNICI
    if (p.mesecnaKarta == true) {
      // BELE vs ZELENE
      return p.vremePokupljenja == null ? 1 : 3; // bela ili zelena
    }

    // OBIČNI PUTNICI
    if (p.vremePokupljenja == null) return 1; // BELE - nepokupljeni
    if (p.vremePokupljenja != null && (p.iznosPlacanja == null || p.iznosPlacanja == 0)) {
      return 2; // PLAVE - pokupljeni neplaćeni
    }
    if (p.vremePokupljenja != null && (p.iznosPlacanja != null && p.iznosPlacanja! > 0)) {
      return 3; // ZELENE - pokupljeni plaćeni
    }
    return 99;
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
          // 🎯 UVEK KORISTI STANDARDNO GRUPNO SORTIRANJE: 1-BELI, 2-PLAVI, 3-ZELENI, 4-CRVENI, 5-ŽUTI
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
              // Redni broj: broji samo one koji nisu otkazani i nisu na odsustvu
              int? redniBroj;
              if (!useProvidedOrder) {
                if (!putnik.jeOdsustvo &&
                    !(putnik.status?.toLowerCase() == 'otkazano' || putnik.status?.toLowerCase() == 'otkazan')) {
                  // Redni broj je pozicija među svim neotkazanim putnicima koji nisu na odsustvu
                  redniBroj = prikaz
                      .take(index + 1)
                      .where((p) =>
                          !p.jeOdsustvo &&
                          !(p.status?.toLowerCase() == 'otkazano' || p.status?.toLowerCase() == 'otkazan'))
                      .length;
                }
              } else {
                // Ako caller traži da se zadrži provajdirani redosled (optiimizovana lista)
                if (!putnik.jeOdsustvo &&
                    !(putnik.status?.toLowerCase() == 'otkazano' || putnik.status?.toLowerCase() == 'otkazan')) {
                  redniBroj = prikaz
                      .take(index + 1)
                      .where((p) =>
                          !p.jeOdsustvo &&
                          !(p.status?.toLowerCase() == 'otkazano' || p.status?.toLowerCase() == 'otkazan'))
                      .length;
                }
              }

              return PutnikCard(
                putnik: putnik,
                showActions: showActions,
                currentDriver: currentDriver,
                redniBroj: redniBroj,
                bcVremena: bcVremena,
                vsVremena: vsVremena,
                selectedGrad: selectedGrad, // 📍 NOVO: za GPS navigaciju
                selectedVreme: selectedVreme, // 📍 NOVO: za GPS navigaciju
                onChanged: onPutnikStatusChanged, // 🎯 NOVO
                onPokupljen: onPokupljen, // 🔊 glasovna najava
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

      // If caller requested to preserve provided order (optimized route), skip grouping
      if (useProvidedOrder) {
        final prikaz = List<Putnik>.from(filteredPutnici);
        if (prikaz.isEmpty) {
          return const Center(child: Text('Nema putnika za prikaz.'));
        }
        return ListView.builder(
          itemCount: prikaz.length,
          itemBuilder: (context, index) {
            final putnik = prikaz[index];
            int? redniBroj;
            if (!putnik.jeOdsustvo &&
                !(putnik.status?.toLowerCase() == 'otkazano' || putnik.status?.toLowerCase() == 'otkazan')) {
              redniBroj = prikaz
                  .take(index + 1)
                  .where(
                    (p) =>
                        !p.jeOdsustvo &&
                        !(p.status?.toLowerCase() == 'otkazano' || p.status?.toLowerCase() == 'otkazan'),
                  )
                  .length;
            }
            return PutnikCard(
              putnik: putnik,
              showActions: showActions,
              currentDriver: currentDriver,
              redniBroj: redniBroj,
              bcVremena: bcVremena,
              vsVremena: vsVremena,
              selectedGrad: selectedGrad, // 📍 NOVO: za GPS navigaciju
              selectedVreme: selectedVreme, // 📍 NOVO: za GPS navigaciju
              onChanged: onPutnikStatusChanged, // 🎯 NOVO
              onPokupljen: onPokupljen, // 🔊 glasovna najava
            );
          },
        );
      }

      // 🎯 SORTIRAJ PO GRUPAMA: 1-BELI, 2-PLAVI, 3-ZELENI, 4-CRVENI, 5-ŽUTI
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
          // Redni broj: broji samo one koji nisu otkazani i nisu na odsustvu
          int? redniBroj;
          if (!putnik.jeOdsustvo &&
              !(putnik.status?.toLowerCase() == 'otkazano' || putnik.status?.toLowerCase() == 'otkazan')) {
            // nije CRVENA (otkazana) ili ŽUTA (odsustvo)
            // Broji koliko je neotkazanih i ne-odsutnih putnika pre ovog
            redniBroj = filteredPutnici
                .take(index + 1)
                .where(
                  (p) =>
                      !p.jeOdsustvo && !(p.status?.toLowerCase() == 'otkazano' || p.status?.toLowerCase() == 'otkazan'),
                )
                .length;
          }
          return PutnikCard(
            putnik: putnik,
            showActions: showActions,
            currentDriver: currentDriver,
            redniBroj: redniBroj,
            bcVremena: bcVremena,
            vsVremena: vsVremena,
            selectedGrad: selectedGrad, // 📍 NOVO: za GPS navigaciju
            selectedVreme: selectedVreme, // 📍 NOVO: za GPS navigaciju
            onChanged: onPutnikStatusChanged, // 🎯 NOVO
            onPokupljen: onPokupljen, // 🔊 glasovna najava
          );
        },
      );
    } else {
      return const Center(child: Text('Nema podataka.'));
    }
  }
}
