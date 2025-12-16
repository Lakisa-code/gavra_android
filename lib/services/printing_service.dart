// 'dart:typed_data' not required; elements available via Flutter packages
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/putnik.dart';
import '../services/putnik_service.dart';
import '../utils/text_utils.dart';

class PrintingService {
  static final PutnikService _putnikService = PutnikService();

  // ========== FONTOVI SA PODRŠKOM ZA SRPSKA SLOVA ==========
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  static Future<void> _loadFonts() async {
    if (_regularFont == null) {
      final regularData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      _regularFont = pw.Font.ttf(regularData);
    }
    if (_boldFont == null) {
      final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      _boldFont = pw.Font.ttf(boldData);
    }
  }

  // Use centralized logger

  /// Štampa spisak putnika za selektovani dan i vreme
  static Future<void> printPutniksList(
    String selectedDay,
    String selectedVreme,
    String selectedGrad,
    BuildContext context,
  ) async {
    try {
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
              normalizedPutnikGrad.contains(normalizedGrad) || normalizedGrad.contains(normalizedPutnikGrad);

          // Poređenje vremena - normalizuj oba formata
          final putnikPolazak = putnik.polazak.toString().trim();
          final selectedVremeStr = selectedVreme.trim();
          final odgovarajuciPolazak = normalizeTime(putnikPolazak) == normalizeTime(selectedVremeStr) ||
              (normalizeTime(putnikPolazak).startsWith(normalizeTime(selectedVremeStr)));

          // DODAJ FILTRIRANJE PO DANU I ZA MESEČNE PUTNIKE
          final odgovarajuciDan = putnik.dan.toLowerCase().contains(danBaza.toLowerCase());

          final result = odgovarajuciGrad && odgovarajuciPolazak && odgovarajuciDan && normalizedStatus != 'obrisan';

          return result;
        } else {
          // DNEVNI/OBIČNI PUTNICI - standardno filtriranje
          final normalizedPutnikGrad = TextUtils.normalizeText(putnik.grad);
          final normalizedGrad = TextUtils.normalizeText(selectedGrad);
          final gradMatch =
              normalizedPutnikGrad.contains(normalizedGrad) || normalizedGrad.contains(normalizedPutnikGrad);

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

      // Učitaj fontove sa podrškom za srpska slova
      await _loadFonts();

      // Kreiraj PDF dokument
      final pdf = await _createPutniksPDF(
        putnici,
        selectedDay,
        selectedVreme,
        selectedGrad,
      );

      // Save PDF to a local temporary file and open it.
      // `_createPutniksPDF` already returns `Uint8List` bytes
      final bytes = pdf;
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'Spisak_putnika_${selectedDay}_${selectedVreme}_${selectedGrad}_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.pdf'
              .replaceAll(' ', '_');
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      // Open the generated PDF using platform default viewer (Android will show print/share options)
      await OpenFilex.open(file.path);
    } catch (e) {
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

  /// Kreira PDF dokument sa spiskom putnika - IDENTIČNO KAO PAPIRNI NALOG
  static Future<Uint8List> _createPutniksPDF(
    List<Putnik> putnici,
    String selectedDay,
    String selectedVreme,
    String selectedGrad,
  ) async {
    final pdf = pw.Document();

    // Sortiraj putnike po imenu
    putnici.sort((a, b) => a.ime.compareTo(b.ime));

    // Odredi relaciju na osnovu grada i vremena
    String relacija = _odredjiRelaciju(selectedGrad, selectedVreme);

    // Danas datum
    final danas = DateFormat('dd.MM.yyyy').format(DateTime.now());

    // Kreiraj temu sa fontovima koji podržavaju srpska slova
    final theme = pw.ThemeData.withFont(
      base: _regularFont,
      bold: _boldFont,
      italic: _regularFont,
      boldItalic: _boldFont,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ========== ZAGLAVLJE ==========
              pw.Center(
                child: pw.Text(
                  'Limo servis "Gavra 013"',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'PIB: 102853497; MB: 55572178',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),

              pw.SizedBox(height: 40),

              // ========== PODACI O VOŽNJI ==========
              _buildInfoRow('Datum:', danas),
              pw.SizedBox(height: 8),
              _buildInfoRow('Naručilac:', '______________________'),
              pw.SizedBox(height: 8),
              _buildInfoRow('Relacija:', relacija),
              pw.SizedBox(height: 8),
              _buildInfoRow('Vreme polaska:', selectedVreme),
              pw.SizedBox(height: 8),
              _buildInfoRow('Cena:', '______________________'),

              pw.SizedBox(height: 40),

              // ========== SPISAK PUTNIKA NASLOV ==========
              pw.Center(
                child: pw.Text(
                  'SPISAK PUTNIKA',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 20),

              // ========== LISTA PUTNIKA (1-8 + dodatni ako ima više) ==========
              ...List.generate(
                putnici.length > 8 ? putnici.length : 8,
                (index) {
                  final broj = index + 1;
                  final imePutnika =
                      index < putnici.length ? putnici[index].ime : '______________________________________';
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.SizedBox(
                          width: 30,
                          child: pw.Text(
                            '$broj.',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Container(
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(width: 0.5),
                              ),
                            ),
                            child: pw.Text(
                              imePutnika,
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              pw.Spacer(),

              // ========== POTPISI NA DNU ==========
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Potpis naručioca
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 120,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(width: 0.5),
                          ),
                        ),
                        child: pw.SizedBox(height: 40),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Potpis naručioca',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),

                  // Pečat (sredina)
                  pw.Container(
                    width: 80,
                    height: 80,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.blue,
                        width: 2,
                      ),
                      borderRadius: pw.BorderRadius.circular(40),
                    ),
                    child: pw.Center(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            'Bojan Gavrilović',
                            style: pw.TextStyle(
                              fontSize: 6,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                          pw.Text(
                            'LIMO',
                            style: pw.TextStyle(
                              fontSize: 5,
                              color: PdfColors.blue,
                            ),
                          ),
                          pw.Text(
                            'GAVRA 013',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue,
                            ),
                          ),
                          pw.Text(
                            'Bela Crkva',
                            style: pw.TextStyle(
                              fontSize: 6,
                              color: PdfColors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Potpis prevoznika
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 120,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(width: 0.5),
                          ),
                        ),
                        child: pw.SizedBox(height: 40),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Potpis prevoznika',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Određuje relaciju na osnovu grada
  static String _odredjiRelaciju(String grad, String vreme) {
    final normalizedGrad = grad.toLowerCase();
    // Jutarnji polasci iz BC idu u VS, popodnevni iz VS u BC
    if (normalizedGrad.contains('bela crkva') || normalizedGrad.contains('bc')) {
      return 'Bela Crkva - Vršac';
    } else if (normalizedGrad.contains('vrsac') || normalizedGrad.contains('vs')) {
      return 'Vršac - Bela Crkva';
    }
    return '$grad - ______';
  }

  /// Gradi red sa labelom i vrednošću
  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 12),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
