import 'package:flutter/material.dart';

import '../services/kapacitet_service.dart';
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
      debugPrint('❌ Greška pri učitavanju kapaciteta: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editKapacitet(String grad, String vreme, int trenutni) async {
    final controller = TextEditingController(text: trenutni.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).glassContainer,
        title: Text(
          '$grad - $vreme',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Unesite maksimalan broj mesta:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Otkaži', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Sačuvaj'),
          ),
        ],
      ),
    );

    if (result != null && result != trenutni) {
      final success = await KapacitetService.setKapacitet(grad, vreme, result);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $grad $vreme = $result mesta'),
            backgroundColor: Colors.green,
          ),
        );
        _loadKapacitet();
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vremena.length,
      itemBuilder: (context, index) {
        final vreme = vremena[index];
        final maxMesta = _kapacitet[grad]?[vreme] ?? 8;

        return Card(
          color: Theme.of(context).glassContainer,
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
                          await KapacitetService.setKapacitet(grad, vreme, maxMesta - 1);
                          _loadKapacitet();
                        }
                      : null,
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
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
                          await KapacitetService.setKapacitet(grad, vreme, maxMesta + 1);
                          _loadKapacitet();
                        }
                      : null,
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                ),
              ],
            ),
            onTap: () => _editKapacitet(grad, vreme, maxMesta),
          ),
        );
      },
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
          actions: [
            IconButton(
              onPressed: _loadKapacitet,
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Osveži',
            ),
          ],
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
