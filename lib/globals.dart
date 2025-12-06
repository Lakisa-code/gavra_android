import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🌐 GLOBALNE VARIJABLE ZA GAVRA ANDROID
///
/// Ovaj fajl sadrži globalne varijable koje se koriste kroz celu aplikaciju.
/// Kreiran je da bi se smanjilo coupling između servisa i main.dart fajla.

/// Global navigator key za pristup navigation context-u iz servisa
/// Koristi se u:
/// - permission_service.dart - za prikaz dijaloga za dozvole
/// - notification_navigation_service.dart - za navigaciju iz notifikacija
/// - local_notification_service.dart - za pristup context-u u background-u
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Globalna instanca Supabase klijenta
/// Koristi se u svim servisima umesto kreiranja novih instanci
final SupabaseClient supabase = Supabase.instance.client;

/// 🧪 DEBUG: Simulirani dan u nedelji za testiranje
/// null = koristi pravi datum, 1-7 = ponedeljak-nedelja
/// POSTAVI NA null PRE PRODUKCIJE!
int? debugSimulatedWeekday; // 1=pon, 2=uto, 3=sre, 4=čet, 5=pet, 6=sub, 7=ned

/// 🧪 DEBUG: Simulirano vreme (sat) za testiranje
/// null = koristi pravo vreme
int? debugSimulatedHour;

/// Helper funkcija za dobijanje trenutnog dana (sa debug override)
int getCurrentWeekday() {
  return debugSimulatedWeekday ?? DateTime.now().weekday;
}

/// Helper funkcija za dobijanje trenutnog sata (sa debug override)
int getCurrentHour() {
  return debugSimulatedHour ?? DateTime.now().hour;
}
