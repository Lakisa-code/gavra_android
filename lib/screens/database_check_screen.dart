import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/custom_back_button.dart';

class DatabaseCheckScreen extends StatefulWidget {
  const DatabaseCheckScreen({super.key});

  @override
  State<DatabaseCheckScreen> createState() => _DatabaseCheckScreenState();
}

class _DatabaseCheckScreenState extends State<DatabaseCheckScreen> {
  List<String> tableResults = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkTables();
  }

  Future<void> _checkTables() async {
    final supabase = Supabase.instance.client;

    final expectedTables = [
      'vozaci',
      'vozila',
      'rute',
      'adrese',
      'dnevni_putnici',
      'mesecni_putnici',
      'putovanja_istorija',
      'gps_lokacije'
    ];

    List<String> results = [];

    for (final tableName in expectedTables) {
      try {
        final response = await supabase.from(tableName).select('*').limit(1);

        if (response.isNotEmpty) {
          results.add('✅ $tableName - postoji (ima podatke)');
        } else {
          results.add('⚠️ $tableName - postoji ali je prazan');
        }
      } catch (e) {
        results.add(
            '❌ $tableName - ne postoji ili greška: ${e.toString().split('\n')[0]}');
      }
    }

    setState(() {
      tableResults = results;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const CustomBackButton(color: Colors.black),
        automaticallyImplyLeading: false,
        title: const Text('Provera Supabase tabela'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: tableResults.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(tableResults[index]),
                );
              },
            ),
    );
  }
}
