import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Inicijalizuj Supabase
  await Supabase.initialize(
    url: 'https://hmnzekwoqizjiwlhzxbn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtbnpla3dvcWl6aml3bGh6eGJuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjcyNTI2NzMsImV4cCI6MjA0MjgyODY3M30.ZaV2OLQB8UJ9db5whqpAhXAhDW1eFEIcgUgKQmWgeGg',
  );

  final supabase = Supabase.instance.client;

  try {
    print('🔍 Tražim Ana Cortan i Radošević Dragan u putovanja_istorija...');

    // Pronađi sve zapise Ana Cortan
    final anaRows = await supabase
        .from('putovanja_istorija')
        .select()
        .ilike('putnik_ime', '%ana%cortan%')
        .eq('tip_putnika', 'mesecni');

    print('📋 Pronašao ${anaRows.length} zapisa za Ana Cortan:');
    for (final row in anaRows) {
      print('  - ID: ${row['id']}, Datum: ${row['datum_putovanja']}, Cena: ${row['cena']} RSD');
    }

    // Pronađi sve zapise Radošević Dragan
    final radosevicRows = await supabase
        .from('putovanja_istorija')
        .select()
        .ilike('putnik_ime', '%radošević%dragan%')
        .eq('tip_putnika', 'mesecni');

    print('📋 Pronašao ${radosevicRows.length} zapisa za Radošević Dragan:');
    for (final row in radosevicRows) {
      print('  - ID: ${row['id']}, Datum: ${row['datum_putovanja']}, Cena: ${row['cena']} RSD');
    }

    if (anaRows.isEmpty && radosevicRows.isEmpty) {
      print('✅ Nema zapisa za brisanje.');
      return;
    }

    print('\n❓ Da li želiš da obrišeš sve ove zapise? (y/n)');
    final input = stdin.readLineSync()?.toLowerCase();

    if (input != 'y' && input != 'yes') {
      print('❌ Brisanje otkazano.');
      return;
    }

    // Obriši Ana Cortan zapise
    if (anaRows.isNotEmpty) {
      final anaIds = anaRows.map((row) => row['id']).toList();
      await supabase.from('putovanja_istorija').delete().in_('id', anaIds);
      print('🗑️ Obrisao ${anaIds.length} zapisa za Ana Cortan');
    }

    // Obriši Radošević Dragan zapise
    if (radosevicRows.isNotEmpty) {
      final radosevicIds = radosevicRows.map((row) => row['id']).toList();
      await supabase.from('putovanja_istorija').delete().in_('id', radosevicIds);
      print('🗑️ Obrisao ${radosevicIds.length} zapisa za Radošević Dragan');
    }

    print('✅ Brisanje završeno! Ana i Radošević su uklonjeni iz putovanja_istorija.');
    print('💡 Sada će se računati samo iz mesecni_putnici tabele (bez duplog računanja).');
  } catch (e) {
    print('❌ Greška: $e');
  }
}
