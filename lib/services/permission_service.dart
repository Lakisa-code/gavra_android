import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
// foundation import not needed here
import '../main.dart'; // Import za navigatorKey
import '../utils/logging.dart';

/// 🔐 CENTRALIZOVANI SERVIS ZA SVE DOZVOLE
/// Zahteva sve dozvole pri prvom pokretanju aplikacije
/// i zatim ih koristi automatski bez dodatnih pitanja
class PermissionService {
  static const String _firstLaunchKey = 'app_first_launch_permissions';

  /// 🚀 INICIJALNO ZAHTEVANJE SVIH DOZVOLA (poziva se u main.dart)
  static Future<bool> requestAllPermissionsOnFirstLaunch(
      BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool(_firstLaunchKey) ?? true;

    if (isFirstLaunch) {
      // Proveri da li je context još uvek aktivan pre korišćenja
      if (!context.mounted) return false;
      return await _showPermissionSetupDialog(context);
    }

    // Nije prvi pokret - proverava da li su dozvole i dalje aktivne
    return await _checkExistingPermissions();
  }

  /// 📱 DIALOG ZA POČETNO PODEŠAVANJE DOZVOLA
  static Future<bool> _showPermissionSetupDialog(BuildContext context) async {
    if (!context.mounted) return false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.security, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Podešavanje aplikacije'),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Za potpunu funkcionalnost aplikacije potrebne su sledeće dozvole:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              '📍 GPS lokacija - za navigaciju do putnika')),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.phone, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('📞 Pozivi - za kontaktiranje putnika')),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.message, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('📱 SMS poruke - za obaveštenja')),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.notifications, color: Colors.purple, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('🔔 Notifikacije - za nova putovanja')),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Dozvole se zahtevaju samo jednom. Možete ih kasnije promeniti u podešavanjima telefona.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('PRESKOČI'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Pozovi zahtevanje dozvola kada korisnik klikne dugme
                    final success = await requestAllPermissions();
                    if (context.mounted) {
                      Navigator.of(context).pop(success);
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('ODOBRI DOZVOLE'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// ✅ ZAHTEVANJE SVIH DOZVOLA ODJEDNOM
  static Future<bool> requestAllPermissions() async {
    try {
      // 1. 📍 LOKACIJA (obavezno za navigaciju)
      final locationStatus = await _requestLocationPermission();

      // 2. 📞 POZIVI (za kontakt sa putnicima)
      final phoneStatus = await Permission.phone.request();

      // 3. 📱 SMS (za slanje poruka)
      final smsStatus = await Permission.sms.request();

      // 4. 🔔 NOTIFIKACIJE (za obaveštenja)
      await Permission.notification.request();

      // Sačuvaj da su dozvole zatražene
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firstLaunchKey, false);

      // Vraća true ako su sve kritične dozvole odobrene
      final allCriticalGranted = locationStatus &&
          (phoneStatus.isGranted || phoneStatus.isLimited) &&
          (smsStatus.isGranted || smsStatus.isLimited);

      return allCriticalGranted;
    } catch (e) {
      dlog('❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// 🛰️ SPECIJALNO ZAHTEVANJE LOKACIJSKIH DOZVOLA
  static Future<bool> _requestLocationPermission() async {
    try {
      // Prvo proveri da li je Location Service uključen
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Pokušaj da uključi automatski
        await Geolocator.openLocationSettings();
        // Proveri ponovo
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      }

      // Zatim zahtevaj dozvole
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return serviceEnabled &&
          permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (e) {
      dlog('❌ Location permission error: $e');
      return false;
    }
  }

  /// 🔍 PROVERA POSTOJEĆIH DOZVOLA
  static Future<bool> _checkExistingPermissions() async {
    try {
      final location = await _isLocationPermissionGranted();
      final phone = await Permission.phone.status;
      final sms = await Permission.sms.status;

      return location &&
          (phone.isGranted || phone.isLimited) &&
          (sms.isGranted || sms.isLimited);
    } catch (e) {
      return false;
    }
  }

  /// 📍 BRZA PROVERA LOKACIJSKE DOZVOLE
  static Future<bool> _isLocationPermissionGranted() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();

      return serviceEnabled &&
          permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (e) {
      return false;
    }
  }

  /// 🚗 INSTANT GPS ZA NAVIGACIJU (bez dodatnih dialoga)
  static Future<bool> ensureGpsForNavigation() async {
    try {
      // Brza provera - ako je sve OK, samo nastavi
      final isReady = await _isLocationPermissionGranted();
      if (isReady) {
        return true;
      }

      // Proveri da li je GPS usluga uključena
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Pokaži upozorenje pre otvaranja settings
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          final shouldOpen = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.gps_off, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('GPS je isključen'),
                ],
              ),
              content: const Text(
                'Za navigaciju treba da uključite GPS u podešavanjima.\n\n'
                'Tapnite "Uključi GPS" da otvorite podešavanja.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Otkaži'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Uključi GPS'),
                ),
              ],
            ),
          );

          if (shouldOpen == true) {
            await Geolocator.openLocationSettings();
            // Sačekaj malo da korisnik uključi GPS
            await Future.delayed(const Duration(seconds: 2));
            serviceEnabled = await Geolocator.isLocationServiceEnabled();
          }
        } else {
          await Geolocator.openLocationSettings();
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return serviceEnabled &&
          permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (e) {
      return false;
    }
  }

