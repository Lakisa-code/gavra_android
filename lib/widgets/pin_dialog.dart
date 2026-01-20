import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../globals.dart';
import '../services/admin_audit_service.dart';

/// PIN DIALOG za mesečne putnike
/// Prikazuje/generiše/šalje PIN kod
class PinDialog extends StatefulWidget {
  final String putnikId;
  final String putnikIme;
  final String? trenutniPin;
  final String? brojTelefona;

  const PinDialog({
    Key? key,
    required this.putnikId,
    required this.putnikIme,
    this.trenutniPin,
    this.brojTelefona,
  }) : super(key: key);

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  late String? _pin;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pin = widget.trenutniPin;
  }

  /// Generiši nasumičan 4-cifreni PIN
  String _generatePin() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString(); // 1000-9999
  }

  /// Sačuvaj PIN u bazu
  Future<void> _savePin(String newPin) async {
    setState(() => _isLoading = true);

    try {
      await supabase.from('registrovani_putnici').update({'pin': newPin}).eq('id', widget.putnikId);

      // 🛡️ AUDIT LOG
      final currentUser = supabase.auth.currentUser;
      await AdminAuditService.logAction(
        adminName: currentUser?.email ?? 'Unknown Admin',
        actionType: 'change_pin',
        details: 'Promenjen PIN za putnika: ${widget.putnikIme}',
        metadata: {'putnik_id': widget.putnikId},
      );

      setState(() {
        _pin = newPin;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN sačuvan!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Pošalji PIN putem SMS-a
  Future<void> _sendSms() async {
    if (widget.brojTelefona == null || widget.brojTelefona!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Putnik nema broj telefona!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_pin == null || _pin!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prvo generiši PIN!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final message = 'Vaš PIN za aplikaciju Gavra 013 je: $_pin\n'
        'Koristite ovaj PIN zajedno sa brojem telefona za pristup.\n'
        '- Gavra 013';

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: widget.brojTelefona,
      queryParameters: {'body': message},
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        throw Exception('Ne mogu da otvorim SMS aplikaciju');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Kopiraj PIN u clipboard
  void _copyPin() {
    if (_pin != null && _pin!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _pin!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN kopiran!'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: Row(
        children: [
          const Icon(Icons.lock, color: Colors.amber, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'PIN - ${widget.putnikIme}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Prikaz PIN-a
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Text(
                    _pin ?? 'Nema PIN',
                    style: TextStyle(
                      color: _pin != null ? Colors.amber : Colors.white54,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                  ),
                  if (_pin != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _copyPin,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.copy, color: Colors.white54, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Kopiraj',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dugmad
            Row(
              children: [
                // Generiši PIN
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            final newPin = _generatePin();
                            await _savePin(newPin);
                          },
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(_pin == null ? 'Generiši' : 'Novi PIN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Pošalji SMS
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_pin == null || widget.brojTelefona == null) ? null : _sendSms,
                    icon: const Icon(Icons.sms, size: 18),
                    label: const Text('Pošalji'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            // Info o telefonu
            if (widget.brojTelefona == null || widget.brojTelefona!.isEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Putnik nema broj telefona',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zatvori'),
        ),
      ],
    );
  }
}
