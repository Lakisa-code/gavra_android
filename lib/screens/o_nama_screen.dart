import 'package:flutter/material.dart';

import '../theme.dart';

/// 📖 O NAMA SCREEN
/// Informacije o Gavra 013 timu i aplikaciji
class ONamaScreen extends StatelessWidget {
  const ONamaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: tripleBlueFashionGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            '📖 O nama',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Text(
            'Uskoro...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 24,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