  /// 📞 INSTANT POZIV (bez dodatnih dialoga)
  static Future<bool> ensurePhonePermission() async {
    try {
      final status = await Permission.phone.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }

      final result = await Permission.phone.request();
      return result.isGranted || result.isLimited;
    } catch (e) {
      return false;
    }
  }

  /// 📱 INSTANT SMS (bez dodatnih dialoga)
  static Future<bool> ensureSmsPermission() async {
    try {
      final status = await Permission.sms.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }

      final result = await Permission.sms.request();
      return result.isGranted || result.isLimited;
    } catch (e) {
      return false;
    }
  }

  /// 🔔 STATUS SVIH DOZVOLA
  static Future<Map<String, bool>> getPermissionStatus() async {
    return {
      'location': await _isLocationPermissionGranted(),
      'phone': (await Permission.phone.status).isGranted,
      'sms': (await Permission.sms.status).isGranted,
      'notification': (await Permission.notification.status).isGranted,
    };
  }

  /// ⚙️ OTVORI SETTINGS ZA RUČNO PODEŠAVANJE
  static Future<void> openPermissionSettings() async {
    // Otvori system settings za dozvole aplikacije
    try {
      await Permission.phone
          .request(); // Ovo će otvoriti settings ako je potrebno
    } catch (e) {
      dlog('❌ Error opening settings: $e');
    }
  }

  /// 🔧 HUAWEI SPECIFIČNA LOGIKA - Graceful handling na Huawei uređajima
  static Future<bool> ensureSmsPermissionHuawei() async {
    try {
      // Prvo pokušaj standardni pristup
      final status = await Permission.sms.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }

      // Huawei specifično - pokušaj zahtev
      final result = await Permission.sms.request();

      // Ako Huawei blokira dozvolu, nastavi sa URL launcher pristupom
      if (result.isDenied || result.isPermanentlyDenied) {
        dlog('🍎 HUAWEI: SMS dozvola odbijena, koristim URL launcher');
        return true; // Vraća true jer će koristiti URL launcher
      }

      return result.isGranted || result.isLimited;
    } catch (e) {
      dlog('🍎 HUAWEI: SMS permission error, fallback to URL launcher: $e');
      return true; // Fallback na URL launcher
    }
  }

  /// 📞 HUAWEI SPECIFIČNA LOGIKA - Phone permission
  static Future<bool> ensurePhonePermissionHuawei() async {
    try {
      final status = await Permission.phone.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }

      final result = await Permission.phone.request();

      // Huawei fallback
      if (result.isDenied || result.isPermanentlyDenied) {
        dlog('🍎 HUAWEI: Phone dozvola odbijena, koristim tel: URI');
        return true; // Vraća true jer će koristiti tel: URI
      }

      return result.isGranted || result.isLimited;
    } catch (e) {
      dlog('🍎 HUAWEI: Phone permission error, fallback to tel: URI: $e');
      return true; // Fallback na tel: URI
    }
  }
}
