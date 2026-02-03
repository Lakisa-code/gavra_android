import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/pin_zahtev_service.dart';
import '../theme.dart';

/// 📋 PIN ZAHTEVI SCREEN
/// Admin vidi sve zahteve za PIN i može da odobri/odbije
class PinZahteviScreen extends StatefulWidget {
  const PinZahteviScreen({super.key});

  @override
  State<PinZahteviScreen> createState() => _PinZahteviScreenState();
}

class _PinZahteviScreenState extends State<PinZahteviScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: PinZahtevService.streamZahteviKojiCekaju(),
      builder: (context, snapshot) {
        final zahtevi = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting && zahtevi.isEmpty;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('📋 PIN Zahtevi', style: TextStyle(fontWeight: FontWeight.bold)),
            automaticallyImplyLeading: false,
          ),
          body: Container(
            decoration: BoxDecoration(gradient: Theme.of(context).backgroundGradient),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : zahtevi.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nema zahteva na čekanju.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: zahtevi.length,
                                itemBuilder: (context, index) {
                                  final zahtev = zahtevi[index];
                                  return _buildZahtevCard(zahtev);
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Generiši random 4-cifreni PIN
  String _generatePin() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  /// Pošalji PIN putem SMS-a
  Future<void> _posaljiPinSms(String brojTelefona, String pin, String ime) async {
    final message = 'Vaš PIN za aplikaciju Gavra 013 je: $pin\n'
        'Koristite ovaj PIN zajedno sa brojem telefona za pristup.\n'
        '- Gavra 013';

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: brojTelefona,
      queryParameters: {'body': message},
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ne mogu da otvorim SMS aplikaciju'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri otvaranju SMS: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Odobri zahtev i dodeli PIN
  Future<void> _odobriZahtev(Map<String, dynamic> zahtev) async {
    final zahtevId = zahtev['id'] as String;
    final putnik = zahtev['registrovani_putnici'] as Map<String, dynamic>?;
    final ime = putnik?['putnik_ime'] ?? '';
    final brojTelefona = putnik?['broj_telefona'] as String? ?? zahtev['telefon'] as String? ?? '';

    final generisaniPin = _generatePin();
    final pinController = TextEditingController(text: generisaniPin);

    final rezultat = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.vpn_key, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(child: Text('Dodeli PIN za $ime', style: const TextStyle(color: Colors.white, fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 12),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '0000',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                pinController.text = _generatePin();
              },
              icon: const Icon(Icons.refresh, color: Colors.amber),
              label: const Text('Generiši novi', style: TextStyle(color: Colors.amber)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Odustani', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (pinController.text.length == 4) {
                Navigator.pop(context, pinController.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN mora imati 4 cifre'), backgroundColor: Colors.orange),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Dodeli PIN', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (rezultat != null) {
      final success = await PinZahtevService.odobriZahtev(
        zahtevId: zahtevId,
        pin: rezultat,
      );

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ PIN $rezultat dodeljen putniku $ime'),
            backgroundColor: Colors.green,
          ),
        );
        // Automatski otvori SMS da pošalje PIN
        if (brojTelefona.isNotEmpty) {
          await _posaljiPinSms(brojTelefona, rezultat, ime);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Greška pri dodeli PIN-a'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Odbij zahtev
  Future<void> _odbijZahtev(Map<String, dynamic> zahtev) async {
    final zahtevId = zahtev['id'] as String;
    final putnik = zahtev['registrovani_putnici'] as Map<String, dynamic>?;
    final ime = putnik?['putnik_ime'] ?? '';

    final potvrda = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Odbij zahtev?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Da li sigurno želite da odbijete zahtev za PIN od putnika $ime?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Odustani', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Odbij', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (potvrda == true) {
      final success = await PinZahtevService.odbijZahtev(zahtevId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zahtev od $ime je odbijen'), backgroundColor: Colors.orange),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Greška pri odbijanju'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildZahtevCard(Map<String, dynamic> zahtev) {
    final putnik = zahtev['registrovani_putnici'] as Map<String, dynamic>?;

    final ime = putnik?['putnik_ime'] ?? '';
    final telefon = zahtev['telefon'] ?? putnik?['broj_telefona'] ?? '-';
    final email = zahtev['email'] ?? putnik?['email'] ?? '-';
    final tip = putnik?['tip'] ?? '-';
    final createdAt = zahtev['created_at'] as String?;

    String vremeZahteva = '-';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) {
        vremeZahteva = '${dt.day}.${dt.month}.${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return Card(
      color: const Color(0xFF1a1a2e),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - ime i tip
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.amber.withValues(alpha: 0.2),
                  child: Text(
                    ime.isNotEmpty ? ime[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        tip == 'radnik'
                            ? '👷 Radnik'
                            : tip == 'ucenik'
                                ? '🎓 Učenik'
                                : tip,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⏳ Čeka',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info redovi
            _buildInfoRow(Icons.phone, 'Telefon', telefon),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.email, 'Email', email),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.access_time, 'Zahtev poslat', vremeZahteva),

            const SizedBox(height: 16),

            // Akcije
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _odbijZahtev(zahtev),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Odbij'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _odobriZahtev(zahtev),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Dodeli PIN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 18),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
