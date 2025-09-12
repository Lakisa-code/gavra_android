import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static const String repoOwner = 'bojanbc83';
  static const String repoName = 'gavra_android';
  static const String githubApiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// Proverava da li je dostupna nova verzija
  static Future<bool> checkForUpdate() async {
    try {
      // Trenutna verzija aplikacije
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      debugPrint('🔍 Trenutna verzija: $currentVersion');
      debugPrint('📱 Build number: ${packageInfo.buildNumber}');
      debugPrint('📦 Package name: ${packageInfo.packageName}');
      debugPrint(
          '🏗️ Build mode: ${packageInfo.buildSignature.isEmpty ? "RELEASE" : "DEBUG"}');

      // GitHub API poziv
      final response = await http.get(
        Uri.parse(githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Proveri da li release postoji i nije draft
        if (data['draft'] == true) {
          debugPrint('📝 Release je draft - nema update-a');
          return false;
        }

        String latestVersion = data['tag_name'].replaceAll('v', '');

        debugPrint('🚀 Najnovija verzija na GitHub: $latestVersion');
        debugPrint('� Raw tag_name: ${data['tag_name']}');
        debugPrint('�🔍 Trenutna verzija aplikacije: $currentVersion');
        debugPrint(
            '⚖️ String comparison: "$currentVersion" == "$latestVersion"');
        debugPrint('📊 Are equal? ${currentVersion == latestVersion}');

        // DIREKTNA PROVERA: Ako su verzije iste, NEMA UPDATE-a!
        if (currentVersion == latestVersion) {
          debugPrint(
              '✅ VERZIJE SU ISTE ($currentVersion == $latestVersion) - NEMA UPDATE-A!');
          return false;
        }

        DateTime? publishedAt;
        try {
          publishedAt = DateTime.parse(data['published_at']);
        } catch (e) {
          debugPrint('⚠️ Nemože da parsira datum objave');
        }

        debugPrint('🚀 Najnovija verzija na GitHub: $latestVersion');
        debugPrint('📅 Objavljena: ${publishedAt ?? "Nepoznato"}');

        // Dodatna provera - samo ako je release stvarno objavljen u poslednjih 30 dana
        // ili je verzija značajno veća
        bool hasUpdate = _isNewerVersion(currentVersion, latestVersion);

        if (hasUpdate && publishedAt != null) {
          final daysSincePublish =
              DateTime.now().difference(publishedAt).inDays;
          debugPrint('📊 Dana od objave: $daysSincePublish');

          // Ako je release stariji od 30 dana, ne prikazuj update osim ako nije major verzija
          if (daysSincePublish > 30) {
            bool isMajorUpdate =
                _isMajorVersionDifference(currentVersion, latestVersion);
            if (!isMajorUpdate) {
              debugPrint(
                  '🕰️ Release je prestari ($daysSincePublish dana), preskačem update');
              return false;
            }
          }
        }

        debugPrint('📊 Ima update: $hasUpdate');
        debugPrint(
            '🔍 DETALJNO: $currentVersion vs $latestVersion = ${hasUpdate ? "TREBA UPDATE" : "NEMA UPDATE"}');

        return hasUpdate;
      } else {
        debugPrint('❌ GitHub API greška: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Greška pri proveri update-a: $e');
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
        if (data['assets'] != null && data['assets'].isNotEmpty) {
          for (var asset in data['assets']) {
            if (asset['name'] != null && asset['name'].toString().endsWith('.apk')) {
              apkDownloadUrl = asset['browser_download_url'];
              break;
            }
          }
        }
        
        // Fallback na GitHub release stranicu ako nema APK
        apkDownloadUrl ??= data['html_url'];
        
        debugPrint('🔗 Download URL: $apkDownloadUrl');
        
        return {
          'version': data['tag_name'].replaceAll('v', ''),
          'name': data['name'] ?? 'Nova verzija',
          'body': data['body'] ?? 'Poboljšanja i ispravke',
          'downloadUrl': apkDownloadUrl,
          'publishedAt': data['published_at'],
        };
      }
    } catch (e) {
      debugPrint('❌ Greška pri dobijanju info o verziji: $e');
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
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Poredi da li je nova verzija novija od trenutne
  static bool _isNewerVersion(String current, String latest) {
    try {
      List<int> currentParts =
          current.split('.').map((e) => int.parse(e)).toList();
      List<int> latestParts =
          latest.split('.').map((e) => int.parse(e)).toList();

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
      debugPrint('❌ Greška pri poređenju verzija: $e');
    }
    return false;
  }

  /// Proverava da li je razlika u verziji major (prva cifra)
  static bool _isMajorVersionDifference(String current, String latest) {
    try {
      List<int> currentParts =
          current.split('.').map((e) => int.parse(e)).toList();
      List<int> latestParts =
          latest.split('.').map((e) => int.parse(e)).toList();

      if (currentParts.isNotEmpty && latestParts.isNotEmpty) {
        return latestParts[0] > currentParts[0];
      }
    } catch (e) {
      debugPrint('❌ Greška pri proveri major verzije: $e');
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
      debugPrint('❌ Greška u automatskoj proveri: $e');
    }
  }

  static void _showUpdateDialog(
      BuildContext context, Map<String, dynamic>? versionInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Nova verzija! 🚀'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (versionInfo != null) ...[
              Text('Verzija: ${versionInfo['version']}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(versionInfo['name'] ?? 'Nova verzija'),
              const SizedBox(height: 8),
              const Text('Šta je novo:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(versionInfo['body'] ?? 'Poboljšanja i ispravke'),
            ] else ...[
              const Text('Dostupna je nova verzija Gavra Android aplikacije.'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kasnije'),
          ),
          ElevatedButton.icon(
            onPressed: () {
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
    showDialog(
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
        showDialog(
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
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Greška ❌'),
          content: const Text(
              'Nemoguće proveriti update-e. Proverite internet konekciju.'),
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
