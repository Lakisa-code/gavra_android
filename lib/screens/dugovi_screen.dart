import 'package:flutter/material.dart';
import '../models/putnik.dart';
import '../widgets/putnik_list.dart';
import '../services/putnik_service.dart';

class DugoviScreen extends StatefulWidget {
  final String? currentDriver;
  const DugoviScreen({Key? key, this.currentDriver}) : super(key: key);

  @override
  State<DugoviScreen> createState() => _DugoviScreenState();
}

class _DugoviScreenState extends State<DugoviScreen> {
  // final PutnikService _putnikService = PutnikService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
        ),
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.white),
        title: const Text(
          'Dužnici',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1.2,
            shadows: [
              Shadow(color: Colors.black26, blurRadius: 4),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<Putnik>>(
        stream: PutnikService().streamKombinovaniPutnici(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final danas = DateTime.now();
          final danasString =
              "${danas.day.toString().padLeft(2, '0')}.${danas.month.toString().padLeft(2, '0')}.${danas.year}";

          print('🔍 DUGOVI DEBUG: Tražim dužnike za datum: $danasString');
          print(
              '🔍 DUGOVI DEBUG: Ukupno putnika u stream-u: ${snapshot.data!.length}');

          // Ispišimo sve putnike za debug
          for (final p in snapshot.data!) {
            if (p.ime.contains('TESTDODAO') || p.ime.contains('KURAPAL')) {
              print(
                  '🔍 DUGOVI DEBUG: ${p.ime} - dan: "${p.dan}", jePokupljen: ${p.jePokupljen}, iznosPlacanja: ${p.iznosPlacanja}, mesecnaKarta: ${p.mesecnaKarta}, status: "${p.status}"');
            }
          }

          // Dužnik je onaj koji je pokupljen i nije platio (iznosPlacanja == null ili 0) - PRIVREMENO BEZ DATUMA
          final duznici = snapshot.data!
              .where((p) =>
                  (p.iznosPlacanja == null || p.iznosPlacanja == 0) &&
                  (p.jePokupljen) &&
                  (p.status == null ||
                      (p.status != 'Otkazano' && p.status != 'otkazan')) &&
                  (p.mesecnaKarta != true))
              // (p.dan == danasString)) // PRIVREMENO ISKLJUČEN FILTER ZA DATUM
              .toList();

          // Sortiraj po datumu i vremenu pokupljenja (najnoviji prvi)
          duznici.sort((a, b) {
            // Prvo poredi po vremenu pokupljenja
            if (a.vremePokupljenja != null && b.vremePokupljenja != null) {
              return b.vremePokupljenja!.compareTo(a.vremePokupljenja!);
            }
            // Ako nema vremena pokupljenja, sortiraj po datumu
            if (a.dan != b.dan) {
              return b.dan.compareTo(a.dan);
            }
            // Kao poslednju opciju, sortiraj po imenu
            return a.ime.compareTo(b.ime);
          });

          // Sortiraj po datumu i vremenu (najnoviji prvi)
          duznici.sort((a, b) {
            final aTime = a.vremeDodavanja ?? DateTime(1970);
            final bTime = b.vremeDodavanja ?? DateTime(1970);
            return bTime.compareTo(aTime); // Obrnut redosled - najnoviji prvi
          });

          print('🔍 DUGOVI DEBUG: Pronađeno dužnika: ${duznici.length}');
          for (final d in duznici) {
            print('🔍 DUGOVI DEBUG: Dužnik: ${d.ime}');
          }
          if (duznici.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 48),
                  SizedBox(height: 8),
                  Text('Nema neplaćenih putnika!',
                      style: TextStyle(color: Colors.green, fontSize: 16)),
                ],
              ),
            );
          }
          return PutnikList(
            putnici: duznici,
            currentDriver: widget.currentDriver,
          );
        },
      ),
    );
  }
}
