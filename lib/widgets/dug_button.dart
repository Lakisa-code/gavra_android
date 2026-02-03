import 'package:flutter/material.dart';

import '../theme.dart'; // Dodato za glassmorphism

class DugButton extends StatelessWidget {
  // novi parametar za prikaz kao kocka

  const DugButton({
    super.key,
    required this.brojDuznika,
    this.onTap,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
    this.wide = false,
    this.isLoading = false,
  });
  final int brojDuznika;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;
  final bool wide;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      // Kompaktni prikaz (za sve ekrane osim admin)
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.red[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red[300]!),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning,
                color: iconColor ?? Colors.red[700],
                size: 18,
              ),
              const SizedBox(height: 2),
              Text(
                'Dug',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? Colors.red[700],
                ),
              ),
              Text(
                brojDuznika > 0 ? brojDuznika.toString() : '-',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? Colors.red[700],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Široki prikaz (kocka kao za admin screen)
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          height: 60,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor ?? Theme.of(context).glassContainer, // Glassmorphism
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).glassBorder, // Transparentni border
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: iconColor ?? Colors.red[700],
                radius: 16,
                child: const Icon(Icons.warning, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dužnici',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor ?? Colors.red[700],
                      ),
                    ),
                    Text(
                      'Dug',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.monetization_on,
                    color: iconColor ?? Colors.red[700],
                    size: 16,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    brojDuznika > 0 ? brojDuznika.toString() : '-',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor ?? Colors.red[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }
}
