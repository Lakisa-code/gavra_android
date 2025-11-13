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
  }) : super(key: key);
  final bool showActions;
  final String? currentDriver;
  final Stream<List<Putnik>>? putniciStream;
  final List<Putnik>? putnici;
  final List<String>? bcVremena;
  final List<String>? vsVremena;

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
          // Sortiranje po novom prioritetu (VIZUELNI REDOSLED U LISTI):
          // 1) BELE - Nepokupljeni (na vrhu)
          // 2) PLAVE - Pokupljeni neplaćeni
          // 3) ZELENE - Pokupljeni plaćeni/sa mesečnom
          // 4) CRVENE - Otkazani
          // 5) ŽUTE - Odsustvo (godišnji/bolovanje) (na dnu)
          int putnikSortKey(Putnik p) {
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

          // 🎯 NOVO: Ako je lista reorderovana, koristi optimized route redosled
          List<Putnik> prikaz;
          // Standardno sortiranje
          filteredPutnici.sort((a, b) {
            final cmp = putnikSortKey(a).compareTo(putnikSortKey(b));
            if (cmp != 0) return cmp;
            // Ako su u istoj grupi, sortiraj alfabetski po imenu
            return a.ime.compareTo(b.ime);
          });
          prikaz = filteredPutnici;
          if (prikaz.isEmpty) {
            return const Center(child: Text('Nema putnika za prikaz.'));
          }
          return ListView.builder(
            itemCount: prikaz.length,
            itemBuilder: (context, index) {
              final putnik = prikaz[index];
              // Redni broj: broji samo one koji nisu otkazani
              int? redniBroj;
              if (!(putnik.status?.toLowerCase() == 'otkazano' || putnik.status?.toLowerCase() == 'otkazan')) {
                // Redni broj je pozicija među svim neotkazanim putnicima
                redniBroj = prikaz
                    .take(index + 1)
                    .where(
                      (p) => !(p.status?.toLowerCase() == 'otkazano' || p.status?.toLowerCase() == 'otkazan'),
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

      final bele = filteredPutnici
          .where(
            (p) =>
                !p.jeOdsustvo && // nije na odsustvu
                (p.status?.toLowerCase() != 'otkazano' && p.status?.toLowerCase() != 'otkazan') &&
                (p.vremePokupljenja == null),
          )
          .toList()
        ..sort((a, b) => a.ime.compareTo(b.ime)); // Alfabetsko sortiranje

      final plave = filteredPutnici
          .where(
            (p) =>
                !p.jeOdsustvo && // nije na odsustvu
                (p.status?.toLowerCase() != 'otkazano' && p.status?.toLowerCase() != 'otkazan') &&
                (p.vremePokupljenja != null) &&
                (p.mesecnaKarta != true) &&
                ((p.iznosPlacanja == null || p.iznosPlacanja == 0)),
          )
          .toList()
        ..sort((a, b) => a.ime.compareTo(b.ime)); // Alfabetsko sortiranje

      final zelene = filteredPutnici
          .where(
            (p) =>
                !p.jeOdsustvo && // nije na odsustvu
                (p.status?.toLowerCase() != 'otkazano' && p.status?.toLowerCase() != 'otkazan') &&
                (p.vremePokupljenja != null) &&
                (p.mesecnaKarta == true || (p.iznosPlacanja != null && p.iznosPlacanja! > 0)),
          )
          .toList()
        ..sort((a, b) => a.ime.compareTo(b.ime)); // Alfabetsko sortiranje

      final crvene = filteredPutnici
          .where(
            (p) =>
                !p.jeOdsustvo && // nije na odsustvu
                (p.status?.toLowerCase() == 'otkazano' || p.status?.toLowerCase() == 'otkazan'),
          )
          .toList()
        ..sort((a, b) => a.ime.compareTo(b.ime)); // Alfabetsko sortiranje

      final zute = filteredPutnici
          .where((p) => p.jeOdsustvo) // na odsustvu (godišnji/bolovanje)
          .toList()
        ..sort((a, b) => a.ime.compareTo(b.ime)); // Alfabetsko sortiranje

      final prikaz = [
        ...bele, // 1. BELE na vrhu
        ...plave, // 2. PLAVE
        ...zelene, // 3. ZELENE
        ...crvene, // 4. CRVENE
        ...zute, // 5. ŽUTE na dnu
      ];
      if (prikaz.isEmpty) {
        return const Center(child: Text('Nema putnika za prikaz.'));
      }
      return ListView.builder(
        itemCount: prikaz.length,
        itemBuilder: (context, index) {
          final putnik = prikaz[index];
          // Redni broj: broji samo BELE + PLAVE + ZELENE (ne broji CRVENE i ŽUTE)
          int? redniBroj;
          if (!putnik.jeOdsustvo && // nije ŽUTA (odsustvo)
              !(putnik.status?.toLowerCase() == 'otkazano' || putnik.status?.toLowerCase() == 'otkazan')) {
            // nije CRVENA (otkazana)
            // Broji koliko je neotkazanih i ne-odsutnih putnika pre ovog
            redniBroj = prikaz
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
          );
        },
      );
    } else {
      return const Center(child: Text('Nema podataka.'));
    }
  }
}
