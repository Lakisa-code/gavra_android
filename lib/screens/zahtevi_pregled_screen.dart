import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

/// 📋 ZAHTEVI PREGLED SCREEN
/// Admin pregleda zahteve putnika za registraciju
/// Može da odobri ili odbije zahteve
class ZahteviPregledScreen extends StatefulWidget {
  const ZahteviPregledScreen({Key? key}) : super(key: key);

  @override
  State<ZahteviPregledScreen> createState() => _ZahteviPregledScreenState();
}

class _ZahteviPregledScreenState extends State<ZahteviPregledScreen> {
  List<Map<String, dynamic>> _zahtevi = [];
  bool _isLoading = true;
  String _filter = 'pending'; // pending, approved, rejected, all

  @override
  void initState() {
    super.initState();
    _loadZahtevi();
  }

  Future<void> _loadZahtevi() async {
    setState(() => _isLoading = true);

    try {
      var query = Supabase.instance.client.from('zahtevi_pristupa').select().order('created_at', ascending: false);

      if (_filter != 'all') {
        query = Supabase.instance.client
            .from('zahtevi_pristupa')
            .select()
            .eq('status', _filter)
            .order('created_at', ascending: false);
      }

      final response = await query;
      setState(() {
        _zahtevi = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Greška pri učitavanju zahteva: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _odobriZahtev(Map<String, dynamic> zahtev) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Odobri zahtev?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Odobri ${zahtev['ime']} ${zahtev['prezime']} iz ${zahtev['grad'] == 'BC' ? 'Bele Crkve' : 'Vršca'}?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ne'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Odobri'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. Ažuriraj status u zahtevi_pristupa
        await Supabase.instance.client.from('zahtevi_pristupa').update({'status': 'approved'}).eq('id', zahtev['id']);

        // 2. Dodaj u dnevni_putnici tabelu
        await Supabase.instance.client.from('dnevni_putnici').insert({
          'ime': zahtev['ime'],
          'prezime': zahtev['prezime'],
          'adresa': zahtev['adresa'],
          'telefon': zahtev['telefon'],
          'email': zahtev['email'],
          'grad': zahtev['grad'],
          'aktivan': true,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${zahtev['ime']} ${zahtev['prezime']} odobren!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        await _loadZahtevi();
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
  }

  Future<void> _odbijZahtev(Map<String, dynamic> zahtev) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Odbij zahtev?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Odbij ${zahtev['ime']} ${zahtev['prezime']}?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ne'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Odbij'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('zahtevi_pristupa').update({'status': 'rejected'}).eq('id', zahtev['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${zahtev['ime']} ${zahtev['prezime']} odbijen'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        await _loadZahtevi();
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
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _zahtevi.where((z) => z['status'] == 'pending').length;

    return Container(
      decoration: const BoxDecoration(
        gradient: tripleBlueFashionGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              const Text(
                '📋 Zahtevi putnika',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              if (pendingCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$pendingCount',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadZahtevi,
            ),
          ],
        ),
        body: Column(
          children: [
            // Filter dugmad
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildFilterButton('pending', '⏳ Čekaju', Colors.amber),
                  const SizedBox(width: 8),
                  _buildFilterButton('approved', '✅ Odobreni', Colors.green),
                  const SizedBox(width: 8),
                  _buildFilterButton('rejected', '❌ Odbijeni', Colors.red),
                  const SizedBox(width: 8),
                  _buildFilterButton('all', '📋 Svi', Colors.blue),
                ],
              ),
            ),

            // Lista zahteva
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                  : _zahtevi.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 64,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nema zahteva',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadZahtevi,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _zahtevi.length,
                            itemBuilder: (context, index) {
                              return _buildZahtevCard(_zahtevi[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String value, String label, Color color) {
    final isSelected = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _filter = value);
          _loadZahtevi();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.white24,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildZahtevCard(Map<String, dynamic> zahtev) {
    final status = zahtev['status'] ?? 'pending';
    final createdAt = DateTime.tryParse(zahtev['created_at'] ?? '');
    final dateStr = createdAt != null
        ? '${createdAt.day}.${createdAt.month}.${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '-';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'Odobren';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Odbijen';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.amber;
        statusText = 'Čeka';
        statusIcon = Icons.hourglass_empty;
    }

    return Card(
      color: Colors.white.withValues(alpha: 0.1),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - ime i status
            Row(
              children: [
                Icon(Icons.person, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${zahtev['ime']} ${zahtev['prezime']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Detalji
            _buildDetailRow(Icons.location_city, zahtev['grad'] == 'BC' ? 'Bela Crkva' : 'Vršac'),
            _buildDetailRow(Icons.home, zahtev['adresa'] ?? '-'),
            _buildDetailRow(Icons.phone, zahtev['telefon'] ?? '-'),
            if (zahtev['email'] != null && zahtev['email'].toString().isNotEmpty)
              _buildDetailRow(Icons.email, zahtev['email']),
            if (zahtev['poruka'] != null && zahtev['poruka'].toString().isNotEmpty)
              _buildDetailRow(Icons.message, zahtev['poruka']),
            _buildDetailRow(Icons.access_time, dateStr),

            // Akcije - samo za pending
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _odbijZahtev(zahtev),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Odbij'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _odobriZahtev(zahtev),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Odobri'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
