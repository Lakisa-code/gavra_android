// SVAKI JEBENI EKRAN DA IMA GRADIJENT KAO STO JE SAD TRENUTNI
// 📱 REFERENTNA SLIKA: Aplikacija sa plavim gradijentom, belim karticama putnika,
//    transparentnim dugmićima i glassmorphism bottom nav barom

import 'package:flutter/material.dart';

class TripleBlueFashionTema {
  static const LinearGradient gradijent = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0575E6),
      Color(0xFF1E3A78),
      Color(0xFF4F7CAC),
      Color(0xFFA8D8E8),
      Color(0xFF12D8FA),
    ],
    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
  );

  static Widget pozadina({required Widget child}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: gradijent),
      child: child,
    );
  }

  // BELE KARTICE PUTNIKA
  static BoxDecoration belaKartica = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(15),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // BEO TEKST SA GLOW EFEKTOM
  static const TextStyle beoTekstSaGlow = TextStyle(
    color: Colors.white,
    shadows: [
      Shadow(
        blurRadius: 8,
        color: Colors.black87,
      ),
      Shadow(
        offset: Offset(1, 1),
        blurRadius: 4,
        color: Colors.black54,
      ),
    ],
  );

  // TRANSPARENTNI GLASSMORPHISM DUGMICI
  static BoxDecoration glassmorphismDugme = BoxDecoration(
    color: Colors.white.withOpacity(0.06),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: Colors.white.withOpacity(0.13),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // TRANSPARENTNI BOTTOM NAV BAR
  static BoxDecoration bottomNavBar = BoxDecoration(
    color: Colors.transparent,
    border: Border.all(
      color: Colors.white.withOpacity(0.13),
      width: 1.5,
    ),
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    boxShadow: [
      BoxShadow(
        color: Colors.blue.withOpacity(0.1),
        blurRadius: 24,
        offset: const Offset(0, -8),
        spreadRadius: 2,
      ),
    ],
  );

  // POPUP DODAJ PUTNIKA - GLASSMORPHISM DIALOG
  static BoxDecoration popupDialog = BoxDecoration(
    color: Colors.white.withOpacity(0.06),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: Colors.white.withOpacity(0.13),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // 📊 STATISTIKA KOCKE (Pazar, Mesečne, Dugovi, Sitan novac)
  static BoxDecoration pazarKocka = BoxDecoration(
    color: Colors.green[50],
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.green[300]!),
  );

  static BoxDecoration mesecneKocka = BoxDecoration(
    color: Colors.purple[50],
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.purple[300]!),
  );

  static BoxDecoration dugoviKocka = BoxDecoration(
    color: Colors.red[50],
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.red[300]!),
  );

  static BoxDecoration sitanNovacKocka = BoxDecoration(
    color: Colors.orange[50],
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.orange[300]!),
  );

  // 🎯 IKONE I DUGMAD U APPBAR-U
  static BoxDecoration appBarButton = BoxDecoration(
    color: Colors.black87,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.4)),
  );

  static BoxDecoration djackiButton = BoxDecoration(
    color: const Color(0xFF1FA2FF),
    borderRadius: BorderRadius.circular(16),
  );

  static BoxDecoration heartbeatIndicator = BoxDecoration(
    borderRadius: BorderRadius.circular(16),
  );

  // 💡 INFORMACIJSKI KONTEJNERI
  static BoxDecoration infoContainer = BoxDecoration(
    color: Colors.orange.withOpacity(0.1),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.orange.withOpacity(0.3)),
  );

  static BoxDecoration warningContainer = BoxDecoration(
    color: Colors.orange.shade50,
    borderRadius: BorderRadius.circular(8),
  );

  // 🎨 GLASSMORPHISM DUGMAD I KONTEJNERI
  static BoxDecoration glassmorphismContainer = BoxDecoration(
    color: Colors.white.withOpacity(0.15),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: Colors.white.withOpacity(0.3),
    ),
  );

  // 📋 SWITCH/TOGGLE DUGME
  static BoxDecoration toggleOn = BoxDecoration(
    gradient: LinearGradient(
      colors: [Colors.green.withOpacity(0.8), Colors.green],
    ),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: Colors.green.withOpacity(0.6),
    ),
  );

  static BoxDecoration toggleOff = BoxDecoration(
    gradient: LinearGradient(
      colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.1)],
    ),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: Colors.white.withOpacity(0.4),
    ),
  );

  static BoxDecoration toggleSlider = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(11),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // 🔳 AKCIJSKI DUGMAD
  static BoxDecoration cancelButton = BoxDecoration(
    color: Colors.red.withOpacity(0.2),
    borderRadius: BorderRadius.circular(15),
    border: Border.all(
      color: Colors.red.withOpacity(0.4),
    ),
  );

  static BoxDecoration saveButton = BoxDecoration(
    color: Colors.green.withOpacity(0.3),
    borderRadius: BorderRadius.circular(15),
    border: Border.all(
      color: Colors.green.withOpacity(0.6),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // 👤 KONTAKT SEKCIJA
  static BoxDecoration contactSection = BoxDecoration(
    color: Colors.blue.withOpacity(0.1),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: Colors.blue.withOpacity(0.3),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.blue.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration parentContactsEdit = BoxDecoration(
    color: Colors.orange.withOpacity(0.1),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: Colors.orange.withOpacity(0.3),
    ),
  );

  static BoxDecoration familyIcon = BoxDecoration(
    color: Colors.orange.withOpacity(0.2),
    borderRadius: BorderRadius.circular(6),
  );

  // 🎮 KOMPAKTNI DUGMAD I AKCIJE
  static BoxDecoration compactActionButton({required Color color}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          color.withOpacity(0.15),
          color.withOpacity(0.08),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: color.withOpacity(0.3),
      ),
    );
  }

  // 🎯 ICON BUTTON WRAPPER
  static BoxDecoration iconWrapper({required Color color}) {
    return BoxDecoration(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(8),
    );
  }

  /* 
  🎯 ZAHTEVI ISPUNJENI (PREMA SLICI):
  ✅ kartica putnika bele vidis majume - belaKartica (Ana Cortan, Dusica kartice su bele)
  ✅ tekst je beo sa glow proveri majmune da li je takoi - beoTekstSaGlow (REZERVACIJE tekst je beo sa shadow)
  ✅ dugmici transparentni proveri majmune - glassmorphismDugme (Dodaj, Danas, Admin dugmići transparentni)
  ✅ BOTTOM NAV BAR JE GLASSMORPHISM SA TRANSPARENTNIM EFEKTOM - bottomNavBar (BC/VS vremena transparentni)
  ✅ POPUP DODAJ PUTNIKA - GLASSMORPHISM DIALOG - popupDialog (transparentni dialog sa border i shadow)
  ✅ STATISTIKA KOCKE - pazarKocka, mesecneKocka, dugoviKocka, sitanNovacKocka (zelena, ljubičasta, crvena, narandžasta)
  ✅ APPBAR DUGMAD - appBarButton, djackiButton, heartbeatIndicator (speedometer, health status, đački brojač)
  ✅ KONTAKT SEKCIJE - contactSection, parentContactsEdit, familyIcon (plava sekcija, narandžasta roditeljska)
  ✅ TOGGLE DUGMAD - toggleOn, toggleOff, toggleSlider (green/white switch sa slider-om)
  ✅ AKCIJSKI DUGMAD - cancelButton (crveno otkaži), saveButton (zeleno sačuvaj)
  ✅ INFORMACIJSKI KONTEJNERI - infoContainer, warningContainer (narandžasti info/warning)
  ✅ GLASSMORPHISM KONTEJNERI - glassmorphismContainer (transparentni sa borderima)
  ✅ KOMPAKTNI DUGMAD - compactActionButton() (dinamička boja), iconWrapper() (za ikone)
  
  📱 DANAS SCREEN ELEMENTI DODANI:
  🟢 Pazar kocka (zelena pozadina + green[300] border)
  🟣 Mesečne kocka (purple pozadina + purple[300] border)  
  🔴 Dugovi kocka (red pozadina + red[300] border)
  🟠 Sitan novac kocka (orange pozadina + orange[300] border)
  ⚡ AppBar dugmad (speedometer, đaci, health indicator)
  📋 Toggle switch komponente (ON/OFF stanja)
  🔳 Akcijski dugmad (Cancel/Save sa bojama)
  💬 Info kontejneri (warning/info notifikacije)
  👤 Kontakt sekcije (plava + orange roditeljska)
  🎨 Glassmorphism wrapper (transparentni kontejneri)
  
  📱 SLIKA POKAZUJE: Plavi gradijent pozadina + bele kartice + beo tekst + transparentni elementi + colored statistike
  */
}
