import 'dart:io';

void main() {
  print('🔍 AUTOMATSKA ANALIZA TESTOVA');
  print('==============================');

  final testDir = Directory('test');
  if (!testDir.existsSync()) {
    print('❌ Test direktorijum ne postoji!');
    return;
  }

  final files = testDir.listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_test.dart'))
      .toList();

  print('📊 PRONAĐENO ${files.length} TEST FAJLOVA');
  print('');

  // Kategorizacija
  final categories = {
    'database': <String>[],
    'vozac': <String>[],
    'mesecni': <String>[],
    'comprehensive': <String>[],
    'final': <String>[],
    'debug': <String>[],
    'simple': <String>[],
    'quick': <String>[],
    'geographic': <String>[],
    'uuid': <String>[],
    'model': <String>[],
    'time': <String>[],
    'utils': <String>[],
    'other': <String>[]
  };

  for (final file in files) {
    final name = file.path.split(Platform.pathSeparator).last;
    final lowerName = name.toLowerCase();

    if (lowerName.contains('database')) {
      categories['database']!.add(name);
    } else if (lowerName.contains('vozac')) {
      categories['vozac']!.add(name);
    } else if (lowerName.contains('mesecni')) {
      categories['mesecni']!.add(name);
    } else if (lowerName.contains('comprehensive')) {
      categories['comprehensive']!.add(name);
    } else if (lowerName.contains('final')) {
      categories['final']!.add(name);
    } else if (lowerName.contains('debug')) {
      categories['debug']!.add(name);
    } else if (lowerName.contains('simple')) {
      categories['simple']!.add(name);
    } else if (lowerName.contains('quick')) {
      categories['quick']!.add(name);
    } else if (lowerName.contains('geographic')) {
      categories['geographic']!.add(name);
    } else if (lowerName.contains('uuid')) {
      categories['uuid']!.add(name);
    } else if (lowerName.contains('model')) {
      categories['model']!.add(name);
    } else if (lowerName.contains('time')) {
      categories['time']!.add(name);
    } else if (lowerName.contains('utils')) {
      categories['utils']!.add(name);
    } else {
      categories['other']!.add(name);
    }
  }

  // Prikaz rezultata
  print('📋 KATEGORIZACIJA TESTOVA:');
  print('');

  categories.forEach((key, value) {
    if (value.isNotEmpty) {
      final priority = _getPriority(key);
      final icon = _getIcon(key);
      print('$icon $key (${value.length} testova) - Priority $priority');
      for (final test in value) {
        print('  - $test');
      }
      print('');
    }
  });

  // Statistika
  final totalTests = files.length;
  final criticalTests = categories['database']!.length +
                       categories['vozac']!.length +
                       categories['mesecni']!.length +
                       categories['comprehensive']!.length +
                       categories['final']!.length;

  print('📈 STATISTIKA:');
  print('Total testova: $totalTests');
  print('Kritičnih testova (Priority 1): $criticalTests');
  print('Procenat pokrivenosti: ${(criticalTests / totalTests * 100).round()}%');
  print('');

  // Preporuke
  print('🎯 PREPORUKE:');
  print('1. Prvo pokrenite Priority 1 testove');
  print('2. Popravite eventualne greške u njima');
  print('3. Zatim testirajte Priority 2');
  print('4. Priority 3 i 4 su opcionalni');
}

String _getPriority(String category) {
  switch (category) {
    case 'database':
    case 'vozac':
    case 'mesecni':
    case 'comprehensive':
    case 'final':
      return '1 (KRITIČNO)';
    case 'geographic':
    case 'uuid':
    case 'model':
    case 'time':
      return '2 (VAŽNO)';
    case 'debug':
    case 'simple':
    case 'quick':
      return '3 (MANJE VAŽNO)';
    default:
      return '4 (OPCIONALNO)';
  }
}

String _getIcon(String category) {
  switch (category) {
    case 'database': return '🗄️';
    case 'vozac': return '🚗';
    case 'mesecni': return '📅';
    case 'comprehensive': return '🔍';
    case 'final': return '🏁';
    case 'debug': return '🐛';
    case 'simple': return '📝';
    case 'quick': return '⚡';
    case 'geographic': return '🌍';
    case 'uuid': return '🔗';
    case 'model': return '📋';
    case 'time': return '⏰';
    case 'utils': return '🔧';
    default: return '📄';
  }
}