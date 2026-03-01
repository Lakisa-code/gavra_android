import 'package:flutter/material.dart';

import '../models/v2_polazak.dart';
import '../services/v2_auth_manager.dart';
import '../services/v2_polasci_service.dart';
import '../services/v2_theme_manager.dart';
import '../theme.dart';
import '../utils/v2_app_snack_bar.dart';

class V2PolasciScreen extends StatefulWidget {
  const V2PolasciScreen({super.key});

  @override
  State<V2PolasciScreen> createState() => _V2PolasciScreenState();
}

class _V2PolasciScreenState extends State<V2PolasciScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late final TabController _tabController;

  // Radnici/Učenici — monitoring svih aktivnih statusa
  static const _monitoringStatusi = ['obrada', 'odobreno', 'odbijeno', 'otkazano'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: ThemeManager().currentGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).glassContainer,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).glassBorder, width: 1.5),
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Zahtevi Rezervacija',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildTabBar(),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 0: Dnevni — ručna obrada admina (samo 'obrada' status)
            StreamBuilder<List<V2Polazak>>(
              stream: V2PolasciService.v2StreamZahteviObrada(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                final zahtevi = (snapshot.data ?? []).where((z) {
                  final t = (z.tipPutnika ?? 'dnevni').toLowerCase();
                  return t == 'dnevni' || t == 'manual';
                }).toList();
                return _buildDnevniLista(zahtevi);
              },
            ),

            // Tab 1: Radnici — praćenje toka (svi statusi)
            StreamBuilder<List<V2Polazak>>(
              stream: V2PolasciService.v2StreamZahteviObrada(statusFilter: _monitoringStatusi),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                final zahtevi =
                    (snapshot.data ?? []).where((z) => (z.tipPutnika ?? '').toLowerCase() == 'radnik').toList();
                return _buildMonitoringLista(zahtevi, Colors.teal);
              },
            ),

            // Tab 2: Učenici — praćenje toka (svi statusi)
            StreamBuilder<List<V2Polazak>>(
              stream: V2PolasciService.v2StreamZahteviObrada(statusFilter: _monitoringStatusi),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                final zahtevi =
                    (snapshot.data ?? []).where((z) => (z.tipPutnika ?? '').toLowerCase() == 'ucenik').toList();
                return _buildMonitoringLista(zahtevi, Colors.purple);
              },
            ),
          ],
        ),
      ),
    );
  }

  // TabBar — badge broji samo 'obrada' zahteve (oni koji čekaju akciju)
  Widget _buildTabBar() {
    return StreamBuilder<List<V2Polazak>>(
      stream: V2PolasciService.v2StreamZahteviObrada(),
      builder: (context, snapshot) {
        final svi = snapshot.data ?? [];
        final dnevniCount = svi.where((z) {
          final t = (z.tipPutnika ?? 'dnevni').toLowerCase();
          return t == 'dnevni' || t == 'manual';
        }).length;
        final radnikCount = svi.where((z) => (z.tipPutnika ?? '').toLowerCase() == 'radnik').length;
        final ucenikCount = svi.where((z) => (z.tipPutnika ?? '').toLowerCase() == 'ucenik').length;

        return TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: [
            _buildTab('🎟️ Dnevni', dnevniCount, Colors.blue),
            _buildTab('👷 Radnici', radnikCount, Colors.teal),
            _buildTab('🎓 Učenici', ucenikCount, Colors.purple),
          ],
        );
      },
    );
  }

  Tab _buildTab(String label, int count, Color color) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withOpacity(0.85),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── DNEVNI TAB: admin odobrava/odbija ────────────────────────────────────

  Widget _buildDnevniLista(List<V2Polazak> zahtevi) {
    if (zahtevi.isEmpty) {
      return _buildPrazno('Nema dnevnih zahteva na čekanju');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      itemCount: zahtevi.length,
      itemBuilder: (context, index) => _buildDnevniKartica(zahtevi[index]),
    );
  }

  Widget _buildDnevniKartica(V2Polazak zahtev) {
    final ime = zahtev.putnikIme ?? 'Nepoznat';
    final telefon = zahtev.brojTelefona ?? '';
    final grad = zahtev.grad ?? 'BC';
    final dan = zahtev.dan ?? '';
    final vreme = zahtev.zeljenoVreme ?? '';
    final id = zahtev.id;
    final brojMesta = zahtev.brojMesta;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).glassContainer.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).glassBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ime,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            _tipBadge('🎟️ DNEVNI', Colors.blue),
                            if (brojMesta > 1) _infoBadge('👥 $brojMesta mesta', Colors.purple),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _gradBadge(grad),
                ],
              ),
              if (telefon.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.phone, size: 16, color: Colors.white.withOpacity(0.7)),
                  const SizedBox(width: 8),
                  Text(telefon, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15)),
                ]),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: Colors.white24, height: 1),
              ),
              Row(children: [
                const Icon(Icons.calendar_month, size: 20, color: Colors.amber),
                const SizedBox(width: 10),
                Text('$dan  ($vreme)',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _approveZahtev(id, zahtev),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('ODOBRI', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.9),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _rejectZahtev(id),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('ODBIJ', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ─── RADNICI/UČENICI TAB: monitoring toka ─────────────────────────────────

  Widget _buildMonitoringLista(List<V2Polazak> zahtevi, Color akcentBoja) {
    if (zahtevi.isEmpty) {
      return _buildPrazno('Nema zahteva za prikaz');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      itemCount: zahtevi.length,
      itemBuilder: (context, index) => _buildMonitoringKartica(zahtevi[index], akcentBoja),
    );
  }

  Widget _buildMonitoringKartica(V2Polazak zahtev, Color akcentBoja) {
    final ime = zahtev.putnikIme ?? 'Nepoznat';
    final grad = zahtev.grad ?? 'BC';
    final dan = zahtev.dan ?? '';
    final zeljenoVreme = zahtev.zeljenoVreme ?? '';
    final dodeljenoVreme = zahtev.dodeljenoVreme ?? '';
    final status = zahtev.status;
    final tip = zahtev.tipPutnika ?? '';
    final brojMesta = zahtev.brojMesta;

    final (statusLabel, statusColor, statusIkon) = _statusInfo(status);
    final tipLabel = tip.toLowerCase() == 'radnik' ? '👷 RADNIK' : '🎓 UČENIK';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).glassContainer.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.45), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ime + status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child:
                      Text(ime, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withOpacity(0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(statusIkon, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(statusLabel,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Tip + grad + mesta
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _tipBadge(tipLabel, akcentBoja),
                _gradBadge(grad),
                if (brojMesta > 1) _infoBadge('👥 $brojMesta mesta', Colors.purple),
              ],
            ),
            const SizedBox(height: 10),
            // Dan + željeno vreme → dodeljeno vreme
            Row(children: [
              const Icon(Icons.schedule, size: 15, color: Colors.amber),
              const SizedBox(width: 6),
              Text('$dan  $zeljenoVreme',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500)),
              if (dodeljenoVreme.isNotEmpty && dodeljenoVreme != zeljenoVreme) ...[
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 13, color: Colors.greenAccent.withOpacity(0.8)),
                const SizedBox(width: 4),
                Text(dodeljenoVreme,
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ]),
            // Alternativna vremena
            if ((zahtev.alternativeVreme1 != null && zahtev.alternativeVreme1!.isNotEmpty) ||
                (zahtev.alternativeVreme2 != null && zahtev.alternativeVreme2!.isNotEmpty)) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.alt_route, size: 14, color: Colors.cyan.withOpacity(0.7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Alt: ${[
                      zahtev.alternativeVreme1,
                      zahtev.alternativeVreme2
                    ].where((v) => v != null && v.isNotEmpty).join(', ')}',
                    style: TextStyle(color: Colors.cyan.shade200, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  (String label, Color color, String ikon) _statusInfo(String status) {
    return switch (status.toLowerCase()) {
      'obrada' => ('Na čekanju', Colors.orange, '⏳'),
      'odobreno' => ('Odobreno', Colors.green, '✅'),
      'odbijeno' => ('Odbijeno', Colors.red, '❌'),
      'otkazano' => ('Otkazano', Colors.grey, '🚫'),
      'pokupljen' => ('Pokupljen', Colors.teal, '🚗'),
      _ => (status, Colors.white54, '•'),
    };
  }

  Widget _tipBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
      );

  Widget _gradBadge(String grad) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Text(grad, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      );

  Widget _infoBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(label, style: TextStyle(color: color.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 10)),
      );

  Widget _buildPrazno(String poruka) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 72, color: Colors.white.withOpacity(0.4)),
            const SizedBox(height: 14),
            Text(poruka,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 17, fontWeight: FontWeight.w500)),
          ],
        ),
      );

  // ─── Akcije (samo dnevni tab) ─────────────────────────────────────────────

  Future<void> _approveZahtev(String id, V2Polazak zahtev) async {
    setState(() => _isLoading = true);
    try {
      final currentDriver = await AuthManager.getCurrentDriver();
      final success = await V2PolasciService.v2OdobriZahtev(id, approvedBy: currentDriver);
      if (success && mounted) {
        AppSnackBar.success(context, '✅ Zahtev uspešno odobren');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectZahtev(String id) async {
    setState(() => _isLoading = true);
    try {
      final currentDriver = await AuthManager.getCurrentDriver();
      final success = await V2PolasciService.v2OdbijZahtev(id, rejectedBy: currentDriver);
      if (success && mounted) {
        AppSnackBar.error(context, '❌ Zahtev je odbijen');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
