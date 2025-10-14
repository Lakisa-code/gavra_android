import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/logging.dart';

// Use centralized logger

class UpdateService {
  static const String repoOwner = 'bojanbc83';
  static const String repoName = 'gavra_android';
  static const String githubApiUrl = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
  static const String _skippedVersionKey = 'skipped_update_version';
  static const String _lastCheckKey = 'last_update_check';
  static const String _lastInstalledVersionKey = 'last_installed_version';
  static const String _lastFoundVersionKey = 'last_found_version';

  // Timer za background proveru
  static Timer? _backgroundTimer;

  /// Pokreće background proveru svakih sat vremena
  static void startBackgroundUpdateCheck() {
    // Zaustavi postojeći timer ako postoji
    _backgroundTimer?.cancel();

    dlog('🔄 Pokretanje background update provere (svakih 60 min)');

    // Prva provera odmah
    _checkUpdateInBackground();

    // Timer za svakih sat vremena (60 minuta)
    _backgroundTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _checkUpdateInBackground();
    });
  }

  /// Zaustavlja background proveru
  static void stopBackgroundUpdateCheck() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    dlog('⏹️ Background update provera zaustavljena');
  }

  /// Tiha provera u pozadini bez UI-ja
  static Future<void> _checkUpdateInBackground() async {
    try {
      dlog('🔍 Background provera update-a...');

      // Trenutna verzija aplikacije
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // GitHub API poziv
      final response = await http.get(
        Uri.parse(githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Proveri da li release postoji i nije draft
        if (data['draft'] == true) {
          dlog('📝 Release je draft - nema update-a');
          return;
        }

        String latestVersion = (data['tag_name'] as String).replaceAll('v', '');

        dlog('🔍 Background: Current: $currentVersion, Latest: $latestVersion');

        // Ako su verzije iste, nema update-a
        if (currentVersion == latestVersion) {
          dlog('✅ Background: Verzije su iste - nema update-a');
          return;
        }

        // Proverava da li je novija verzija
        bool hasUpdate = _isNewerVersion(currentVersion, latestVersion);

        if (hasUpdate) {
          // Pamti poslednju pronađenu verziju (za buduće UI implementacije)
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_lastFoundVersionKey, latestVersion);

          dlog('🚀 Background: Nova verzija pronađena: $latestVersion');
          dlog('💾 Verzija sačuvana u SharedPreferences');
        } else {
          dlog('📊 Background: Nema novije verzije');
        }
      } else {
        dlog('❌ Background: GitHub API greška: ${response.statusCode}');
      }
    } catch (e) {
      dlog('❌ Background: Greška pri proveri: $e');
    }
  }

  /// Vraća poslednju pronađenu verziju (ako postoji)
  static Future<String?> getLastFoundVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastFoundVersionKey);
  }

  /// Pamti verziju koju je korisnik preskočio
  static Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedVersionKey, version);
    dlog('📝 Preskočena verzija: $version');
  }

  /// Pamti verziju koja je instalirana (kada korisnik klikne Download)
  static Future<void> markVersionAsInstalled(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastInstalledVersionKey, version);
    dlog('✅ Verzija označena kao instalirana: $version');
  }

  /// Proverava da li je verzija već instalirana
  static Future<bool> isVersionInstalled(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final installedVersion = prefs.getString(_lastInstalledVersionKey);
    return installedVersion == version;
  }

  /// Proverava da li je verzija već preskočena
  static Future<bool> isVersionSkipped(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final skippedVersion = prefs.getString(_skippedVersionKey);
    return skippedVersion == version;
  }

  /// Pamti kada je poslednji put proveravano
  static Future<void> _saveLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Proverava da li je prošlo dovoljno vremena od poslednje provere (24h)
  static Future<bool> _shouldCheckForUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastCheckKey);
    if (lastCheck == null) return true;

    final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheck);
    final now = DateTime.now();
    final hoursSinceLastCheck = now.difference(lastCheckTime).inHours;

    dlog('🕐 Sati od poslednje provere: $hoursSinceLastCheck');
    return hoursSinceLastCheck >= 1; // Proveravaj svakih sat vremena
  }

  /// Proverava da li je dostupna nova verzija
  static Future<bool> checkForUpdate() async {
    try {
      // Proverava da li je prošlo dovoljno vremena od poslednje provere
      if (!await _shouldCheckForUpdate()) {
        dlog('⏰ Prerano za novu proveru update-a');
        return false;
      }

      // Trenutna verzija aplikacije
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // GitHub API poziv
      final response = await http.get(
        Uri.parse(githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Proveri da li release postoji i nije draft
        if (data['draft'] == true) {
          dlog('📝 Release je draft - nema update-a');
          return false;
        }

        String latestVersion = (data['tag_name'] as String).replaceAll('v', '');

        dlog('🚀 Najnovija verzija na GitHub: $latestVersion');
        dlog('� Raw tag_name: ${data['tag_name']}');
        dlog('�🔍 Trenutna verzija aplikacije: $currentVersion');
        dlog('⚖️ String comparison: "$currentVersion" == "$latestVersion"');
        dlog('📊 Are equal? ${currentVersion == latestVersion}');

        // DIREKTNA PROVERA: Ako su verzije iste, NEMA UPDATE-a!
        if (currentVersion == latestVersion) {
          dlog(
            '✅ VERZIJE SU ISTE ($currentVersion == $latestVersion) - NEMA UPDATE-A!',
          );
          await _saveLastCheckTime();
          return false;
        }

        // Proverava da li je korisnik već preskočio ovu verziju
        if (await isVersionSkipped(latestVersion)) {
          dlog('⏭️ Verzija $latestVersion je već preskočena');
          await _saveLastCheckTime();
          return false;
        }

        // Proverava da li je ova verzija već "instalirana" (korisnik je već kliknuo Download)
        if (await isVersionInstalled(latestVersion)) {
          dlog('💿 Verzija $latestVersion je već instalirana/download-ovana');
          await _saveLastCheckTime();
          return false;
        }

        DateTime? publishedAt;
        try {
          publishedAt = DateTime.parse(data['published_at'] as String);
        } catch (e) {
          dlog('⚠️ Nemože da parsira datum objave');
        }

        dlog('🚀 Najnovija verzija na GitHub: $latestVersion');
        dlog('📅 Objavljena: ${publishedAt ?? "Nepoznato"}');

        // Dodatna provera - samo ako je release stvarno objavljen u poslednjih 7 dana
        // ili je verzija značajno veća (major update)
        bool hasUpdate = _isNewerVersion(currentVersion, latestVersion);

        if (hasUpdate && publishedAt != null) {
          final daysSincePublish = DateTime.now().difference(publishedAt).inDays;
          dlog('📊 Dana od objave: $daysSincePublish');

          // STROŽIJA PROVERA: Ako je release stariji od 7 dana, ne prikazuj update osim ako nije major verzija
          if (daysSincePublish > 7) {
            bool isMajorUpdate = _isMajorVersionDifference(currentVersion, latestVersion);
            if (!isMajorUpdate) {
              dlog(
                '🕰️ Release je prestari ($daysSincePublish dana), preskačem update',
              );
              await _saveLastCheckTime();
              return false;
            }
          }

          // Dodatno: Proverava da li je release "nightly" build - ne prikazuj update za nightly
          String releaseTag = (data['tag_name'] as String).toLowerCase();
          if (releaseTag.contains('nightly') || releaseTag.contains('beta') || releaseTag.contains('alpha')) {
            dlog('🌙 Nightly/Beta release - preskačem update');
            await _saveLastCheckTime();
            return false;
          }
        }

        dlog('📊 Ima update: $hasUpdate');
        dlog(
          '🔍 DETALJNO: $currentVersion vs $latestVersion = ${hasUpdate ? "TREBA UPDATE" : "NEMA UPDATE"}',
        );

        return hasUpdate;
      } else {
        dlog('❌ GitHub API greška: ${response.statusCode}');
      }
    } catch (e) {
      dlog('❌ Greška pri proveri update-a: $e');
    }
    return false;
  }

  /// Vraća informacije o najnovijoj verziji
  static Future<Map<String, dynamic>?> getLatestVersionInfo() async {
    try {
      final response = await http.get(
        Uri.parse(githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Pronađi APK asset u assets listi
        String? apkDownloadUrl;
        if (data['assets'] != null && (data['assets'] as List).isNotEmpty) {
          for (var asset in data['assets'] as List) {
            if (asset['name'] != null && asset['name'].toString().endsWith('.apk')) {
              apkDownloadUrl = asset['browser_download_url'] as String?;
              break;
            }
          }
        }

        // Fallback na GitHub release stranicu ako nema APK
        apkDownloadUrl ??= data['html_url'] as String?;

        dlog('🔗 Download URL: $apkDownloadUrl');

        return {
          'version': (data['tag_name'] as String).replaceAll('v', ''),
          'name': data['name'] ?? 'Nova verzija',
          'body': data['body'] ?? 'Poboljšanja i ispravke',
          'downloadUrl': apkDownloadUrl,
          'publishedAt': data['published_at'],
        };
      }
    } catch (e) {
      dlog('❌ Greška pri dobijanju info o verziji: $e');
    }
    return null;
  }

  /// Otvara download stranicu za novu verziju
  static Future<void> openUpdatePage() async {
    const url = 'https://github.com/$repoOwner/$repoName/releases/latest';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  /// Otvara direktan APK download
  static Future<void> downloadApk() async {
    final versionInfo = await getLatestVersionInfo();
    if (versionInfo != null && versionInfo['downloadUrl'] != null) {
      final url = versionInfo['downloadUrl'];
      if (await canLaunchUrl(Uri.parse(url as String))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Poredi da li je nova verzija novija od trenutne
  static bool _isNewerVersion(String current, String latest) {
    try {
      List<int> currentParts = current.split('.').map((e) => int.parse(e)).toList();
      List<int> latestParts = latest.split('.').map((e) => int.parse(e)).toList();

      // Dopuni sa nulama ako je potrebno
      while (currentParts.length < 3) {
        currentParts.add(0);
      }
      while (latestParts.length < 3) {
        latestParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
    } catch (e) {
      dlog('❌ Greška pri poređenju verzija: $e');
    }
    return false;
  }

  /// Proverava da li je razlika u verziji major (prva cifra)
  static bool _isMajorVersionDifference(String current, String latest) {
    try {
      List<int> currentParts = current.split('.').map((e) => int.parse(e)).toList();
      List<int> latestParts = latest.split('.').map((e) => int.parse(e)).toList();

      if (currentParts.isNotEmpty && latestParts.isNotEmpty) {
        return latestParts[0] > currentParts[0];
      }
    } catch (e) {
      dlog('❌ Greška pri proveri major verzije: $e');
    }
    return false;
  }
}

/// Update checker sa UI dijalogom
class UpdateChecker {
  static Future<void> checkAndShowUpdate(BuildContext context) async {
    try {
      bool hasUpdate = await UpdateService.checkForUpdate();

      if (hasUpdate && context.mounted) {
        final versionInfo = await UpdateService.getLatestVersionInfo();
        if (context.mounted) {
          _showUpdateDialog(context, versionInfo);
        }
      }
    } catch (e) {
      dlog('❌ Greška u automatskoj proveri: $e');
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    Map<String, dynamic>? versionInfo,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update, color: Theme.of(context).colorScheme.primary, size: 28),
            const SizedBox(width: 8),
            const Text('Nova verzija! 🚀'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (versionInfo != null) ...[
              Text(
                'Verzija: ${versionInfo['version']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(versionInfo['name'] as String? ?? 'Nova verzija'),
              const SizedBox(height: 8),
              const Text(
                'Šta je novo:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(versionInfo['body'] as String? ?? 'Poboljšanja i ispravke'),
            ] else ...[
              const Text('Dostupna je nova verzija Gavra Android aplikacije.'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Označi verziju kao preskočenu
              if (versionInfo != null && versionInfo['version'] != null) {
                UpdateService.skipVersion(versionInfo['version'] as String);
              }
              Navigator.pop(context);
            },
            child: const Text('Kasnije'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // Označi verziju kao instaliranu
              if (versionInfo != null && versionInfo['version'] != null) {
                UpdateService.markVersionAsInstalled(
                  versionInfo['version'] as String,
                );
              }
              Navigator.pop(context);
              UpdateService.downloadApk();
            },
            icon: const Icon(Icons.download),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }

  /// Manualna provera update-a (za dugme u settings)
  static Future<void> manualUpdateCheck(BuildContext context) async {
    // Pokazuj loading
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Proveravam update-e...'),
          ],
        ),
      ),
    );

    try {
      bool hasUpdate = await UpdateService.checkForUpdate();
      if (!context.mounted) return;
      Navigator.pop(context); // Zatvori loading

      if (hasUpdate) {
        final versionInfo = await UpdateService.getLatestVersionInfo();
        if (!context.mounted) return;
        _showUpdateDialog(context, versionInfo);
      } else {
        // Nema update-a
        if (!context.mounted) return;
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Nema update-a ✅'),
            content: const Text('Koristiš najnoviju verziju aplikacije.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Zatvori loading
      // Greška
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Greška ❌'),
          content: const Text(
            'Nemoguće proveriti update-e. Proverite internet konekciju.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}



