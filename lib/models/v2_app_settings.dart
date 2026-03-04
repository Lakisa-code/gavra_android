/// Model za globalna podešavanja aplikacije (v2_app_settings tabela)
class V2AppSettings {
  final String id;
  final String minVersion;
  final String latestVersion;
  final String? storeUrlAndroid;
  final String? storeUrlHuawei;
  final String? storeUrlIos;
  final String? navBarType;
  final DateTime? updatedAt;

  V2AppSettings({
    required this.id,
    required this.minVersion,
    required this.latestVersion,
    this.storeUrlAndroid,
    this.storeUrlHuawei,
    this.storeUrlIos,
    this.navBarType,
    this.updatedAt,
  });

  factory V2AppSettings.fromJson(Map<String, dynamic> json) {
    return V2AppSettings(
      id: json['id'] as String? ?? '',
      minVersion: json['min_version'] as String? ?? '1.0.0',
      latestVersion: json['latest_version'] as String? ?? '1.0.0',
      storeUrlAndroid: json['store_url_android'] as String?,
      storeUrlHuawei: json['store_url_huawei'] as String?,
      storeUrlIos: json['store_url_ios'] as String?,
      navBarType: json['nav_bar_type'] as String?,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'min_version': minVersion,
      'latest_version': latestVersion,
      'store_url_android': storeUrlAndroid,
      'store_url_huawei': storeUrlHuawei,
      'store_url_ios': storeUrlIos,
      'nav_bar_type': navBarType,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
