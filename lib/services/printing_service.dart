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
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/grad_adresa_validator.dart';
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

  static Future<void> printPutniksList(
    String selectedDay,
    String selectedVreme,
    String selectedGrad,
    BuildContext context,
  ) async {
    try {
      String? isoDate;
      try {
        isoDate = DateTime.now().toIso8601String().split('T')[0];
      } catch (e) {
        debugPrint('⚠️ Error parsing ISO date for printing: $e');
        isoDate = DateTime.now().toIso8601String().split('T')[0];
      }

      List<Putnik> sviPutnici = await _putnikService
          .streamKombinovaniPutniciFiltered(
            isoDate: isoDate,
            grad: selectedGrad,
            vreme: selectedVreme,
          )
          .first;

      String getDayAbbreviation(String fullDayName) {
        return app_date_utils.DateUtils.getDayAbbreviation(fullDayName);
      }

      String normalizeTime(String? time) {
        if (time == null || time.isEmpty) return '';

        String normalized = time.trim();

        if (normalized.contains(':') && normalized.split(':').length == 3) {
          List<String> parts = normalized.split(':');
          normalized = '${parts[0]}:${parts[1]}';
        }

        if (normalized.startsWith('0')) {
          normalized = normalized.substring(1);
        }

        return normalized;
      }

      final danBaza = getDayAbbreviation(selectedDay);

      List<Putnik> putnici = sviPutnici.where((putnik) {
        final normalizedStatus = TextUtils.normalizeText(putnik.status ?? '');

        if (putnik.mesecnaKarta == true) {
          final normalizedPutnikGrad = TextUtils.normalizeText(putnik.grad);
          final normalizedGrad = TextUtils.normalizeText(selectedGrad);
          final odgovarajuciGrad =
              normalizedPutnikGrad.contains(normalizedGrad) || normalizedGrad.contains(normalizedPutnikGrad);

          final putnikPolazak = putnik.polazak.toString().trim();
          final selectedVremeStr = selectedVreme.trim();
          final odgovarajuciPolazak = normalizeTime(putnikPolazak) == normalizeTime(selectedVremeStr) ||
              (normalizeTime(putnikPolazak).startsWith(normalizeTime(selectedVremeStr)));

          final odgovarajuciDan = putnik.dan.toLowerCase().contains(danBaza.toLowerCase());

          final result = odgovarajuciGrad && odgovarajuciPolazak && odgovarajuciDan && normalizedStatus != 'obrisan';

          return result;
        } else {
          final normalizedPutnikGrad = TextUtils.normalizeText(putnik.grad);
          final normalizedGrad = TextUtils.normalizeText(selectedGrad);
          final gradMatch =
              normalizedPutnikGrad.contains(normalizedGrad) || normalizedGrad.contains(normalizedPutnikGrad);

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

      await _loadFonts();

      final pdf = await _createPutniksPDF(
        putnici,
        selectedDay,
        selectedVreme,
        selectedGrad,
      );

      final bytes = pdf;
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'Spisak_putnika_${selectedDay}_${selectedVreme}_${selectedGrad}_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.pdf'
              .replaceAll(' ', '_');
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

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

  static Future<Uint8List> _createPutniksPDF(
    List<Putnik> putnici,
    String selectedDay,
    String selectedVreme,
    String selectedGrad,
  ) async {
    final pdf = pw.Document();

    putnici.sort((a, b) => a.ime.compareTo(b.ime));

    String relacija = _odredjiRelaciju(selectedGrad, selectedVreme);

    final danas = DateFormat('dd.MM.yyyy').format(DateTime.now());

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

  static String _odredjiRelaciju(String grad, String vreme) {
    if (GradAdresaValidator.isBelaCrkva(grad)) {
      return 'Bela Crkva - Vršac';
    } else if (GradAdresaValidator.isVrsac(grad)) {
      return 'Vršac - Bela Crkva';
    }
    return '$grad - ______';
  }

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
