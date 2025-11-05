import 'package:flutter_test/flutter_test.dart';

import '../lib/utils/mesecni_filter_fix.dart';

/// 🧪 TESTOVI ZA POBOLJŠANU LOGIKU FILTRIRANJA MESEČNIH PUTNIKA
void main() {
  group('MesecniFilterFix Tests', () {
    test('matchesDan - tačno matchovanje dana', () {
      // ✅ Pozitivni testovi
      expect(MesecniFilterFix.matchesDan('pon,uto,sre', 'pon'), true);
      expect(MesecniFilterFix.matchesDan('pon, uto, sre', 'uto'), true);
      expect(MesecniFilterFix.matchesDan('PET,SUB', 'pet'), true);

      // ❌ Negativni testovi
      expect(MesecniFilterFix.matchesDan('pon,uto,sre', 'cet'), false);
      expect(MesecniFilterFix.matchesDan('spon,nedelja', 'pon'), false); // Ne treba da matchu!
      expect(MesecniFilterFix.matchesDan('', 'pon'), false);
    });

    test('isValidPolazak - validacija vremena', () {
      // ✅ Validna vremena
      expect(MesecniFilterFix.isValidPolazak('07:30'), true);
      expect(MesecniFilterFix.isValidPolazak('15:45:30'), true);
      expect(MesecniFilterFix.isValidPolazak('8:00'), true);

      // ❌ Nevalidna vremena
      expect(MesecniFilterFix.isValidPolazak('00:00'), false);
      expect(MesecniFilterFix.isValidPolazak('00:00:00'), false);
      expect(MesecniFilterFix.isValidPolazak('null'), false);
      expect(MesecniFilterFix.isValidPolazak(''), false);
      expect(MesecniFilterFix.isValidPolazak(null), false);
      expect(MesecniFilterFix.isValidPolazak('invalid'), false);
    });

    test('isValidStatus - filtriranje statusa', () {
      // ✅ Validni statusi
      expect(MesecniFilterFix.isValidStatus('aktivan'), true);
      expect(MesecniFilterFix.isValidStatus('placen'), true);
      expect(MesecniFilterFix.isValidStatus(null), true);
      expect(MesecniFilterFix.isValidStatus(''), true);

      // ❌ Nevalidni statusi
      expect(MesecniFilterFix.isValidStatus('bolovanje'), false);
      expect(MesecniFilterFix.isValidStatus('godišnje'), false);
      expect(MesecniFilterFix.isValidStatus('OTKAZAN'), false);
      expect(MesecniFilterFix.isValidStatus('obrisan'), false);
    });

    test('shouldIncludeMesecniPutnik - kompletan filter', () {
      // Mock putnik objekat
      final putnikMap = {
        'aktivan': true,
        'obrisan': false,
        'status': 'aktivan',
        'radni_dani': 'pon,uto,sre,cet,pet',
        'putnik_ime': 'Marko Petrović',
        'tip': 'ucenik',
        'tip_skole': 'osnovna',
      };

      // ✅ Trebao bi biti uključen
      expect(
        MesecniFilterFix.shouldIncludeMesecniPutnik(
          putnik: putnikMap,
          targetDay: 'pon',
          searchTerm: 'marko',
          filterType: 'ucenik',
        ),
        true,
      );

      // ❌ Ne treba biti uključen - pogrešan dan
      expect(
        MesecniFilterFix.shouldIncludeMesecniPutnik(
          putnik: putnikMap,
          targetDay: 'sub',
        ),
        false,
      );

      // ❌ Ne treba biti uključen - obrisan
      final obrisanPutnik = Map<String, dynamic>.from(putnikMap);
      obrisanPutnik['obrisan'] = true;

      expect(
        MesecniFilterFix.shouldIncludeMesecniPutnik(
          putnik: obrisanPutnik,
        ),
        false,
      );

      // ❌ Ne treba biti uključen - bolovanje
      final bolovanjeePutnik = Map<String, dynamic>.from(putnikMap);
      bolovanjeePutnik['status'] = 'bolovanje';

      expect(
        MesecniFilterFix.shouldIncludeMesecniPutnik(
          putnik: bolovanjeePutnik,
        ),
        false,
      );

      // ✅ Može biti uključen ako dozvoljavamo neaktivne statuse
      expect(
        MesecniFilterFix.shouldIncludeMesecniPutnik(
          putnik: bolovanjeePutnik,
          includeInactiveStatuses: true,
        ),
        true,
      );
    });

    test('getDayAbbreviation - mapiranje dana', () {
      expect(MesecniFilterFix.getDayAbbreviationFromName('ponedeljak'), 'pon');
      expect(MesecniFilterFix.getDayAbbreviationFromName('UTORAK'), 'uto');
      expect(MesecniFilterFix.getDayAbbreviationFromName('Sreda'), 'sre');
      expect(MesecniFilterFix.getDayAbbreviationFromName('nepoznat'), 'pon'); // fallback
    });
  });
}

/// 🔧 PRIMER KORIŠĆENJA U STVARNOM KODU
class ExampleUsage {
  /// Primer kako da zamenite postojeći kod filtriranja
  static List<Map<String, dynamic>> filtrirajMesecnePutnike({
    required List<Map<String, dynamic>> sviPutnici,
    String? targetDay,
    String? searchTerm,
    String? filterType,
  }) {
    return sviPutnici.where((putnik) {
      return MesecniFilterFix.shouldIncludeMesecniPutnik(
        putnik: putnik,
        targetDay: targetDay,
        searchTerm: searchTerm,
        filterType: filterType,
      );
    }).toList();
  }

  /// Primer SQL upita sa poboljšanom logikom
  static Future<List<Map<String, dynamic>>> loadMesecniPutnici({
    String? targetDay,
    bool activeOnly = true,
  }) async {
    // Umesto složenih Dart filtera, koristite optimizovani SQL
    final query = MesecniFilterFix.buildOptimizedQuery(
      targetDay: targetDay,
      activeOnly: activeOnly,
    );

    // Execute query with your Supabase client
    // return await supabase.rpc('custom_query', {'query': query});
    print('Generated SQL query: $query'); // Za debug
    return []; // placeholder
  }
}
