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
/// 🛡️ Koristi GETTER da izbegneš crash pri library load-u pre Supabase.initialize()
SupabaseClient get supabase => Supabase.instance.client;

/// 🛡️ Provera da li je Supabase spreman za rad (da ne bi pucao call stack)
bool get isSupabaseReady {
  try {
    Supabase.instance.client;
    return true;
  } catch (_) {
    return false;
  }
}

/// 🚌 NAV BAR TYPE - tip bottom navigation bara
/// 'auto' = automatski (zimski/letnji po datumu)
/// 'zimski' = forsiran zimski
/// 'letnji' = forsiran letnji
/// 'praznici' = praznični
final ValueNotifier<String> navBarTypeNotifier = ValueNotifier<String>('auto');

/// Helper za dobijanje trenutnog tipa nav bara
String get currentNavBarType => navBarTypeNotifier.value;

/// 🎄 PRAZNIČNI MOD - specijalni red vožnje (DEPRECATED - koristi navBarTypeNotifier)
/// Kada je true, koristi se BottomNavBarPraznici sa smanjenim brojem polazaka
/// BC: 5:00, 6:00, 12:00, 13:00, 15:00
/// VS: 6:00, 7:00, 13:00, 14:00, 15:30
final ValueNotifier<bool> praznicniModNotifier = ValueNotifier<bool>(false);

/// Helper za proveru prazničnog moda
bool get isPraznicniMod => praznicniModNotifier.value;

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

/// 🎫 DNEVNI ZAKAZIVANJE - admin kontrola da li dnevni putnici mogu da zakazuju
/// false = zakazivanje isključeno (default)
/// true = zakazivanje aktivno
final ValueNotifier<bool> dnevniZakazivanjeNotifier = ValueNotifier<bool>(false);

/// Helper za proveru da li je zakazivanje za dnevne aktivno
bool get isDnevniZakazivanjeAktivno => dnevniZakazivanjeNotifier.value;
