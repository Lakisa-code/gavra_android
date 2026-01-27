import 'package:flutter/material.dart';

import '../services/leaderboard_service.dart';

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
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LeaderboardData>(
      stream: LeaderboardService.streamLeaderboard(tipPutnika: widget.tipPutnika),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting && data == null;

        if (isLoading) {
          return _buildLoading();
        }

        if (data == null || data.isEmpty) {
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
                  '📊 ${data.mesec.toUpperCase()} ${data.godina}',
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

              // Wall of Fame
              if (data.wallOfFame.isNotEmpty) ...[
                _buildSectionHeader('🏆 WALL OF FAME', Colors.amber),
                ...data.wallOfFame.map((e) => _buildEntry(e, Colors.greenAccent)),
              ],

              // Wall of Shame
              if (data.wallOfShame.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildSectionHeader('💀 WALL OF SHAME', Colors.redAccent),
                ...data.wallOfShame.map((e) => _buildEntry(e, Colors.redAccent)),
              ],

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEntry(LeaderboardEntry entry, Color color) {
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
