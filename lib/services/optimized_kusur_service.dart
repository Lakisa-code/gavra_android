import 'dart:async';

import '../globals.dart';
import '../services/memory_management_service.dart';
import '../services/performance_optimizer_service.dart';
import 'vozac_mapping_service.dart';

/// 🚀 OPTIMIZED KUSUR SERVICE
/// Fixed memory leaks and improved performance
class OptimizedKusurService {
  OptimizedKusurService._internal();
  static OptimizedKusurService? _instance;
  static OptimizedKusurService get instance {
    _instance ??= OptimizedKusurService._internal();
    return _instance!;
  }

  /// 🔄 MANAGED STREAM CONTROLLER
  StreamController<Map<String, double>>? _kusurController;
  bool _isInitialized = false;

  /// Initialize service with managed resources
  void initialize() {
    if (_isInitialized) return;

    _kusurController = StreamController<Map<String, double>>.broadcast();
    MemoryManagementService()
        .registerStreamController('kusur_controller', _kusurController!);
    _isInitialized = true;
  }

  /// Ensure service is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      initialize();
    }
  }

  /// 💰 Get kusur for specific driver
  Future<double> getKusurForVozac(String vozacIme) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Mapiranje ime -> UUID
      final vozacUuid = await VozacMappingService.getVozacUuid(vozacIme);
      if (vozacUuid == null) {
        return 0.0;
      }

      final response = await supabase
          .from('vozaci')
          .select('kusur')
          .eq('id', vozacUuid)
          .maybeSingle();

      if (response != null && response['kusur'] != null) {
        return (response['kusur'] as num).toDouble();
      }

      return 0.0;
    } catch (e) {
      return 0.0;
    } finally {
      stopwatch.stop();
      PerformanceOptimizerService().trackOperation(
        'kusur_get_for_vozac',
        stopwatch.elapsed,
      );
    }
  }

  /// 💰 Update kusur for specific driver
  Future<bool> updateKusurForVozac(String vozacIme, double noviKusur) async {
    final stopwatch = Stopwatch()..start();

    try {
      _ensureInitialized();

      // Mapiranje ime -> UUID
      final vozacUuid = await VozacMappingService.getVozacUuid(vozacIme);
      if (vozacUuid == null) {
        return false;
      }

      await supabase
          .from('vozaci')
          .update({'kusur': noviKusur}).eq('id', vozacUuid);

      // Emit update through stream
      _emitKusurUpdate(vozacIme, noviKusur);

      return true;
    } catch (e) {
      return false;
    } finally {
      stopwatch.stop();
      PerformanceOptimizerService().trackOperation(
        'kusur_update_for_vozac',
        stopwatch.elapsed,
      );
    }
  }

  /// 🌊 Stream kusur for specific driver
  Stream<double> streamKusurForVozac(String vozacIme) async* {
    _ensureInitialized();

    // Send current value immediately
    final trenutniKusur = await getKusurForVozac(vozacIme);
    yield trenutniKusur;

    // Listen for updates
    if (_kusurController != null) {
      await for (final kusurMapa in _kusurController!.stream) {
        if (kusurMapa.containsKey(vozacIme)) {
          yield kusurMapa[vozacIme]!;
        }
      }
    }
  }

  /// 📊 Get kusur for all drivers
  Future<Map<String, double>> getKusurSvihVozaca() async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await supabase.from('vozaci').select('id, ime, kusur');

      final Map<String, double> rezultat = {};

      for (final row in response) {
        final ime = row['ime'] as String;
        final kusur = (row['kusur'] as num?)?.toDouble() ?? 0.0;
        rezultat[ime] = kusur;
      }

      return rezultat;
    } catch (e) {
      return {};
    } finally {
      stopwatch.stop();
      PerformanceOptimizerService().trackOperation(
        'kusur_get_all_vozaci',
        stopwatch.elapsed,
      );
    }
  }

  /// 🔄 Emit kusur update
  void _emitKusurUpdate(String vozacIme, double noviKusur) {
    if (_kusurController != null && !_kusurController!.isClosed) {
      PerformanceOptimizerService.batchUIUpdate('kusur_update', () {
        _kusurController!.add({vozacIme: noviKusur});
      });
    }
  }

  /// 🔄 Reset kusur to 0
  Future<bool> resetKusurForVozac(String vozacIme) async {
    return await updateKusurForVozac(vozacIme, 0.0);
  }

  /// ➕ Add amount to kusur
  Future<bool> dodajUKusur(String vozacIme, double iznos) async {
    final trenutniKusur = await getKusurForVozac(vozacIme);
    final noviKusur = trenutniKusur + iznos;
    return await updateKusurForVozac(vozacIme, noviKusur);
  }

  /// ➖ Subtract amount from kusur
  Future<bool> oduzmiIzKusur(String vozacIme, double iznos) async {
    final trenutniKusur = await getKusurForVozac(vozacIme);
    final noviKusur = (trenutniKusur - iznos).clamp(0.0, double.infinity);
    return await updateKusurForVozac(vozacIme, noviKusur);
  }

  /// 📊 Get service statistics
  Map<String, dynamic> getStatistics() {
    return {
      'initialized': _isInitialized,
      'controller_closed': _kusurController?.isClosed ?? true,
      'has_listeners': _kusurController?.hasListener ?? false,
    };
  }

  /// 🧹 Health check
  bool isHealthy() {
    if (!_isInitialized) return false;
    if (_kusurController == null) return false;
    if (_kusurController!.isClosed) return false;
    return true;
  }

  /// 🚫 Dispose resources
  void dispose() {
    if (!_isInitialized) return;

    try {
      if (_kusurController != null && !_kusurController!.isClosed) {
        _kusurController!.close();
      }

      MemoryManagementService().unregisterStreamController('kusur_controller');

      _kusurController = null;
      _isInitialized = false;
    } catch (e) {
      // Fail silently during disposal
    }
  }
}
