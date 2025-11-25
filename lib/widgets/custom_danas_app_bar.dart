import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/clock_ticker.dart';

/// Custom AppBar za DanasScreen
class CustomDanasAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomDanasAppBar({
    Key? key,
    required this.currentDriver,
    required this.onHeartbeatTap,
    required this.onDjackiBrojacTap,
    required this.onOptimizeTap,
    required this.onPopisTap,
    required this.onMapsTap,
    required this.onSpeedometerTap,
  }) : super(key: key);

  final String? currentDriver;
  final VoidCallback onHeartbeatTap;
  final VoidCallback onDjackiBrojacTap;
  final VoidCallback onOptimizeTap;
  final VoidCallback onPopisTap;
  final VoidCallback onMapsTap;
  final VoidCallback onSpeedometerTap;

  @override
  Size get preferredSize => const Size.fromHeight(80);

  Widget _buildDigitalDateDisplay(BuildContext context) {
    final now = DateTime.now();
    final dayNames = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Maj', 'Jun', 'Jul', 'Avg', 'Sep', 'Okt', 'Nov', 'Dec'];

    final dayStr = now.day.toString().padLeft(2, '0');
    final monthStr = monthNames[now.month - 1];
    final yearStr = now.year.toString();
    final dayName = dayNames[now.weekday - 1];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // LEVO - DATUM
        Text(
          '$dayStr.$monthStr.$yearStr',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.8,
            shadows: [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 3,
                color: Colors.black54,
              ),
            ],
          ),
        ),
        // SREDINA - DAN
        Text(
          dayName,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onPrimary,
            letterSpacing: 1.8,
            shadows: const [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 3,
                color: Colors.black54,
              ),
            ],
          ),
        ),
        // DESNO - VREME
        ClockTicker(
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onPrimary,
            letterSpacing: 1.8,
            shadows: const [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 3,
                color: Colors.black54,
              ),
            ],
          ),
          showSeconds: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).glassContainer,
          border: Border.all(
            color: Theme.of(context).glassBorder,
            width: 1.5,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(25),
            bottomRight: Radius.circular(25),
          ),
          // keep AppBar transparent and border-only; no box shadow
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // DATUM TEKST
                Center(
                  child: _buildDigitalDateDisplay(context),
                ),
                const SizedBox(height: 4),
                // DUGMAD U APP BAR-U
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      // CLEAN STATS INDIKATOR
                      Flexible(
                        fit: FlexFit.loose,
                        child: _buildButton(
                          icon: Icons.favorite,
                          label: 'Health',
                          onTap: onHeartbeatTap,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 2),
                      // ĐAČKI BROJAČ
                      Flexible(
                        fit: FlexFit.loose,
                        child: _buildButton(
                          icon: Icons.school,
                          label: 'Đaci',
                          onTap: onDjackiBrojacTap,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 2),
                      // DUGME ZA OPTIMIZACIJU RUTE
                      Flexible(
                        fit: FlexFit.loose,
                        child: _buildButton(
                          icon: Icons.route,
                          label: 'Ruta',
                          onTap: onOptimizeTap,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 2),
                      // DUGME ZA POPIS DANA
                      Flexible(
                        fit: FlexFit.loose,
                        child: _buildButton(
                          icon: Icons.list,
                          label: 'Popis',
                          onTap: onPopisTap,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 2),
                      // DUGME ZA NAVIGACIJU
                      Flexible(
                        fit: FlexFit.loose,
                        child: _buildButton(
                          icon: Icons.map,
                          label: 'Mape',
                          onTap: onMapsTap,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 2),
                      // SPEEDOMETER
                      Flexible(
                        fit: FlexFit.loose,
                        child: _buildButton(
                          icon: Icons.speed,
                          label: 'Brzina',
                          onTap: onSpeedometerTap,
                          color: Colors.cyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return SizedBox(
      height: 26,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 12),
        // keep the label single-line and scale it down when space is tight
        // keep label compact but readable; allow enough min width so short labels
        // (e.g. "POPIS") never get clipped on narrow screens
        label: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minWidth: 40, maxWidth: 56),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.2),
          foregroundColor: color,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          // smaller but guaranteed minimum width so shorter labels are never cut
          // (the original value was very wide and got overridden when many
          // buttons are placed in a horizontal row). 56-72px is enough for
          // short uppercase labels like "POPIS" on narrow devices.
          minimumSize: const Size(72, 26),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        ),
      ),
    );
  }
}
