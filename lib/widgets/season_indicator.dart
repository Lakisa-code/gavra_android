import 'package:flutter/material.dart';
import '../utils/seasonal_schedule_manager.dart';

class SeasonIndicator extends StatelessWidget {
  final bool? forceLetnji;
  final VoidCallback? onSeasonToggle;
  final bool showToggleButton;

  const SeasonIndicator({
    super.key,
    this.forceLetnji,
    this.onSeasonToggle,
    this.showToggleButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isLetnji = forceLetnji ?? SeasonalScheduleManager.isLetniPeriod();
    final seasonName = isLetnji ? 'Letnji' : 'Zimski';
    final seasonIcon = isLetnji ? Icons.wb_sunny : Icons.ac_unit;
    final seasonColor = isLetnji ? Colors.orange : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: seasonColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: seasonColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            seasonIcon,
            size: 16,
            color: seasonColor,
          ),
          const SizedBox(width: 6),
          Text(
            '$seasonName red vožnje',
            style: TextStyle(
              color: seasonColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          if (showToggleButton && onSeasonToggle != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSeasonToggle,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: seasonColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.swap_horiz,
                  size: 14,
                  color: seasonColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SeasonInfoDialog extends StatelessWidget {
  const SeasonInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isLetnji = SeasonalScheduleManager.isLetniPeriod();
    final currentPeriod = SeasonalScheduleManager.getCurrentPeriodDescription();
    final daysUntilNext = SeasonalScheduleManager.getDaysUntilNextSeason();
    final nextSeasonStart = SeasonalScheduleManager.getNextSeasonStartDate();

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isLetnji ? Icons.wb_sunny : Icons.ac_unit,
            color: isLetnji ? Colors.orange : Colors.blue,
          ),
          const SizedBox(width: 8),
          const Text('Sezonski red vožnje'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trenutno važi:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(currentPeriod),
          const SizedBox(height: 16),
          Text(
            'Sledeća promena:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatDate(nextSeasonStart)} (za $daysUntilNext dana)',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 6),
                    Text(
                      'Razlike u redu vožnje:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('• Letnji: manje polazaka'),
                const Text('• Zimski: češći polasci'),
                const Text('• Automatska promena po datumu'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zatvori'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'januar',
      'februar',
      'mart',
      'april',
      'maj',
      'jun',
      'jul',
      'avgust',
      'septembar',
      'oktobar',
      'novembar',
      'decembar'
    ];
    return '${date.day}. ${months[date.month - 1]} ${date.year}.';
  }
}
