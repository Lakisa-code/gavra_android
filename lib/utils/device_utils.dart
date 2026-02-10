import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 🔧 DEVICE UTILITIES
/// Detekcija Huawei uređaja i provera instaliranih aplikacija
class DeviceUtils {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // 📱 Keširane vrednosti
  static bool? _isHuaweiDevice;
  static String? _deviceManufacturer;
  static bool? _isHereWeGoInstalled;

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

  /// 📱 Proveri da li je HERE WeGo instaliran
  static Future<bool> isHereWeGoInstalled() async {
    if (_isHereWeGoInstalled != null) return _isHereWeGoInstalled!;

    try {
      final testUri = Uri.parse('here-route://test');
      _isHereWeGoInstalled = await canLaunchUrl(testUri);
      return _isHereWeGoInstalled!;
    } catch (e) {
      _isHereWeGoInstalled = false;
      return false;
    }
  }
}
