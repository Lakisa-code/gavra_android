import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class V3BlockingScreenService {
  V3BlockingScreenService._();

  static final V3BlockingScreenService instance = V3BlockingScreenService._();

  Timer? _scheduleTimer;
  Map<String, Timer>? _terminTimers; // termin_id -> Timer
  bool _isBlockingScreenShown = false;

  bool get isBlockingScreenShown => _isBlockingScreenShown;

  /// Callback za prikazivanje blokirajućeg ekrana
  void Function(String grad, String vreme)? onShowBlockingScreen;

  /// Callback za gašenje tracking-a
  Future<void> Function()? onStopTracking;

  /// Callback za proveru aktivnih putnika
  Future<bool> Function()? hasActivePassengers;

  /// Inicijalizuje servis i učitava raspored
  Future<void> initialize() async {
    try {
      final response = await Supabase.instance.client
          .from('v3_app_settings')
          .select('bc_custom_by_day, vs_custom_by_day')
          .single();

      final bcSchedule = response['bc_custom_by_day'] as Map<String, dynamic>;
      final vsSchedule = response['vs_custom_by_day'] as Map<String, dynamic>;

      _scheduleBlockingScreens(bcSchedule, vsSchedule);
    } catch (e) {
      debugPrint('[V3BlockingScreenService] initialization error: $e');
    }
  }

  /// Planira blokirajuće ekrane na osnovu rasporeda
  void _scheduleBlockingScreens(
      Map<String, dynamic> bcSchedule, Map<String, dynamic> vsSchedule) {
    _terminTimers?.clear();
    _terminTimers = {};

    final now = DateTime.now();
    final today = _getDayName(now.weekday);

    // Dobavi termin vremena za danas
    final bcTimes = bcSchedule[today] as List<dynamic>?;
    final vsTimes = vsSchedule[today] as List<dynamic>?;

    if (bcTimes != null) {
      for (final time in bcTimes) {
        _scheduleForTermin('BC', time as String, now);
      }
    }

    if (vsTimes != null) {
      for (final time in vsTimes) {
        _scheduleForTermin('VS', time as String, now);
      }
    }
  }

  /// Planira blokirajući ekran za jedan termin
  void _scheduleForTermin(String grad, String timeStr, DateTime now) {
    final terminTime = _parseTime(timeStr);
    if (terminTime == null) return;

    final terminDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      terminTime.hour,
      terminTime.minute,
    );

    final blockingTime = terminDateTime.subtract(const Duration(minutes: 15));

    // Ako je vreme prošlo, preskoči
    if (blockingTime.isBefore(now)) {
      return;
    }

    final delay = blockingTime.difference(now);

    final timer = Timer(delay, () {
      _onBlockingTimeReached(grad, timeStr);
    });

    final terminKey = '${grad}_$timeStr';
    _terminTimers![terminKey] = timer;

    debugPrint('[V3BlockingScreenService] Scheduled blocking for $grad $timeStr at $blockingTime');
  }

  /// Kada stigne vreme za blokirajući ekran
  Future<void> _onBlockingTimeReached(String grad, String vreme) async {
    debugPrint('[V3BlockingScreenService] Blocking time reached for $grad $vreme');

    // Prvo proveri da li treba da zaustavi tracking
    await _smartStopTracking();

    // Zatim prikaži blokirajući ekran
    _showBlockingScreen(grad, vreme);
  }

  /// Pametno gašenje tracking-a (vremenski + statusni uslov)
  Future<void> _smartStopTracking() async {
    // Vremenski uslov: uvek zaustavi kada stigne novo vreme
    if (onStopTracking != null) {
      await onStopTracking!();
    }

    // Statusni uslov: proveri da li ima aktivnih putnika
    // Ako nema, tracking je već zaustavljen gore
    // Ako ima, tracking će biti zaustavljen ali vozač može da ga ponovo pokrene
  }

  /// Prikazuje blokirajući ekran
  void _showBlockingScreen(String grad, String vreme) {
    _isBlockingScreenShown = true;
    if (onShowBlockingScreen != null) {
      onShowBlockingScreen!(grad, vreme);
    }
  }

  /// Poziva se kada vozač klikne START na blokirajućem ekranu
  void onBlockingScreenDismissed() {
    _isBlockingScreenShown = false;
  }

  /// Parsira vreme string u TimeOfDay
  TimeOfDay? _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Vraća ime dana na engleskom
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Ponedeljak';
      case 2:
        return 'Utorak';
      case 3:
        return 'Sreda';
      case 4:
        return 'Cetvrtak';
      case 5:
        return 'Petak';
      case 6:
        return 'Subota';
      case 7:
        return 'Nedelja';
      default:
        return 'Ponedeljak';
    }
  }

  /// Čisti sve timere
  void dispose() {
    _scheduleTimer?.cancel();
    _terminTimers?.forEach((_, timer) => timer.cancel());
    _terminTimers?.clear();
  }
}
