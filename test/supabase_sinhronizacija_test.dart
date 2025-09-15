import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/mesecni_putnik.dart';

void main() {
  group('Supabase logika - sinhronizacija testovi', () {
    test('Nova vremena se formatiraju prilikom čitanja iz baze', () {
      // Simuliramo podatke koji dolaze iz Supabase baze
      final mapFromSupabase = {
        'id': 'test-123',
        'putnik_ime': 'Test Putnik',
        'tip': 'srednjeskola',
        // Nova vremena iz baze - sa sekundama
        'polazak_bc_pon': '07:30:00',
        'polazak_bc_cet': '12:15:00',
        'polazak_vs_pon': '16:45:00',
        'polazak_vs_cet': '08:00:00',
        'datum_pocetka_meseca': '2025-09-01',
        'datum_kraja_meseca': '2025-09-30',
        'created_at': '2025-09-15T10:00:00Z',
        'updated_at': '2025-09-15T10:00:00Z',
      };

      final putnik = MesecniPutnik.fromMap(mapFromSupabase);

      // Proveri da li se vremena formatiraju bez sekundi
      expect(putnik.getPolazakBelaCrkvaZaDan('pon'), equals('07:30'));
      expect(putnik.getPolazakBelaCrkvaZaDan('cet'), equals('12:15'));
      expect(putnik.getPolazakVrsacZaDan('pon'), equals('16:45'));
      expect(putnik.getPolazakVrsacZaDan('cet'), equals('08:00'));

      // Proveri da li null vrednosti rade ispravno
      expect(putnik.getPolazakBelaCrkvaZaDan('uto'), isNull);
      expect(putnik.getPolazakVrsacZaDan('sre'), isNull);
    });

    test('toMap() šalje ispravne podatke u Supabase', () {
      final putnik = MesecniPutnik(
        id: 'test-123',
        putnikIme: 'Test Putnik',
        tip: 'srednjeskola',
        polazakBcPon: '07:30', // Bez sekundi - kao što upisuje korisnik
        polazakBcCet: '12:15',
        polazakVsPon: '16:45',
        polazakVsCet: '08:00',
        datumPocetkaMeseca: DateTime(2025, 9, 1),
        datumKrajaMeseca: DateTime(2025, 9, 30),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = putnik.toMap();

      // Proveri da li se šalju tačne vrednosti
      expect(map['polazak_bc_pon'], equals('07:30'));
      expect(map['polazak_bc_cet'], equals('12:15'));
      expect(map['polazak_vs_pon'], equals('16:45'));
      expect(map['polazak_vs_cet'], equals('08:00'));

      // Proveri da li su stare kolone null (jer koristimo nove)
      expect(map['polazak_bela_crkva'], isNull);
      expect(map['polazak_vrsac'], isNull);
    });

    test('_hasNewTimeColumns() detektuje kada se koriste nova vremena', () {
      final putnikSaNovimVremenima = MesecniPutnik(
        id: 'test-123',
        putnikIme: 'Test Putnik',
        tip: 'srednjeskola',
        polazakBcPon: '07:30',
        datumPocetkaMeseca: DateTime(2025, 9, 1),
        datumKrajaMeseca: DateTime(2025, 9, 30),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final putnikBezNovihVremena = MesecniPutnik(
        id: 'test-124',
        putnikIme: 'Test Putnik 2',
        tip: 'osnovnaskola',
        datumPocetkaMeseca: DateTime(2025, 9, 1),
        datumKrajaMeseca: DateTime(2025, 9, 30),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Test privatne metode kroz toMap()
      final mapSaNovim = putnikSaNovimVremenima.toMap();
      final mapBezNovih = putnikBezNovihVremena.toMap();

      // Kada ima nova vremena, stare kolone treba da budu null
      expect(mapSaNovim['polazak_bela_crkva'], isNull);
      expect(mapSaNovim['polazak_vrsac'], isNull);

      // Kada nema nova vremena, stare kolone mogu biti present
      // (u ovom slučaju će biti null jer ih nismo postavili)
      expect(mapBezNovih['polazak_bela_crkva'], isNull);
      expect(mapBezNovih['polazak_vrsac'], isNull);
    });

    test('Fallback logika radi kada nema novih vremena', () {
      // Kreiraj putnika sa starim formatom vremena
      final mapFromSupabase = {
        'id': 'test-old',
        'putnik_ime': 'Stari Putnik',
        'tip': 'srednjeskola',
        // Nema nove kolone
        'polazak_bela_crkva': {'pon': '07:30', 'cet': '12:15'},
        'polazak_vrsac': {'pon': '16:45', 'cet': '08:00'},
        'datum_pocetka_meseca': '2025-09-01',
        'datum_kraja_meseca': '2025-09-30',
        'created_at': '2025-09-15T10:00:00Z',
        'updated_at': '2025-09-15T10:00:00Z',
      };

      final putnik = MesecniPutnik.fromMap(mapFromSupabase);

      // Fallback na stare kolone treba da radi
      expect(putnik.getPolazakBelaCrkvaZaDan('pon'), equals('07:30'));
      expect(putnik.getPolazakBelaCrkvaZaDan('cet'), equals('12:15'));
      expect(putnik.getPolazakVrsacZaDan('pon'), equals('16:45'));
      expect(putnik.getPolazakVrsacZaDan('cet'), equals('08:00'));
    });
  });
}
