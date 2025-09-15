import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  try {
    final supabase = Supabase.instance.client;

    // Dobij strukturu tabele mesecni_putnici
    final result = await supabase.from('mesecni_putnici').select().limit(1);

    if (result.isNotEmpty) {
      print('📊 Struktura tabele mesecni_putnici:');
      final firstRow = result.first as Map<String, dynamic>;
      firstRow.keys.forEach((column) {
        print('  - $column: ${firstRow[column]?.runtimeType}');
      });
    } else {
      print('❌ Nema podataka u tabeli mesecni_putnici');
    }
  } catch (e) {
    print('❌ Greška: $e');
  }
}
