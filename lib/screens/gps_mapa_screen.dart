import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/custom_back_button.dart';

class GpsMapaScreen extends StatefulWidget {
  const GpsMapaScreen({Key? key}) : super(key: key);

  @override
  State<GpsMapaScreen> createState() => _GpsMapaScreenState();
}

class _GpsMapaScreenState extends State<GpsMapaScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const GradientBackButton(),
          title: const Text(
            'GPS Mapa',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 3,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 80,
          flexibleSpace: Container(
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
            ),
          ),
        ),
        body: const Center(
          child: Text(
            'GPS Mapa funkcionalnost će biti dodana uskoro',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
