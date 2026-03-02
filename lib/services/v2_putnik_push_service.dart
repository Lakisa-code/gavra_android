import 'package:flutter/foundation.dart';

import 'realtime/v2_master_realtime_manager.dart';
import 'v2_firebase_service.dart';
import 'v2_huawei_push_service.dart';
import 'v2_push_token_service.dart';

/// Servis za registraciju push tokena putnika.
/// Koristi unificirani PushTokenService za registraciju.
class V2PutnikPushService {
  V2PutnikPushService._();

  /// Registruje push token za putnika u push_tokens tabelu.
  /// Koristi unificirani PushTokenService
  static Future<bool> registerPutnikToken(dynamic putnikId, {String? putnikTabela}) async {
    try {
      debugPrint('[PutnikPush] Registrujem token za putnika: $putnikId');

      String? token;
      String? provider;

      // Prvo pokusaj FCM (GMS uredjaji)
      token = await FirebaseService.getFCMToken();
      if (token != null && token.isNotEmpty) {
        provider = 'fcm';
        debugPrint('[PutnikPush] FCM token dobijen: ${token.substring(0, token.length.clamp(0, 20))}...');
      } else {
        debugPrint('[PutnikPush] FCM token nije dostupan, pokusavam HMS...');
        // Fallback na HMS (Huawei uredjaji)
        token = await HuaweiPushService().initialize();
        if (token != null && token.isNotEmpty) {
          provider = 'huawei';
          debugPrint('[PutnikPush] HMS token dobijen: ${token.substring(0, token.length.clamp(0, 20))}...');
        }
      }

      if (token == null || provider == null) {
        debugPrint('[PutnikPush] Nijedan push provider nije dostupan!');
        return false;
      }

      // Koristi prosledjenu putnikTabela, fallback na cache
      final resolvedTabela = putnikTabela ??
          V2MasterRealtimeManager.instance.getPutnikById(putnikId?.toString() ?? '')?['putnik_tabela']?.toString();
      debugPrint('[PutnikPush] putnikTabela: $resolvedTabela');

      // Koristi unificirani PushTokenService
      final success = await V2PushTokenService.registerToken(
        token: token,
        provider: provider,
        putnikId: putnikId?.toString(),
        putnikTabela: resolvedTabela,
      );

      debugPrint('[PutnikPush] Registracija ${success ? 'uspesna' : 'neuspesna'}');
      return success;
    } catch (e) {
      debugPrint('[PutnikPush] Greška pri registraciji: $e');
      return false;
    }
  }
}
