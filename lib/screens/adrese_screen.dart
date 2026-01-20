import 'package:flutter/material.dart';

import '../globals.dart';
import '../theme.dart';

/// 📍 ADRESE SCREEN - Upravljanje dozvoljenim adresama
/// Omogućava dodavanje, uređivanje i brisanje adresa direktno iz aplikacije
class AdreseScreen extends StatefulWidget {
  const AdreseScreen({Key? key}) : super(key: key);

  @override
  State<AdreseScreen> createState() => _AdreseScreenState();
}

class _AdreseScreenState extends State<AdreseScreen> {
  List<Map<String, dynamic>> _adrese = [];
  bool _isLoading = true;
  String _filterGrad = 'Svi';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAdrese();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdrese() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase.from('adrese').select().order('grad').order('naziv');

      setState(() {
        _adrese = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri učitavanju: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredAdrese {
    return _adrese.where((adresa) {
      final naziv = (adresa['naziv'] ?? '').toString().toLowerCase();
      final grad = (adresa['grad'] ?? '').toString();

      final matchesSearch = _searchQuery.isEmpty || naziv.contains(_searchQuery.toLowerCase());
      final matchesGrad = _filterGrad == 'Svi' || grad == _filterGrad;

      return matchesSearch && matchesGrad;
    }).toList();
  }

  Future<void> _addAdresa() async {
    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => _AdresaDialog(),
    );

    if (result != null) {
      try {
        await supabase.from('adrese').insert({
          'naziv': result['naziv'],
          'grad': result['grad'],
          'ulica': result['ulica'],
          'broj': result['broj'],
        });

        await _loadAdrese();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Adresa dodana'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Greška: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _editAdresa(Map<String, dynamic> adresa) async {
    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => _AdresaDialog(
        initialNaziv: adresa['naziv'],
        initialGrad: adresa['grad'],
        initialUlica: adresa['ulica'],
        initialBroj: adresa['broj'],
      ),
    );

    if (result != null) {
      try {
        await supabase.from('adrese').update({
          'naziv': result['naziv'],
          'grad': result['grad'],
          'ulica': result['ulica'],
          'broj': result['broj'],
        }).eq('id', adresa['id']);

        await _loadAdrese();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Adresa ažurirana'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Greška: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteAdresa(Map<String, dynamic> adresa) async {
    try {
      await supabase.from('adrese').delete().eq('id', adresa['id']);
      await _loadAdrese();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Adresa obrisana'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final belaCrkvaCount = _adrese.where((a) => a['grad'] == 'Bela Crkva').length;
    final vrsacCount = _adrese.where((a) => a['grad'] == 'Vršac' || a['grad'] == 'Vrsac').length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('📍 Adrese'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header sa statistikom
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).glassContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).glassBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard('Ukupno', _adrese.length.toString(), Colors.blue),
                        _buildStatCard('B. Crkva', belaCrkvaCount.toString(), Colors.green),
                        _buildStatCard('Vršac', vrsacCount.toString(), Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Pretraži adrese...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white70),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.3),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                    const SizedBox(height: 12),
                    // Filter dugmad
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFilterChip('Svi', _filterGrad == 'Svi'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Bela Crkva', _filterGrad == 'Bela Crkva'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Vršac', _filterGrad == 'Vršac'),
                      ],
                    ),
                  ],
                ),
              ),

              // Lista adresa
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredAdrese.isEmpty
                        ? const Center(
                            child: Text(
                              'Nema adresa',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredAdrese.length,
                            itemBuilder: (context, index) {
                              final adresa = _filteredAdrese[index];
                              return _buildAdresaCard(adresa);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      // 📱 ANDROID 15 EDGE-TO-EDGE: Padding za gesture navigation bar
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
        child: FloatingActionButton.extended(
          onPressed: _addAdresa,
          icon: const Icon(Icons.add),
          label: const Text('Dodaj'),
          backgroundColor: Colors.green,
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) {
        setState(() => _filterGrad = label);
      },
      backgroundColor: Colors.black.withValues(alpha: 0.3),
      selectedColor: Colors.blue.withValues(alpha: 0.6),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: selected ? Colors.blue : Colors.white.withValues(alpha: 0.3),
        width: selected ? 2 : 1,
      ),
      labelStyle: TextStyle(
        color: Colors.white,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 14,
      ),
    );
  }

  Widget _buildAdresaCard(Map<String, dynamic> adresa) {
    final grad = adresa['grad'] ?? '';
    final isVrsac = grad == 'Vršac' || grad == 'Vrsac';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).glassContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVrsac ? Colors.orange.withValues(alpha: 0.5) : Colors.green.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isVrsac ? Colors.orange : Colors.green,
          child: Text(
            (adresa['naziv'] ?? '?')[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          adresa['naziv'] ?? 'Bez naziva',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          grad,
          style: TextStyle(
            color: isVrsac ? Colors.orange.shade200 : Colors.green.shade200,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editAdresa(adresa),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteAdresa(adresa),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog za dodavanje/uređivanje adrese
class _AdresaDialog extends StatefulWidget {
  final String? initialNaziv;
  final String? initialGrad;
  final String? initialUlica;
  final String? initialBroj;

  const _AdresaDialog({
    this.initialNaziv,
    this.initialGrad,
    this.initialUlica,
    this.initialBroj,
  });

  @override
  State<_AdresaDialog> createState() => _AdresaDialogState();
}

class _AdresaDialogState extends State<_AdresaDialog> {
  late TextEditingController _nazivController;
  late TextEditingController _ulicaController;
  late TextEditingController _brojController;
  String _selectedGrad = 'Bela Crkva';

  @override
  void initState() {
    super.initState();
    _nazivController = TextEditingController(text: widget.initialNaziv);
    _ulicaController = TextEditingController(text: widget.initialUlica);
    _brojController = TextEditingController(text: widget.initialBroj);
    if (widget.initialGrad != null) {
      _selectedGrad = widget.initialGrad!;
    }
  }

  @override
  void dispose() {
    _nazivController.dispose();
    _ulicaController.dispose();
    _brojController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialNaziv != null;

    return AlertDialog(
      title: Text(isEditing ? 'Uredi adresu' : 'Nova adresa'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nazivController,
              decoration: const InputDecoration(
                labelText: 'Naziv *',
                hintText: 'npr. Bolnica, Hemofarm, Dejana Brankova 99',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedGrad,
              decoration: const InputDecoration(labelText: 'Grad *'),
              items: ['Bela Crkva', 'Vršac'].map((grad) {
                return DropdownMenuItem(value: grad, child: Text(grad));
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedGrad = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ulicaController,
              decoration: const InputDecoration(
                labelText: 'Ulica (opciono)',
                hintText: 'npr. Dejana Brankova',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _brojController,
              decoration: const InputDecoration(
                labelText: 'Broj (opciono)',
                hintText: 'npr. 99',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Otkaži'),
        ),
        ElevatedButton(
          onPressed: () {
            final naziv = _nazivController.text.trim();
            if (naziv.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Naziv je obavezan')),
              );
              return;
            }
            Navigator.pop(context, {
              'naziv': naziv,
              'grad': _selectedGrad,
              'ulica': _ulicaController.text.trim().isEmpty ? naziv : _ulicaController.text.trim(),
              'broj': _brojController.text.trim().isEmpty ? null : _brojController.text.trim(),
            });
          },
          child: Text(isEditing ? 'Sačuvaj' : 'Dodaj'),
        ),
      ],
    );
  }
}
