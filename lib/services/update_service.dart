import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Manual update/browser functions removed; background check only.

// Update service for checking GitHub releases

class UpdateService {
  static const String repoOwner = 'bojanbc83';
  static const String repoName = 'gavra_android';
  static const String githubApiUrl = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
  static const String _lastCheckKey = 'last_update_check';
  // removed last_found_version key - no manual storage for update info

  // Timer za background proveru
  static Timer? _backgroundTimer;

  /// Pokreće background proveru svakih sat vremena
  static void startBackgroundUpdateCheck() {
    // Zaustavi postojeći timer ako postoji
    _backgroundTimer?.cancel();
    // Starting background update check

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
    // Background update check stopped
  }

  /// Tiha provera u pozadini bez UI-ja
  static Future<void> _checkUpdateInBackground() async {
    try {
      // Background update check started

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
          // Release is draft - no update
          return;
        }

        String latestVersion = (data['tag_name'] as String).replaceAll('v', '');

        // Version comparison
        // Ako su verzije iste, nema update-a
        if (currentVersion == latestVersion) {
          // Versions are same - no update
          return;
        }

        // Proverava da li je novija verzija
        bool hasUpdate = _isNewerVersion(currentVersion, latestVersion);

        if (hasUpdate) {
          // Found new version (background-only) - not storing manual flags
        }
      }
    } catch (e) {
      // Error handling - logging removed for production
    }
  }

  // getLastFoundVersion removed - we do not persist manual update metadata

  // Manual/manual UI related methods (skip/mark/is installed) removed

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

    // Check every hour
    return hoursSinceLastCheck >= 1;
  }

  /// Proverava da li je dostupna nova verzija
  static Future<bool> checkForUpdate() async {
    try {
      // Proverava da li je prošlo dovoljno vremena od poslednje provere
      if (!await _shouldCheckForUpdate()) {
        // Too early for new check
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
          // Release is draft - no update
          return false;
        }

        String latestVersion = (data['tag_name'] as String).replaceAll('v', '');

        // Version comparison completed

        // DIREKTNA PROVERA: Ako su verzije iste, NEMA UPDATE-a!
        if (currentVersion == latestVersion) {
          // Versions are same - no update
          await _saveLastCheckTime();
          return false;
        }

        // NOTE: Skipping or installed checks removed (manual UI removed)

        DateTime? publishedAt;
        try {
          publishedAt = DateTime.parse(data['published_at'] as String);
        } catch (e) {
          // Cannot parse publish date
        }

        // Version information processed

        // Dodatna provera - samo ako je release stvarno objavljen u poslednjih 7 dana
        // ili je verzija značajno veća (major update)
        bool hasUpdate = _isNewerVersion(currentVersion, latestVersion);

        if (hasUpdate && publishedAt != null) {
          final daysSincePublish = DateTime.now().difference(publishedAt).inDays;

          // STROŽIJA PROVERA: Ako je release stariji od 7 dana, ne prikazuj update osim ako nije major verzija
          if (daysSincePublish > 7) {
            bool isMajorUpdate = _isMajorVersionDifference(currentVersion, latestVersion);
            if (!isMajorUpdate) {
              // Release is too old, skipping update
              await _saveLastCheckTime();
              return false;
            }
          }

          // Dodatno: Proverava da li je release "nightly" build - ne prikazuj update za nightly
          String releaseTag = (data['tag_name'] as String).toLowerCase();
          if (releaseTag.contains('nightly') || releaseTag.contains('beta') || releaseTag.contains('alpha')) {
            // Nightly/Beta release - skip update
            await _saveLastCheckTime();
            return false;
          }
        }

        // Update check completed
        return hasUpdate;
      }
    } catch (e) {
      // Error handling - logging removed for production
    }
    return false;
  }

  // Manual UI methods for opening/downloading update removed

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
      // Error handling - logging removed for production
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
      // Error handling - logging removed for production
    }
    return false;
  }
}

// Note: Manual/manual UI update methods removed — the app uses automatic background checks only.

// Manual update UI removed; only automatic background update checks remain.
