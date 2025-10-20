// 'dart:typed_data' not required; elements available via Flutter packages
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../models/putnik.dart';
import '../services/putnik_service.dart';
import '../utils/text_utils.dart';

class PrintingService {
  static final PutnikService _putnikService = PutnikService();

  // Use centralized logger

  /// Štampa spisak putnika za selektovani dan i vreme
  static Future<void> printPutniksList(
    String selectedDay,
    String selectedVreme,
    String selectedGrad,
    BuildContext context,
  ) async {
    try {
      // Debug logging removed for production
// ✅ KORISTI ISTI STREAM kao home_screen za tačne podatke
      // Try to compute isoDate from selectedDay (if present) - otherwise leave null
      String? isoDate;
      try {
        // selectedDay is a full name like "Ponedeljak" - map to next matching date (best-effort)
        // Fallback: use today
        isoDate = DateTime.now().toIso8601String().split('T')[0];
      } catch (_) {
        isoDate = DateTime.now().toIso8601String().split('T')[0];
      }

      List<Putnik> sviPutnici = await _putnikService
          .streamKombinovaniPutniciFiltered(
            isoDate: isoDate,
            grad: selectedGrad,
            vreme: selectedVreme,
          )
          .first;

      // Konvertuj pun naziv dana u kraticu za poređenje sa bazom
      String getDayAbbreviation(String fullDayName) {
        switch (fullDayName.toLowerCase()) {
          case 'ponedeljak':
            return 'pon';
          case 'utorak':
            return 'uto';
          case 'sreda':
            return 'sre';
          case 'četvrtak':
            return 'cet';
          case 'petak':
            return 'pet';
          case 'subota':
            return 'sub';
          case 'nedelja':
            return 'ned';
          default:
            return fullDayName.toLowerCase();
        }
      }

      // Normalizuj vreme format - konvertuj "05:00:00" u "5:00"
      String normalizeTime(String? time) {
        if (time == null || time.isEmpty) return '';

        String normalized = time.trim();

        // Ukloni sekunde ako postoje (05:00:00 -> 05:00)
        if (normalized.contains(':') && normalized.split(':').length == 3) {
          List<String> parts = normalized.split(':');
          normalized = '${parts[0]}:${parts[1]}';
        }

        // Ukloni leading zero (05:00 -> 5:00)
        if (normalized.startsWith('0')) {
          normalized = normalized.substring(1);
        }

        return normalized;
      }

      final danBaza = getDayAbbreviation(selectedDay);

      // Filtriraj putnike za selektovani dan, vreme i grad (ISTA LOGIKA KAO U HOMESCREEN)
      List<Putnik> putnici = sviPutnici.where((putnik) {
        final normalizedStatus = TextUtils.normalizeText(putnik.status ?? '');

        // MESEČNI PUTNICI - sada imaju polazak kolonu!
        if (putnik.mesecnaKarta == true) {
          // Mesečni putnici se filtriraju po gradu, polazku, danu i statusu
          final normalizedPutnikGrad = TextUtils.normalizeText(putnik.grad);
          final normalizedGrad = TextUtils.normalizeText(selectedGrad);
          final odgovarajuciGrad =
              normalizedPutnikGrad.contains(normalizedGrad) ||
                  normalizedGrad.contains(normalizedPutnikGrad);

          // Poređenje vremena - normalizuj oba formata
          final putnikPolazak = putnik.polazak.toString().trim();
          final selectedVremeStr = selectedVreme.trim();
          final odgovarajuciPolazak =
              normalizeTime(putnikPolazak) == normalizeTime(selectedVremeStr) ||
                  (normalizeTime(putnikPolazak)
                      .startsWith(normalizeTime(selectedVremeStr)));

          // DODAJ FILTRIRANJE PO DANU I ZA MESEČNE PUTNIKE
          final odgovarajuciDan =
              putnik.dan.toLowerCase().contains(danBaza.toLowerCase());

          final result = odgovarajuciGrad &&
              odgovarajuciPolazak &&
              odgovarajuciDan &&
              normalizedStatus != 'obrisan';

          return result;
        } else {
          // DNEVNI/OBIČNI PUTNICI - standardno filtriranje
          final normalizedPutnikGrad = TextUtils.normalizeText(putnik.grad);
          final normalizedGrad = TextUtils.normalizeText(selectedGrad);
          final gradMatch = normalizedPutnikGrad.contains(normalizedGrad) ||
              normalizedGrad.contains(normalizedPutnikGrad);

          // Konvertuj pun naziv dana u kraticu za poređenje sa bazom
          final odgovara = gradMatch &&
              normalizeTime(putnik.polazak) == normalizeTime(selectedVreme) &&
              putnik.dan.toLowerCase().contains(danBaza.toLowerCase()) &&
              normalizedStatus != 'obrisan';

          return odgovara;
        }
      }).toList();

      if (putnici.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '📄 Nema putnika za $selectedDay - $selectedVreme - $selectedGrad',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Kreiraj PDF dokument
      final pdf = await _createPutniksPDF(
        putnici,
        selectedDay,
        selectedVreme,
        selectedGrad,
      );

      // Otvori pregled za štampanje
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf,
        name:
            'Spisak_putnika_${selectedDay}_${selectedVreme}_${selectedGrad}_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.pdf',
      );
      // Debug logging removed for production
} catch (e) {
      // Debug logging removed for production
if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška pri štampanju: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Kreira PDF dokument sa spiskom putnika
  static Future<Uint8List> _createPutniksPDF(
    List<Putnik> putnici,
    String selectedDay,
    String selectedVreme,
    String selectedGrad,
  ) async {
    final pdf = pw.Document();

    // Grupiši putnike po statusu
    final pokupljeni = putnici.where((p) => p.jePokupljen).toList();
    final otkazani = putnici.where((p) => p.jeOtkazan).toList();
    final cekaju =
        putnici.where((p) => !p.jePokupljen && !p.jeOtkazan).toList();

    // Sortiraj po gradu/destinaciji
    pokupljeni.sort((a, b) => a.grad.compareTo(b.grad));
    otkazani.sort((a, b) => a.grad.compareTo(b.grad));
    cekaju.sort((a, b) => a.grad.compareTo(b.grad));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Zaglavlje
            _buildHeader(
              selectedDay,
              selectedVreme,
              selectedGrad,
              putnici.length,
            ),

            pw.SizedBox(height: 20),

            // Statistike
            _buildStatisticsSection(
              pokupljeni.length,
              otkazani.length,
              cekaju.length,
            ),

            pw.SizedBox(height: 20),

            // Spisak putnika koji čekaju
            if (cekaju.isNotEmpty) ...[
              _buildSectionTitle(
                '🕐 ČEKAJU UKRCAVANJE (${cekaju.length})',
                Colors.orange,
              ),
              pw.SizedBox(height: 10),
              _buildPutnikTable(cekaju),
              pw.SizedBox(height: 20),
            ],

            // Spisak pokupljenih putnika
            if (pokupljeni.isNotEmpty) ...[
              _buildSectionTitle(
                '✅ POKUPLJENI (${pokupljeni.length})',
                Colors.green,
              ),
              pw.SizedBox(height: 10),
              _buildPutnikTable(pokupljeni),
              pw.SizedBox(height: 20),
            ],

            // Spisak otkazanih putnika
            if (otkazani.isNotEmpty) ...[
              _buildSectionTitle('❌ OTKAZANI (${otkazani.length})', Colors.red),
              pw.SizedBox(height: 10),
              _buildPutnikTable(otkazani),
            ],

            pw.SizedBox(height: 30),

            // Footer
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Kreira zaglavlje dokumenta
  static pw.Widget _buildHeader(
    String selectedDay,
    String selectedVreme,
    String selectedGrad,
    int totalCount,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            'GAVRA 013',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Center(
          child: pw.Text(
            'SPISAK PUTNIKA',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Dan: $selectedDay',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Ukupno: $totalCount putnika',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Polazak: $selectedVreme - $selectedGrad',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Datum štampanja: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 12),
            ),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '',
              style: const pw.TextStyle(fontSize: 12),
            ), // Prazan prostor
            pw.Text('Strana 1', style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  /// Kreira sekciju sa statistikama
  static pw.Widget _buildStatisticsSection(
    int pokupljeni,
    int otkazani,
    int cekaju,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            '✅ Pokupljeni',
            pokupljeni.toString(),
            PdfColors.green,
          ),
          _buildStatCard('🕐 Čekaju', cekaju.toString(), PdfColors.orange),
          _buildStatCard('❌ Otkazani', otkazani.toString(), PdfColors.red),
        ],
      ),
    );
  }

  /// Kreira karticu sa statistikom
  static pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Kreira naslov sekcije
  static pw.Widget _buildSectionTitle(String title, Color color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(color.value),
        border: pw.Border.all(color: PdfColor.fromInt(color.value)),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  /// Kreira tabelu sa putnicima
  static pw.Widget _buildPutnikTable(List<Putnik> putnici) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey),
      columnWidths: const {
        0: pw.FixedColumnWidth(30), // #
        1: pw.FlexColumnWidth(3), // Ime
        2: pw.FlexColumnWidth(2), // Polazak
        3: pw.FlexColumnWidth(2), // Destinacija
        4: pw.FixedColumnWidth(60), // Status
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell('#', isHeader: true),
            _buildTableCell('IME', isHeader: true),
            _buildTableCell('POLAZAK', isHeader: true),
            _buildTableCell('DOLAZAK', isHeader: true),
            _buildTableCell('STATUS', isHeader: true),
          ],
        ),
        // Putnici
        ...putnici.asMap().entries.map((entry) {
          int index = entry.key + 1;
          Putnik putnik = entry.value;

          String status = '';
          if (putnik.jePokupljen) {
            status = '✅ Pokupljen';
          } else if (putnik.jeOtkazan) {
            status = '❌ Otkazan';
          } else {
            status = '🕐 Čeka';
          }

          return pw.TableRow(
            children: [
              _buildTableCell(index.toString()),
              _buildTableCell(putnik.ime),
              _buildTableCell(putnik.polazak),
              _buildTableCell(putnik.grad),
              _buildTableCell(status),
            ],
          );
        }).toList(),
      ],
    );
  }

  /// Kreira ćeliju tabele
  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Kreira footer dokumenta
  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'GAVRA 013 - Transport Services',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
            pw.Text(
              'www.gavra013.rs',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          ],
        ),
      ],
    );
  }
}





