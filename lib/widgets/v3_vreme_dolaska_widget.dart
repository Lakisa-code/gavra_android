import 'package:flutter/material.dart';

import '../services/realtime/v3_master_realtime_manager.dart';
import '../utils/v3_container_utils.dart';

class V3VremeDolaskaWidget extends StatelessWidget {
  const V3VremeDolaskaWidget({
    super.key,
    required this.putnikId,
  });

  final String putnikId;

  static const String _colVozacId = 'vozac_id';
  static const String _colEtaSeconds = 'eta_seconds';
  static const String _colComputedAt = 'computed_at';

  // ETA se smatra zastarelom ako nema svežeg update-a duže vreme.
  // Ovo sprečava da ETA widget ostane "zalepljen" kada lokacije prestanu da stižu.
  static const Duration _staleThreshold = Duration(minutes: 15);

  ({int? etaSeconds, bool isStale, String? vozacId}) _readEtaState(Map<String, dynamic>? row) {
    if (row == null) {
      return (etaSeconds: null, isStale: false, vozacId: null);
    }

    final eta = (row[_colEtaSeconds] as num?)?.toInt();
    final computedAtRaw = row[_colComputedAt];
    DateTime? computedAt;
    if (computedAtRaw is DateTime) {
      computedAt = computedAtRaw;
    } else if (computedAtRaw is String) {
      computedAt = DateTime.tryParse(computedAtRaw);
    }
    final stale = computedAt == null || DateTime.now().difference(computedAt) > _staleThreshold;
    final vozacId = row[_colVozacId]?.toString();

    return (etaSeconds: eta, isStale: stale, vozacId: vozacId);
  }

  int _buildEtaMinutes(int etaSeconds) {
    if (etaSeconds <= 0) return 0;
    return (etaSeconds / 60).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: V3MasterRealtimeManager.instance.tablesRevisionStream(const ['v3_eta_results', 'v3_auth']),
      builder: (context, _) {
        final row = V3MasterRealtimeManager.instance.etaResultsCache[putnikId];
        final etaState = _readEtaState(row);
        final eta = etaState.etaSeconds;
        final isStale = etaState.isStale;
        final vozacId = etaState.vozacId;

        if (eta == null || isStale) return const SizedBox.shrink();

        final minutes = _buildEtaMinutes(eta);

        return V3ContainerUtils.styledContainer(
          padding: const EdgeInsets.all(12),
          backgroundColor: Colors.green.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.8), width: 1.2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '🚐 Procenjeno vreme dolaska',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'za $minutes min',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (vozacId != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Vozač: ${V3MasterRealtimeManager.instance.vozaciCache[vozacId]?['ime_prezime'] ?? vozacId}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
