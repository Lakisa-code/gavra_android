import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/putnik.dart';
import '../services/putnik_service.dart';
import '../services/mesecni_putnik_service.dart';
import '../utils/logging.dart';

/// Coherent PutnikCard implementation (single-file, stateful)
class PutnikCard extends StatefulWidget {
  final Putnik putnik;
  final bool showActions;
  final String? currentDriver;
  final String? selectedVreme;
  final String? selectedGrad;
  final VoidCallback? onChanged;
  final int? redniBroj;
  final List<String>? bcVremena;
  final List<String>? vsVremena;

  const PutnikCard({
    Key? key,
    required this.putnik,
    this.showActions = true,
    this.currentDriver,
    this.selectedVreme,
    this.selectedGrad,
    this.onChanged,
    this.redniBroj,
    this.bcVremena,
    this.vsVremena,
  }) : super(key: key);

  @override
  State<PutnikCard> createState() => _PutnikCardState();
}

class _PutnikCardState extends State<PutnikCard> {
  bool _loading = false;

  void _safeRun(Future<void> Function() fn) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await fn();
    } catch (e, st) {
      dlog('PutnikCard error: $e\n$st');
    } finally {
      if (mounted) setState(() => _loading = false);
      widget.onChanged?.call();
    }
  }

  void _togglePaid() {
    _safeRun(() async {
      final putnik = widget.putnik;
      final currentDriver = widget.currentDriver;
      if (currentDriver == null || currentDriver.isEmpty) {
        dlog('Cannot mark paid: currentDriver not set');
        return;
      }

      if (putnik.mesecnaKarta == true) {
        // For monthly passengers, update payment for current month using MesecniPutnikService
        final iznos = putnik.iznosPlacanja ?? 0.0;
        final now = DateTime.now();
        final pocetakMeseca = DateTime(now.year, now.month, 1);
        final krajMeseca = DateTime(now.year, now.month + 1, 0);
        await MesecniPutnikService.azurirajPlacanjeZaMesec(
          putnik.id.toString(),
          iznos,
          currentDriver,
          pocetakMeseca,
          krajMeseca,
        );
        dlog('Marked monthly paid for ${putnik.ime}');
      } else {
        // Ordinary passenger: mark payment using PutnikService
        final iznos = putnik.iznosPlacanja ?? 0.0;
        await PutnikService()
            .oznaciPlaceno(putnik.id ?? '', iznos, currentDriver);
        dlog('Marked paid for ${putnik.ime}');
      }
    });
  }

  void _togglePickedUp() {
    _safeRun(() async {
      final putnik = widget.putnik;
      final currentDriver = widget.currentDriver;
      if (currentDriver == null || currentDriver.isEmpty) {
        dlog('Cannot mark picked up: currentDriver not set');
        return;
      }
      await PutnikService().oznaciPokupljen(putnik.id ?? '', currentDriver);
      dlog('Marked picked up for ${putnik.ime}');
    });
  }

  void _resetCard() {
    _safeRun(() async {
      await PutnikService()
          .resetPutnikCard(widget.putnik.ime, widget.currentDriver ?? '');
      dlog('Reset card for ${widget.putnik.ime}');
    });
  }

  void _callNumber() {
    final phone = widget.putnik.brojTelefona;
    if (phone == null || phone.isEmpty) {
      dlog('No phone number for ${widget.putnik.ime}');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    dlog('Opening dialer for $phone');
    launchUrl(uri);
  }

  void _sendSMS() {
    final phone = widget.putnik.brojTelefona;
    if (phone == null || phone.isEmpty) {
      dlog('No phone number for ${widget.putnik.ime}');
      return;
    }
    final uri = Uri(scheme: 'sms', path: phone);
    dlog('Opening SMS app for $phone');
    launchUrl(uri);
  }

  void _deletePutnik() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrda brisanja'),
        content: Text('Da li želite da obrišete ${widget.putnik.ime}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Otkaži')),
          TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _safeRun(() async {
                  await PutnikService().obrisiPutnika(widget.putnik.id ?? '');
                  dlog('Deleted ${widget.putnik.ime}');
                });
              },
              child: const Text('Obriši')),
        ],
      ),
    );
  }

  void _confirmAndReset() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrda resetovanja'),
        content:
            Text('Da li želite da resetujete karticu za ${widget.putnik.ime}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Otkaži')),
          TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _resetCard();
              },
              child: const Text('Resetuj')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final putnik = widget.putnik;
    final titleText = widget.redniBroj != null
        ? '${widget.redniBroj}. ${putnik.ime}'
        : putnik.ime;
    Color? tileColor;
    if (putnik.jeOdsustvo) {
      tileColor = Colors.amber[100];
    } else if (putnik.status?.toLowerCase() == 'otkazano' ||
        putnik.status?.toLowerCase() == 'otkazan') {
      tileColor = Colors.red[50];
    } else if (putnik.vremePokupljenja == null) {
      tileColor = Colors.white;
    } else if (putnik.iznosPlacanja == null || putnik.iznosPlacanja == 0) {
      tileColor = Colors.blue[50];
    } else {
      tileColor = Colors.green[50];
    }

    return Card(
      color: tileColor,
      child: ListTile(
        title: Text(titleText),
        subtitle: Text('${putnik.grad} • ${putnik.polazak}'),
        trailing: widget.showActions
            ? PopupMenuButton<String>(
                onSelected: (val) {
                  switch (val) {
                    case 'paid':
                      _togglePaid();
                      break;
                    case 'picked':
                      _togglePickedUp();
                      break;
                    case 'reset':
                      _confirmAndReset();
                      break;
                    case 'call':
                      _callNumber();
                      break;
                    case 'sms':
                      _sendSMS();
                      break;
                    case 'delete':
                      _deletePutnik();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'paid', child: Text('Označi plaćeno')),
                  const PopupMenuItem(
                      value: 'picked', child: Text('Označi pokupljen')),
                  const PopupMenuItem(value: 'reset', child: Text('Resetuj')),
                  const PopupMenuItem(value: 'call', child: Text('Pozovi')),
                  const PopupMenuItem(value: 'sms', child: Text('Pošalji SMS')),
                  const PopupMenuItem(value: 'delete', child: Text('Obriši')),
                ],
              )
            : null,
        isThreeLine: false,
        onTap: widget.onChanged,
      ),
    );
  }
}
