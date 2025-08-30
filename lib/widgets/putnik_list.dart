import 'package:flutter/material.dart';
import '../models/putnik.dart';
import '../utils/text_utils.dart';
import 'putnik_card.dart';

/// Widget koji prikazuje listu putnika koristeći PutnikCard za svaki element.

class PutnikList extends StatelessWidget {
  final bool showActions;
  final String? currentDriver;
  final Stream<List<Putnik>>? putniciStream;
  final List<Putnik>? putnici;
  final List<String>? bcVremena;
  final List<String>? vsVremena;

  const PutnikList({
    Key? key,
    this.putnici,
    this.putniciStream,
    this.showActions = true,
    this.currentDriver,
    this.bcVremena,
    this.vsVremena,
  }) : super(key: key);

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
          // Sortiranje po prioritetu:
          // 1) Nepokupljeni (bele)
          // 2) Pokupljeni neplaćeni (plave)
          // 3) Pokupljeni plaćeni/sa mesečnom (zelene)
          // 4) Otkazani (crvene)
          int putnikSortKey(Putnik p) {
            final status = TextUtils.normalizeText(p.status ?? '');

            // Prvo proveravamo status
            if (status == 'otkazano' || status == 'otkazan') {
              return 4; // crvene na dno liste
            }

            // MESEČNI PUTNICI
            if (p.mesecnaKarta == true) {
              // Koristi vremePokupljenja za determininaciju stanja
              return p.vremePokupljenja == null ? 0 : 3; // bela ili zelena
            }

            // OBIČNI PUTNICI
            if (p.vremePokupljenja == null) return 0; // bela
            if (p.vremePokupljenja != null &&
                (p.iznosPlacanja == null || p.iznosPlacanja == 0)) {
              return 1; // plava
            }
            if (p.vremePokupljenja != null &&
                (p.iznosPlacanja != null && p.iznosPlacanja! > 0)) {
              return 2; // zelena
            }
            return 99;
          }

          // 🎯 NOVO: Ako je lista reorderovana, koristi optimized route redosled
          List<Putnik> prikaz;
          // Standardno sortiranje
          filteredPutnici.sort((a, b) {
            final cmp = putnikSortKey(a).compareTo(putnikSortKey(b));
            if (cmp != 0) return cmp;
            // Ako su u istoj grupi, zadrži redosled iz baze/streama
            return 0;
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
              if (!(putnik.status?.toLowerCase() == 'otkazano' ||
                  putnik.status?.toLowerCase() == 'otkazan')) {
                // Redni broj je pozicija među svim neotkazanim putnicima
                redniBroj = prikaz
                    .take(index + 1)
                    .where((p) => !(p.status?.toLowerCase() == 'otkazano' ||
                        p.status?.toLowerCase() == 'otkazan'))
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
      // Nova logika sortiranja:
      // 1) Nepokupljeni (bele kartice)
      // 2) Pokupljeni neplaćeno (plave kartice)
      // 3) Pokupljeni mesečne i pokupljeni plaćeno (zelene kartice)
      // 4) Otkazani (crvene kartice)
      final nepokupljeni = filteredPutnici
          .where((p) =>
              (p.status?.toLowerCase() != 'otkazano' &&
                  p.status?.toLowerCase() != 'otkazan') &&
              (p.vremePokupljenja == null))
          .toList();
      final pokupNeplaceno = filteredPutnici
          .where((p) =>
              (p.status?.toLowerCase() != 'otkazano' &&
                  p.status?.toLowerCase() != 'otkazan') &&
              (p.vremePokupljenja != null) &&
              (p.mesecnaKarta != true) &&
              ((p.iznosPlacanja == null || p.iznosPlacanja == 0)))
          .toList();
      final pokupZeleni = filteredPutnici
          .where((p) =>
              (p.status?.toLowerCase() != 'otkazano' &&
                  p.status?.toLowerCase() != 'otkazan') &&
              (p.vremePokupljenja != null) &&
              (p.mesecnaKarta == true ||
                  (p.iznosPlacanja != null && p.iznosPlacanja! > 0)))
          .toList();
      final otkazani = filteredPutnici
          .where((p) => (p.status?.toLowerCase() == 'otkazano' ||
              p.status?.toLowerCase() == 'otkazan'))
          .toList();
      final prikaz = [
        ...nepokupljeni,
        ...pokupNeplaceno,
        ...pokupZeleni,
        ...otkazani
      ];
      if (prikaz.isEmpty) {
        return const Center(child: Text('Nema putnika za prikaz.'));
      }
      return ListView.builder(
        itemCount: prikaz.length,
        itemBuilder: (context, index) {
          final putnik = prikaz[index];
          final redniBroj = index <
                  (nepokupljeni.length +
                      pokupNeplaceno.length +
                      pokupZeleni.length)
              ? index + 1
              : null;
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
