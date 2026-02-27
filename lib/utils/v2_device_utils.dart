import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// 🔧 DEVICE UTILITIES
/// Detekcija Huawei uređaja i provera instaliranih aplikacija
class DeviceUtils {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // 📱 Keširane vrednosti
  static bool? _isHuaweiDevice;
  static String? _deviceManufacturer;

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
}
