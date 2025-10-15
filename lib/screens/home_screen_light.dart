import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_service.dart';
import '../utils/logging.dart';
import 'welcome_screen.dart';

class HomeScreenLight extends StatefulWidget {
  const HomeScreenLight({Key? key}) : super(key: key);

  @override
  State<HomeScreenLight> createState() => _HomeScreenLightState();
}

class _HomeScreenLightState extends State<HomeScreenLight> {
  String? _currentDriver;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDriver();
  }

  Future<void> _loadDriver() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentDriver = prefs.getString('selected_driver');
      dlog('🚗 Trenutni vozač: $_currentDriver');

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      dlog('❌ Greška pri učitavanju vozača: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_driver');

      // ✅ FIREBASE SERVICE - CLEAR CURRENT DRIVER
      await FirebaseService.clearCurrentDriver();

      dlog('✅ Logout uspešan za vozača: $_currentDriver');

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const WelcomeScreen()),
        );
      }
    } catch (e) {
      dlog('❌ Greška pri logout-u: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Učitavanje...'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Gavra Prevoz - ${_currentDriver ?? 'Nepoznat vozač'}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Odjavi se',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.directions_bus,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              Text(
                'Dobrodošli, ${_currentDriver ?? 'Vozač'}!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Jednostavna verzija aplikacije je spremna za korišćenje.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Stabilno okruženje',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text('Bez grešaka i padova aplikacije'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
