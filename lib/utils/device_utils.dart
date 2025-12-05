import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'navigation_provider.dart';

/// 🔧 DEVICE UTILITIES
/// Detekcija Huawei uređaja i provera instaliranih navigacionih aplikacija
class DeviceUtils {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // 🔑 SharedPreferences ključevi
  static const String _huaweiDialogShownKey = 'huawei_herewego_dialog_shown';
  static const String _preferredNavProviderKey = 'preferred_nav_provider';

  // 📱 Keširane vrednosti
  static bool? _isHuaweiDevice;
  static String? _deviceManufacturer;
  static Map<NavigationProvider, bool>? _installedApps;

  /// 🔍 Proveri da li je uređaj Huawei/Honor
  static Future<bool> isHuaweiDevice() async {
    if (_isHuaweiDevice != null) return _isHuaweiDevice!;

    if (!Platform.isAndroid) {
      _isHuaweiDevice = false;
      return false;
    }

    try {
      final androidInfo = await _deviceInfo.androidInfo;
      _deviceManufacturer = androidInfo.manufacturer.toLowerCase();

      _isHuaweiDevice = _deviceManufacturer!.contains('huawei') || _deviceManufacturer!.contains('honor');

      return _isHuaweiDevice!;
    } catch (e) {
      _isHuaweiDevice = false;
      return false;
    }
  }

  /// 🔍 Dobij proizvođača uređaja
  static Future<String> getDeviceManufacturer() async {
    if (_deviceManufacturer != null) return _deviceManufacturer!;

    if (!Platform.isAndroid) return 'unknown';

    try {
      final androidInfo = await _deviceInfo.androidInfo;
      _deviceManufacturer = androidInfo.manufacturer.toLowerCase();
      return _deviceManufacturer!;
    } catch (e) {
      return 'unknown';
    }
  }

  /// 📱 Proveri da li je navigaciona aplikacija instalirana
  static Future<bool> isAppInstalled(NavigationProvider provider) async {
    // Keširaj rezultate
    _installedApps ??= {};

    if (_installedApps!.containsKey(provider)) {
      return _installedApps![provider]!;
    }

    try {
      // Probaj da otvoriš URL scheme bez stvarnog otvaranja
      final testUri = Uri.parse('${provider.urlScheme}://test');
      final canLaunch = await canLaunchUrl(testUri);

      _installedApps![provider] = canLaunch;

      return canLaunch;
    } catch (e) {
      _installedApps![provider] = false;
      return false;
    }
  }

  /// 🧭 Dobij dostupnu navigacionu aplikaciju (uvek HERE WeGo)
  static Future<NavigationProvider?> getAvailableNavigationApp() async {
    // Proveri da li je HERE WeGo instaliran
    if (await isAppInstalled(NavigationProvider.hereWeGo)) {
      return NavigationProvider.hereWeGo;
    }

    // HERE WeGo nije instaliran
    return null;
  }

  /// 📱 Dobij listu svih instaliranih navigacionih aplikacija
  static Future<List<NavigationProvider>> getInstalledNavigationApps() async {
    final installed = <NavigationProvider>[];

    if (await isAppInstalled(NavigationProvider.hereWeGo)) {
      installed.add(NavigationProvider.hereWeGo);
    }

    return installed;
  }

  /// 💾 Da li je Huawei HERE WeGo dialog već prikazan?
  static Future<bool> wasHuaweiDialogShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_huaweiDialogShownKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 💾 Označi da je Huawei HERE WeGo dialog prikazan
  static Future<void> markHuaweiDialogShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_huaweiDialogShownKey, true);
    } catch (_) {
      // Greška pri čuvanju
    }
  }

  /// 💾 Sačuvaj preferiranu navigacionu aplikaciju
  static Future<void> setPreferredNavigationProvider(NavigationProvider provider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferredNavProviderKey, provider.packageName);
    } catch (_) {
      // Greška pri čuvanju
    }
  }

  /// 💾 Dobij preferiranu navigacionu aplikaciju
  static Future<NavigationProvider?> getPreferredNavigationProvider() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final packageName = prefs.getString(_preferredNavProviderKey);

      if (packageName == null) return null;

      return NavigationProvider.values.cast<NavigationProvider?>().firstWhere(
            (p) => p?.packageName == packageName,
            orElse: () => null,
          );
    } catch (e) {
      return null;
    }
  }

  /// 🔄 Resetuj keš (za testiranje)
  static void resetCache() {
    _isHuaweiDevice = null;
    _deviceManufacturer = null;
    _installedApps = null;
  }

  /// 🔄 Resetuj sve preferencije (za testiranje)
  static Future<void> resetPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_huaweiDialogShownKey);
      await prefs.remove(_preferredNavProviderKey);
    } catch (_) {
      // Greška pri resetovanju
    }
  }
}
