import 'package:flutter/material.dart';

import '../services/seat_optimization_service.dart';
import '../services/theme_manager.dart';

/// 🎯 SEAT OPTIMIZATION ADMIN WIDGET
/// Widget za admina da vidi i primeni optimizaciju rasporeda
/// Prikazuje trenutno stanje, predloge preraspodele i mogućnost primene

class SeatOptimizationWidget extends StatefulWidget {
  final String grad;
  final DateTime datum;
  final VoidCallback? onOptimizationApplied;

  const SeatOptimizationWidget({
    Key? key,
    required this.grad,
    required this.datum,
    this.onOptimizationApplied,
  }) : super(key: key);

  @override
  State<SeatOptimizationWidget> createState() => _SeatOptimizationWidgetState();
}

class _SeatOptimizationWidgetState extends State<SeatOptimizationWidget> {
  bool _isLoading = true;
  bool _isApplying = false;
  OptimizationResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _runOptimization();
  }

  Future<void> _runOptimization() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await SeatOptimizationService.optimize(
        grad: widget.grad,
        datum: widget.datum,
      );

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Greška: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _applyOptimization() async {
    if (_result == null || !_result!.imaPredloga) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Primeni optimizaciju?'),
        content: Text(
          'Ovo će preraspodeliti ${_result!.brojPreraspodela} putnika '
          'i uštedeti ${_result!.ustedaKombija} kombija.\n\n'
          'Da li ste sigurni?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Primeni'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isApplying = true);

    try {
      final success = await SeatOptimizationService.applyOptimization(_result!);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Optimizacija primenjena! Ušteda: ${_result!.ustedaKombija} kombija'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onOptimizationApplied?.call();
        await _runOptimization(); // Refresh
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Greška pri primeni'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Greška: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: ThemeManager().currentGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_fix_high, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎯 Smart Optimizacija',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.grad} • ${widget.datum.day}.${widget.datum.month}.${widget.datum.year}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _runOptimization,
                ),
              ],
            ),
          ),

          // Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            )
          else if (_result != null)
            _buildOptimizationResult(),
        ],
      ),
    );
  }

  Widget _buildOptimizationResult() {
    final result = _result!;
    final preKombija = SeatOptimizationService.calculateTotalKombija(result.preOptimizacije);
    final posleKombija = SeatOptimizationService.calculateTotalKombija(result.posleOptimizacije);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistike pre/posle
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Trenutno',
                  value: '$preKombija',
                  subtitle: 'kombija',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward, color: Colors.white54),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Posle',
                  value: '$posleKombija',
                  subtitle: 'kombija',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Ušteda
          if (result.ustedaKombija > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.savings, color: Colors.green, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'UŠTEDA: ${result.ustedaKombija} kombija! 🎉',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Predlozi preraspodele
          if (result.imaPredloga) ...[
            const Text(
              'Predložene preraspodele:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: result.suggestions.length,
                itemBuilder: (ctx, i) {
                  final s = result.suggestions[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.putnikIme ?? 'Putnik',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${s.originalnoVreme} → ${s.predlozenoVreme}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.swap_horiz, color: Colors.blue, size: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Dugme za primenu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isApplying ? null : _applyOptimization,
                icon: _isApplying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isApplying ? 'Primenjujem...' : 'Primeni optimizaciju'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Raspored je već optimalan! ✓',
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Detaljan pregled termina
          ExpansionTile(
            title: const Text(
              'Detaljan pregled termina',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            iconColor: Colors.white,
            collapsedIconColor: Colors.white70,
            children: [
              ...result.preOptimizacije.entries.where((e) => e.value.ukupno > 0).map((entry) {
                final s = entry.value;
                return ListTile(
                  dense: true,
                  leading: Text(s.vreme, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  title: Text(
                    '${s.fiksniPutnici} fiksni + ${s.fleksibilniPutnici} flex = ${s.ukupno}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${s.brojKombija} 🚐',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          Text(subtitle, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12)),
        ],
      ),
    );
  }
}
