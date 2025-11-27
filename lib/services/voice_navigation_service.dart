import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/putnik.dart';
import '../models/turn_by_turn_instruction.dart';

/// 🔊 BESPLATNO VOICE NAVIGATION SISTEM
/// Koristi flutter_tts za audio instrukcije na srpskom jeziku
class VoiceNavigationService {
  static FlutterTts? _flutterTts;
  static AudioSession? _audioSession;
  static bool _isInitialized = false;
  static bool _isSpeaking = false;
  static final String _currentLanguage = 'sr-RS'; // Srpski jezik

  // Navigation state
  static List<TurnByTurnInstruction> _currentInstructions = [];
  static int _currentInstructionIndex = 0;
  static StreamSubscription<Position>? _positionSubscription;

  // Voice settings
  static double _speechRate = 0.8; // Sporije za bolje razumevanje
  static double _volume = 1.0;
  static double _pitch = 1.0;

  /// 🚀 INITIALIZE VOICE NAVIGATION
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize TTS
      _flutterTts = FlutterTts();

      // Initialize audio session
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.longFormAudio,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.audibilityEnforced,
            usage: AndroidAudioUsage.assistant,
          ),
          androidWillPauseWhenDucked: true,
        ),
      );

      // Configure TTS
      await _configureTts();

      // Load saved preferences
      await _loadVoiceSettings();

      _isInitialized = true;
    } catch (e) {
      // Silent fail - voice navigation je optional feature
    }
  }

  /// 🔊 START VOICE NAVIGATION SA INSTRUKCIJAMA
  static Future<void> startVoiceNavigation({
    required List<TurnByTurnInstruction> instructions,
    required List<Putnik> route,
  }) async {
    if (!_isInitialized) await initialize();

    _currentInstructions = instructions;
    _currentInstructionIndex = 0;

    // Početna poruka
    await speak('Navigacija pokrenuta. ${route.length} putnika na listi.');

    // Prva instrukcija
    if (_currentInstructions.isNotEmpty) {
      await _speakCurrentInstruction();
    }

    // Pokreni GPS tracking za turn-by-turn
    await _startGpsTracking();
  }

  /// 🛑 STOP VOICE NAVIGATION
  static Future<void> stopVoiceNavigation() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    await stopSpeaking();
    await speak('Navigacija završena.');

    _currentInstructions.clear();
    _currentInstructionIndex = 0;
  }

  /// 🔊 SPEAK TEXT (glavna TTS funkcija)
  static Future<void> speak(String text) async {
    if (!_isInitialized || text.isEmpty) return;

    try {
      // Prekini trenutni govor
      await stopSpeaking();

      _isSpeaking = true;

      // Pripremi tekst za srpski govor
      final processedText = _preprocessTextForSerbianTts(text);

      // Speak
      await _flutterTts!.speak(processedText);

      // Wait for completion
      await _waitForSpeechCompletion();
    } catch (e) {
      _isSpeaking = false;
    }
  }

  /// 🛑 STOP CURRENT SPEECH
  static Future<void> stopSpeaking() async {
    if (_flutterTts != null && _isSpeaking) {
      await _flutterTts!.stop();
      _isSpeaking = false;
    }
  }

  /// 📢 ANNOUNCE PASSENGER PICKUP
  static Future<void> announcePassengerPickup(Putnik putnik) async {
    final kartaTip = (putnik.mesecnaKarta == true) ? 'Mesečna karta.' : 'Jednokratna karta.';
    final announcement = 'Sledeći putnik: ${putnik.ime}. '
        'Adresa: ${putnik.adresa}. '
        '$kartaTip';

    await speak(announcement);
  }

  /// 📢 ANNOUNCE NEXT UNPICKED PASSENGER FROM OPTIMIZED ROUTE
  /// Pronalazi sledećeg nepokupljenog putnika i najavljuje ga
  static Future<void> announceNextPassenger(List<Putnik> optimizedRoute) async {
    // Pronađi prvog nepokupljenog (koji nije otkazan i nije na odsustvu)
    final next = optimizedRoute.where((p) => p.vremePokupljenja == null && !p.jeOtkazan && !p.jeOdsustvo).firstOrNull;

    if (next != null) {
      await announcePassengerPickup(next);
    } else {
      // Svi pokupljeni
      final pokupljeno = optimizedRoute.where((p) => p.vremePokupljenja != null).length;
      await announceRouteCompletion(pokupljeno);
    }
  }

  /// 📢 ANNOUNCE ROUTE COMPLETION
  static Future<void> announceRouteCompletion(int totalPassengers) async {
    await speak('Ruta završena. Ukupno pokupljeno $totalPassengers putnika.');
  }

  /// 📢 ANNOUNCE DISTANCE TO DESTINATION
  static Future<void> announceDistanceToDestination(
    double distanceMeters,
  ) async {
    String distanceText;

    if (distanceMeters < 100) {
      distanceText = 'Manje od sto metara do destinacije.';
    } else if (distanceMeters < 1000) {
      final meters = (distanceMeters / 50).round() * 50; // Round to nearest 50m
      distanceText = '$meters metara do destinacije.';
    } else {
      final km = (distanceMeters / 1000).toStringAsFixed(1);
      distanceText = '$km kilometara do destinacije.';
    }

    await speak(distanceText);
  }

  /// ⚙️ VOICE SETTINGS
  static Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 2.0);
    await _flutterTts?.setSpeechRate(_speechRate);
    await _saveVoiceSettings();
  }

  static Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _flutterTts?.setVolume(_volume);
    await _saveVoiceSettings();
  }

  static Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _flutterTts?.setPitch(_pitch);
    await _saveVoiceSettings();
  }

  /// 🎯 GET CURRENT VOICE SETTINGS
  static double get speechRate => _speechRate;
  static double get volume => _volume;
  static double get pitch => _pitch;
  static bool get isInitialized => _isInitialized;
  static bool get isSpeaking => _isSpeaking;

  /// 🔧 CONFIGURE TTS
  static Future<void> _configureTts() async {
    if (_flutterTts == null) return;

    // Set language to Serbian
    await _flutterTts!.setLanguage(_currentLanguage);

    // Apply settings
    await _flutterTts!.setSpeechRate(_speechRate);
    await _flutterTts!.setVolume(_volume);
    await _flutterTts!.setPitch(_pitch);

    // Set callbacks
    _flutterTts!.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts!.setErrorHandler((message) {
      _isSpeaking = false;
    });
  }

  /// 📝 PREPROCESS TEXT FOR SERBIAN TTS
  static String _preprocessTextForSerbianTts(String text) {
    // Replace common abbreviations and symbols
    String processed = text
        .replaceAll('m', 'metara')
        .replaceAll('km', 'kilometara')
        .replaceAll('&', 'i')
        .replaceAll('@', 'at')
        .replaceAll('%', 'procenata')
        .replaceAll('°', 'stepeni');

    // Fix common mispronunciations
    processed = processed.replaceAll('GPS', 'Ges Pe Es').replaceAll('API', 'A Pe I').replaceAll('URL', 'U Er El');

    // Add pauses for better comprehension
    processed = processed.replaceAll('.', '. ').replaceAll(',', ', ').replaceAll(';', '; ');

    return processed.trim();
  }

  /// 🔊 SPEAK CURRENT TURN-BY-TURN INSTRUCTION
  static Future<void> _speakCurrentInstruction() async {
    if (_currentInstructionIndex >= _currentInstructions.length) return;

    final instruction = _currentInstructions[_currentInstructionIndex];

    // Create natural Serbian instruction
    String instructionText = _convertInstructionToSerbian(instruction);

    await speak(instructionText);
  }

  /// 🔄 CONVERT INSTRUCTION TO NATURAL SERBIAN
  static String _convertInstructionToSerbian(
    TurnByTurnInstruction instruction,
  ) {
    String direction = '';

    switch (instruction.type) {
      case InstructionType.turnLeft:
        direction = 'Skreni levo';
        break;
      case InstructionType.turnRight:
        direction = 'Skreni desno';
        break;
      case InstructionType.turnSharpLeft:
        direction = 'Oštro skreni levo';
        break;
      case InstructionType.turnSharpRight:
        direction = 'Oštro skreni desno';
        break;
      case InstructionType.turnSlightLeft:
        direction = 'Blago skreni levo';
        break;
      case InstructionType.turnSlightRight:
        direction = 'Blago skreni desno';
        break;
      case InstructionType.straight:
        direction = 'Nastavi pravo';
        break;
      case InstructionType.uturn:
        direction = 'Polukrug';
        break;
      case InstructionType.roundabout:
        direction = 'Uđi u kružnu raskrsnicu';
        break;
      case InstructionType.exitRoundabout:
        direction = 'Izađi iz kružne raskrsnice';
        break;
      case InstructionType.arrive:
        return 'Stigli ste na destinaciju.';
      case InstructionType.depart:
        direction = 'Kreni';
        break;
      default:
        direction = 'Nastavi pravo';
    }

    // Add distance information
    String distanceText = '';
    if (instruction.distance > 0) {
      if (instruction.distance < 100) {
        distanceText = ' za ${instruction.distance.toInt()} metara';
      } else if (instruction.distance < 1000) {
        final meters = (instruction.distance / 50).round() * 50;
        distanceText = ' za $meters metara';
      } else {
        final km = (instruction.distance / 1000).toStringAsFixed(1);
        distanceText = ' za $km kilometara';
      }
    }

    // Add street name if available
    String streetText = '';
    if (instruction.streetName != null && instruction.streetName!.isNotEmpty) {
      streetText = ' na ${instruction.streetName}';
    }

    return '$direction$distanceText$streetText.';
  }

  /// 🛰️ START GPS TRACKING FOR TURN-BY-TURN
  static Future<void> _startGpsTracking() async {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _handleGpsUpdate(position);
    });
  }

  /// 📍 HANDLE GPS UPDATE FOR NAVIGATION
  static void _handleGpsUpdate(Position position) async {
    if (_currentInstructions.isEmpty || _currentInstructionIndex >= _currentInstructions.length) {
      return;
    }

    final currentInstruction = _currentInstructions[_currentInstructionIndex];

    // Check if we're close to the next instruction point
    if (currentInstruction.coordinates.isNotEmpty) {
      final instructionCoord = currentInstruction.coordinates.first;
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        instructionCoord.latitude,
        instructionCoord.longitude,
      );

      // If we're within 50 meters of instruction point, move to next
      if (distance < 50) {
        _currentInstructionIndex++;

        // Speak next instruction if available
        if (_currentInstructionIndex < _currentInstructions.length) {
          await _speakCurrentInstruction();
        }
      }
    }
  }

  /// ⏳ WAIT FOR SPEECH COMPLETION
  static Future<void> _waitForSpeechCompletion() async {
    while (_isSpeaking) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  /// 💾 SAVE VOICE SETTINGS
  static Future<void> _saveVoiceSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('voice_speech_rate', _speechRate);
      await prefs.setDouble('voice_volume', _volume);
      await prefs.setDouble('voice_pitch', _pitch);
    } catch (e) {
      // Ignore save errors
    }
  }

  /// 📂 LOAD VOICE SETTINGS
  static Future<void> _loadVoiceSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _speechRate = prefs.getDouble('voice_speech_rate') ?? 0.8;
      _volume = prefs.getDouble('voice_volume') ?? 1.0;
      _pitch = prefs.getDouble('voice_pitch') ?? 1.0;
    } catch (e) {
      // Use defaults on error
    }
  }

  /// 🧹 CLEANUP
  static Future<void> dispose() async {
    await _positionSubscription?.cancel();
    await stopSpeaking();
    await _flutterTts?.stop();
    _isInitialized = false;
  }
}
