import 'package:flutter/material.dart';

import '../services/admin_audit_service.dart'; // 🕵️ ADMIN AUDIT
import '../services/firebase_service.dart'; // 👤 CURRENT USER
import '../services/kapacitet_service.dart';
import '../services/slobodna_mesta_service.dart'; // 🚢 SMART TRANZIT
import '../services/theme_manager.dart';
import '../theme.dart';

/// 🎫 Admin ekran za podešavanje kapaciteta polazaka
class KapacitetScreen extends StatefulWidget {
  const KapacitetScreen({Key? key}) : super(key: key);

  @override
  State<KapacitetScreen> createState() => _KapacitetScreenState();
}

class _KapacitetScreenState extends State<KapacitetScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, Map<String, int>> _kapacitet = {'BC': {}, 'VS': {}};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadKapacitet();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadKapacitet() async {
    setState(() => _isLoading = true);
    try {
      _kapacitet = await KapacitetService.getKapacitet();
    } catch (e) {
      // Error loading kapacitet
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editKapacitet(String grad, String vreme, int trenutni) async {
    final controller = TextEditingController(text: trenutni.toString());

    final result = await showDialog<int>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            gradient: Theme.of(context).backgroundGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).glassBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🎨 GLASSMORPHISM HEADER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).glassContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).glassBorder,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '🎫 $grad - $vreme',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 3,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 📝 CONTENT
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unesite maksimalan broj mesta:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).glassContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).glassBorder,
                        ),
                      ),
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 🎯 BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            child: const Text(
                              'Otkaži',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final value = int.tryParse(controller.text);
                              if (value != null && value > 0 && value <= 20) {
                                Navigator.pop(ctx, value);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Unesite broj između 1 i 20'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Sačuvaj',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && result != trenutni) {
      final success = await KapacitetService.setKapacitet(grad, vreme, result);
      if (!mounted) return;
      if (success) {
        try {
          // 🕵️ AUDIT LOG
          final vozac = await FirebaseService.getCurrentDriver() ?? 'Unknown Admin';
          await AdminAuditService.logCapacityChange(
            adminName: vozac,
            datum: 'Standardni raspored',
            vreme: '$grad $vreme',
            oldCap: trenutni,
            newCap: result,
          );
        } catch (e) {
          // Ignore log errors
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $grad $vreme = $result mesta'),
              backgroundColor: Colors.green,
            ),
          );
          _loadKapacitet();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Greška pri čuvanju'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildGradTab(String grad, List<String> vremena) {
    return Column(
      children: [
        // 🚢 SMART TRANZIT INFO (Samo za Vršac)
        if (grad == 'VS')
          FutureBuilder<List<Map<String, dynamic>>>(
            future: SlobodnaMestaService.getMissingTransitPassengers(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
              final missingCount = snapshot.data!.length;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horizontal_circle, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PROJEKTOVANO OPTEREĆENJE (VS)',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '$missingCount putnika u VS još nije rezervisalo povratak.',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vremena.length,
            itemBuilder: (ctx, index) {
              final vreme = vremena[index];
              final maxMesta = _kapacitet[grad]?[vreme] ?? 8;

              return Card(
                color: Theme.of(ctx).glassContainer,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    vreme,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Kapacitet: $maxMesta mesta',
                    style: TextStyle(
                      color: maxMesta < 8 ? Colors.orange : Colors.white70,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Brzo smanjenje
                      IconButton(
                        onPressed: maxMesta > 1
                            ? () async {
                                final success = await KapacitetService.setKapacitet(grad, vreme, maxMesta - 1);
                                if (!mounted) return;
                                if (success) {
                                  setState(() {
                                    _kapacitet[grad]?[vreme] = maxMesta - 1;
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('❌ Greška pri čuvanju'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            : null,
                        icon: const Icon(Icons.remove_circle, color: Colors.red, size: 32),
                      ),
                      // Prikaz broja
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getKapacitetBoja(maxMesta),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$maxMesta',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Brzo povećanje
                      IconButton(
                        onPressed: maxMesta < 20
                            ? () async {
                                final success = await KapacitetService.setKapacitet(grad, vreme, maxMesta + 1);
                                if (!mounted) return;
                                if (success) {
                                  setState(() {
                                    _kapacitet[grad]?[vreme] = maxMesta + 1;
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('❌ Greška pri čuvanju'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            : null,
                        icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                      ),
                    ],
                  ),
                  onTap: () => _editKapacitet(grad, vreme, maxMesta),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getKapacitetBoja(int mesta) {
    if (mesta >= 8) return Colors.green;
    if (mesta >= 5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: ThemeManager().currentGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            '🎫 Kapacitet Polazaka',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.green,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'Bela Crkva'),
              Tab(text: 'Vršac'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildGradTab('BC', KapacitetService.bcVremena),
                  _buildGradTab('VS', KapacitetService.vsVremena),
                ],
              ),
      ),
    );
  }
}
