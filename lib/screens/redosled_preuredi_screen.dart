import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🚐 Screen za editovanje satnih redoslijeda po sezoni
class RedosledPreureditiScreen extends StatefulWidget {
  const RedosledPreureditiScreen({Key? key}) : super(key: key);

  @override
  State<RedosledPreureditiScreen> createState() => _RedosledPreureditiScreenState();
}

class _RedosledPreureditiScreenState extends State<RedosledPreureditiScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Map sa redosledima: sezona -> grad -> vremena
  Map<String, Map<String, List<String>>> _redosled = {
    'zimski': {'bc': [], 'vs': []},
    'letnji': {'bc': [], 'vs': []},
    'praznici': {'bc': [], 'vs': []},
  };

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRedosled();
  }

  Future<void> _loadRedosled() async {
    try {
      setState(() => _isLoading = true);
      
      final response = await _supabase
          .from('voznje_po_sezoni')
          .select('sezona, grad, vremena')
          .eq('aktivan', true);

      // Organizuj po sezoni i gradu
      final Map<String, Map<String, List<String>>> redosled = {
        'zimski': {'bc': [], 'vs': []},
        'letnji': {'bc': [], 'vs': []},
        'praznici': {'bc': [], 'vs': []},
      };

      for (final row in response) {
        final sezona = row['sezona'];
        final grad = row['grad'];
        final vremena = List<String>.from(row['vremena'] ?? []);
        
        if (redosled.containsKey(sezona) && redosled[sezona]!.containsKey(grad)) {
          redosled[sezona]![grad] = vremena;
        }
      }

      if (mounted) {
        setState(() {
          _redosled = redosled;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Greška pri učitavanju redoslijeda: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveRedosled(String sezona, String grad) async {
    try {
      final vremena = _redosled[sezona]![grad]!;
      
      await _supabase
          .from('voznje_po_sezoni')
          .update({'vremena': vremena})
          .eq('sezona', sezona)
          .eq('grad', grad);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Redoslijed za $sezona/$grad je sačuvan')),
        );
      }
      
      if (kDebugMode) {
        debugPrint('✅ Sačuvan redoslijed ($sezona/$grad): $vremena');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Greška: $e')),
        );
      }
    }
  }

  void _editVremena(String sezona, String grad) {
    final controller = TextEditingController(
      text: _redosled[sezona]![grad]!.join(', '),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Uredi vremena - $sezona / ${grad.toUpperCase()}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '05:00, 06:00, 07:00, ...',
            helperText: 'Odvoji vremena zarezom',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            onPressed: () {
              final input = controller.text.trim();
              if (input.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❌ Unesite vremena')),
                );
                return;
              }

              final vremena = input
                  .split(',')
                  .map((v) => v.trim())
                  .where((v) => v.isNotEmpty)
                  .toList();

              setState(() {
                _redosled[sezona]![grad] = vremena;
              });

              _saveRedosled(sezona, grad);
              Navigator.pop(context);
            },
            child: const Text('Sačuvaj'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚐 Redoslijedi Vožnji'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 16)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: _redosled.entries.map((sezonaEntry) {
                      final sezona = sezonaEntry.key;
                      final gradovi = sezonaEntry.value;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ExpansionTile(
                          title: Text(
                            sezona.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          children: gradovi.entries.map((gradEntry) {
                            final grad = gradEntry.key;
                            final vremena = gradEntry.value;

                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ListTile(
                                leading: Text(
                                  grad == 'bc' ? '🏙️' : '🌆',
                                  style: const TextStyle(fontSize: 24),
                                ),
                                title: Text(
                                  grad == 'bc' ? 'BELA CRKVA' : 'VRŠAC',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  vremena.join(', '),
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editVremena(sezona, grad),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  ),
                ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
