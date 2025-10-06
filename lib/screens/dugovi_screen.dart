import 'package:flutter/material.dart';
import '../models/putnik.dart';
import '../widgets/putnik_list.dart';
import '../services/putnik_service.dart';
import '../widgets/custom_back_button.dart';

class DugoviScreen extends StatefulWidget {
  const DugoviScreen({Key? key, this.currentDriver}) : super(key: key);
  final String? currentDriver;

  @override
  State<DugoviScreen> createState() => _DugoviScreenState();
}

class _DugoviScreenState extends State<DugoviScreen> {
  // final PutnikService _putnikService = PutnikService();

  @override
  void initState() {
    super.initState();
    // _currentDriver = widget.currentDriver; // Removed unused assignment
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const GradientBackButton(),
        automaticallyImplyLeading: false,
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
        stream: PutnikService().streamKombinovaniPutniciFiltered(
          isoDate: DateTime.now().toIso8601String().split('T')[0],
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Pronađi dužnike

          // Dužnik je onaj koji je pokupljen i nije platio (iznosPlacanja == null ili 0) - SVI DUŽNICI
          final duznici = snapshot.data!
              .where(
                (p) =>
                    (p.iznosPlacanja == null || p.iznosPlacanja == 0) &&
                    (p.jePokupljen) &&
                    (p.status == null ||
                        (p.status != 'Otkazano' && p.status != 'otkazan')) &&
                    (p.mesecnaKarta != true),
              )
              // Uklonjeno ograničenje na trenutnog vozača - prikaži SVE dužnike
              .toList();

          // Sortiraj po vremenu pokupljenja (najnoviji prvi)
          duznici.sort((a, b) {
            final aTime = a.vremePokupljenja;
            final bTime = b.vremePokupljenja;

            // Ako nemaju vreme pokupljenja, stavi ih na kraj
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1; // a ide na kraj
            if (bTime == null) return -1; // b ide na kraj

            return bTime.compareTo(aTime); // najnoviji prvo
          });
          if (duznici.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 48),
                  SizedBox(height: 8),
                  Text(
                    'Nema neplaćenih putnika!',
                    style: TextStyle(color: Colors.green, fontSize: 16),
                  ),
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
