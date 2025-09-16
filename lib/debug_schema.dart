import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  try {
    final supabase = Supabase.instance.client;

    // Dobij strukturu tabele mesecni_putnici
    final result = await supabase.from('mesecni_putnici').select().limit(1);

    if (result.isNotEmpty) {
      debugPrint('📊 Struktura tabele mesecni_putnici:');
      final firstRow = result.first;
      for (final column in firstRow.keys) {
        debugPrint('  - $column: ${firstRow[column]?.runtimeType}');
      }
    } else {
      debugPrint('❌ Nema podataka u tabeli mesecni_putnici');
    }
  } catch (e) {
    debugPrint('❌ Greška: $e');
  }
}
