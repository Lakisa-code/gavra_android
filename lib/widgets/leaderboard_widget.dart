import 'dart:async';

import 'package:flutter/material.dart';

import '../services/leaderboard_service.dart';
import '../services/realtime/realtime_manager.dart';

/// 🏆💀 LEADERBOARD WIDGET
/// Wall of Fame / Wall of Shame - realtime prikaz
class LeaderboardWidget extends StatefulWidget {
  const LeaderboardWidget({
    super.key,
    required this.tipPutnika, // 'ucenik' ili 'radnik'
  });

  final String tipPutnika;

  @override
  State<LeaderboardWidget> createState() => _LeaderboardWidgetState();
}

class _LeaderboardWidgetState extends State<LeaderboardWidget> {
  LeaderboardData? _data;
  bool _isLoading = true;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startRealtimeListener();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    RealtimeManager.instance.unsubscribe('voznje_log');
    super.dispose();
  }

  Future<void> _loadData() async {
    final data = await LeaderboardService.getLeaderboard(
      tipPutnika: widget.tipPutnika,
    );

    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
    }
  }

  void _startRealtimeListener() {
    // Sluša promene na voznje_log tabeli
    _subscription = RealtimeManager.instance.subscribe('voznje_log').listen((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoading();
    }

    if (_data == null || _data!.isEmpty) {
      return _buildEmpty();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.indigo.shade900.withValues(alpha: 0.8),
            Colors.purple.shade900.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '📊 ${_data!.mesec.toUpperCase()} ${_data!.godina}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),

          // Divider
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),

          // Two columns
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wall of Fame (levo)
                Expanded(
                  child: _buildColumn(
                    title: '🏆 Fame',
                    entries: _data!.wallOfFame,
                    isGood: true,
                  ),
                ),

                // Separator
                Container(
                  width: 1,
                  height: 150,
                  color: Colors.white.withValues(alpha: 0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),

                // Wall of Shame (desno)
                Expanded(
                  child: _buildColumn(
                    title: '💀 Shame',
                    entries: _data!.wallOfShame,
                    isGood: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn({
    required String title,
    required List<LeaderboardEntry> entries,
    required bool isGood,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Naslov kolone
        Text(
          title,
          style: TextStyle(
            color: isGood ? Colors.greenAccent : Colors.redAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Entries
        if (entries.isEmpty)
          Text(
            'Nema podataka',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ...entries.asMap().entries.map((e) => _buildEntry(e.key + 1, e.value, isGood)),
      ],
    );
  }

  Widget _buildEntry(int rank, LeaderboardEntry entry, bool isGood) {
    // Skrati ime ako je predugačko
    String displayName = entry.ime;
    if (displayName.length > 12) {
      final parts = displayName.split(' ');
      if (parts.length >= 2) {
        // Ime + inicijal prezimena
        displayName = '${parts[0]} ${parts[1][0]}.';
      } else {
        displayName = '${displayName.substring(0, 10)}...';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Rang
          SizedBox(
            width: 16,
            child: Text(
              '$rank.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ),

          // Ime
          Expanded(
            child: Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Ikona
          Text(
            entry.icon,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: const Center(
        child: Text(
          '📊 Nema dovoljno podataka za leaderboard',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
