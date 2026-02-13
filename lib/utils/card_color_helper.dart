import 'package:flutter/material.dart';

import '../models/putnik.dart';

/// Enum za stanja kartice putnika
enum CardState {
  odsustvo, // ✅ Godišnji/bolovanje
  otkazano, // ❌ Otkazano
  placeno, // 💰 Plaćeno/mesečno
  pokupljeno, // 🚶 Pokupljeno neplaćeno
  tudji, // 👥 Tuđi putnik (dodeljen drugom vozaču)
  nepokupljeno, // 🕒 Nepokupljeno (default)
}

/// 🎨 CARD COLOR HELPER - Centralizovana logika boja za kartice putnika
///
/// ## Prioritet boja (od najvišeg ka najnižem):
/// 1. 🟡 ŽUTO - Odsustvo (godišnji/bolovanje) - `CardState.odsustvo`
/// 2. 🔴 CRVENO - Otkazani putnici - `CardState.otkazano`
/// 3. 🟢 ZELENO - Pokupljeni plaćeni/mesečni - `CardState.placeno`
/// 4. 🔵 PLAVO - Pokupljeni neplaćeni - `CardState.pokupljeno`
/// 5. ⚪ SIVO - Tuđi putnik (dodeljen drugom vozaču) - `CardState.tudji`
/// 6. ⚪ BELO - Nepokupljeni (default) - `CardState.nepokupljeno`
///
/// ## Cheat Sheet Boja:
///
/// ### POZADINA KARTICE:
/// | Stanje | Boja | Hex |
/// |--------|------|-----|
/// | Odsustvo | Svetlo žuta | #FFF59D |
/// | Otkazano | Svetlo crvena | #FFE5E5 |
/// | Placeno | Zelena | #388E3C |
/// | Pokupljeno | Svetlo plava | #7FB3D3 |
/// | Nepokupljeno | Bela 70% | #FFFFFF (alpha 0.70) |
///
/// ### TEKST:
/// | Stanje | Boja | Hex |
/// |--------|------|-----|
/// | Odsustvo | Orange | #F57C00 |
/// | Otkazano | Crvena | #EF5350 |
/// | Placeno | Zelena (successPrimary) | iz teme |
/// | Pokupljeno | Tamno plava | #0D47A1 |
/// | Nepokupljeno | Crna | #000000 |
///
/// ### BORDER:
/// | Stanje | Boja | Alpha |
/// |--------|------|-------|
/// | Odsustvo | #FFC107 | 0.6 |
/// | Otkazano | Crvena | 0.25 |
/// | Placeno | #388E3C | 0.4 |
/// | Pokupljeno | #7FB3D3 | 0.4 |
/// | Nepokupljeno | Siva | 0.10 |
///
/// ### SHADOW:
/// | Stanje | Boja | Alpha |
/// |--------|------|-------|
/// | Odsustvo | #FFC107 | 0.2 |
/// | Otkazano | Crvena | 0.08 |
/// | Placeno | #388E3C | 0.15 |
/// | Pokupljeno | #7FB3D3 | 0.15 |
/// | Nepokupljeno | Crna | 0.07 |
///
/// ## Primer korišćenja:
/// ```dart
/// final decoration = CardColorHelper.getCardDecoration(putnik);
/// final textColor = CardColorHelper.getTextColorWithTheme(
///   putnik,
///   context,
///   successPrimary: Theme.of(context).colorScheme.successPrimary,
/// );
/// ```
class CardColorHelper {
  // ---------------------------------------------------------------------------
  // KONSTANTE BOJA
  // ---------------------------------------------------------------------------

  // 🟡 ODSUSTVO (godišnji/bolovanje) - NAJVEĆI PRIORITET
  static const Color odsustvoBackground = Color(0xFFFFF59D);
  static const Color odsustueBorder = Color(0xFFFFC107);
  static const Color odsustvoText = Color(0xFFF57C00); // Colors.orange[700]

  // 🔴 OTKAZANO - DRUGI PRIORITET
  static const Color otkazanoBackground = Color(0xFFEF9A9A); // Red[200] - tamnija crvena
  static const Color otkazanoBorder = Colors.red;
  static const Color otkazanoText = Color(0xFFEF5350); // Colors.red[400]

  // 🟢 PLACENO/MESECNO - TREĆI PRIORITET
  static const Color placenoBackground = Color(0xFF388E3C);
  static const Color placenoBorder = Color(0xFF388E3C);
  static const Color placenoText = Color(0xFF388E3C);

  // 🔵 POKUPLJENO NEPLACENO - ČETVRTI PRIORITET
  static const Color pokupljenoBackground = Color(0xFF7FB3D3);
  static const Color pokupljenoBorder = Color(0xFF7FB3D3);
  static const Color pokupljenoText = Color(0xFF0D47A1);

  // ⚪ TUĐI PUTNIK (dodeljen drugom vozaču)
  static const Color tudjiBackground = Color(0xFF757575); // Grey[600]
  static const Color tudjiBorder = Color(0xFFBDBDBD); // Grey[400]
  static const Color tudjiText = Color(0xFF757575); // Grey[600]

  // ? NEPOKUPLJENO - DEFAULT
  static const Color defaultBackground = Colors.white;
  static const Color defaultBorder = Colors.grey;
  static const Color defaultText = Colors.black;

  // ---------------------------------------------------------------------------
  // STANJE PUTNIKA
  // ---------------------------------------------------------------------------

  /// Enum za stanje kartice putnika (bez provere vozaca)
  static CardState getCardState(Putnik putnik) {
    // Provera po prioritetu
    if (putnik.jeOdsustvo) {
      return CardState.odsustvo;
    }
    if (putnik.jeOtkazan) {
      return CardState.otkazano;
    }
    if (putnik.jePokupljen) {
      // ?? PRAVI FIX: Proveravamo `placeno` polje umesto iznosa
      // `placeno` je true samo ako je putnik STVARNO platio
      final bool isPlaceno = putnik.placeno == true;
      // radnik/ucenik ? zelena, dnevni ? plava
      final bool isMesecniTip = putnik.isMesecniTip;
      if (isPlaceno || isMesecniTip) {
        return CardState.placeno;
      }
      return CardState.pokupljeno;
    }
    return CardState.nepokupljeno;
  }

  /// Enum za stanje kartice sa proverom vozaca (za sivu boju)
  /// [currentDriver] - ime trenutnog vozaca koji gleda listu
  static CardState getCardStateWithDriver(Putnik putnik, String currentDriver) {
    // Provera po prioritetu - odsustvo i otkazano imaju najveci prioritet
    if (putnik.jeOdsustvo) {
      return CardState.odsustvo;
    }
    if (putnik.jeOtkazan) {
      return CardState.otkazano;
    }
    if (putnik.jePokupljen) {
      // ?? PRAVI FIX: Proveravamo `placeno` polje umesto iznosa
      final bool isPlaceno = putnik.placeno == true;
      final bool isMesecniTip = putnik.isMesecniTip;
      if (isPlaceno || isMesecniTip) {
        return CardState.placeno;
      }
      return CardState.pokupljeno;
    }
    // ?? TU�I PUTNIK: ima vozaca, vozac nije trenutni
    if (putnik.dodeljenVozac != null && putnik.dodeljenVozac!.isNotEmpty && putnik.dodeljenVozac != currentDriver) {
      return CardState.tudji;
    }
    return CardState.nepokupljeno;
  }

  // ---------------------------------------------------------------------------
  // POZADINA KARTICE
  // ---------------------------------------------------------------------------

  /// Vraca boju pozadine kartice na osnovu stanja putnika
  static Color getBackgroundColor(Putnik putnik) {
    final state = getCardState(putnik);
    switch (state) {
      case CardState.odsustvo:
        return odsustvoBackground;
      case CardState.otkazano:
        return otkazanoBackground;
      case CardState.placeno:
        return placenoBackground;
      case CardState.pokupljeno:
        return pokupljenoBackground;
      case CardState.tudji:
        return tudjiBackground;
      case CardState.nepokupljeno:
        return defaultBackground.withOpacity(0.70);
    }
  }

  /// Vraca gradijent za karticu (ako je potrebno)
  static Gradient? getBackgroundGradient(Putnik putnik) {
    final state = getCardState(putnik);

    switch (state) {
      case CardState.odsustvo:
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.98),
            odsustvoBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardState.otkazano:
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.98),
            otkazanoBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardState.placeno:
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.98),
            placenoBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardState.pokupljeno:
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.98),
            pokupljenoBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardState.tudji:
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.98),
            tudjiBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardState.nepokupljeno:
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.98),
            Colors.white.withOpacity(0.98),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // BORDER KARTICE
  // ---------------------------------------------------------------------------

  /// Vraca boju border-a kartice
  static Color getBorderColor(Putnik putnik) {
    final state = getCardState(putnik);
    switch (state) {
      case CardState.odsustvo:
        return odsustueBorder.withOpacity(0.6);
      case CardState.otkazano:
        return otkazanoBorder.withOpacity(0.25);
      case CardState.placeno:
        return placenoBorder.withOpacity(0.4);
      case CardState.pokupljeno:
        return pokupljenoBorder.withOpacity(0.4);
      case CardState.tudji:
        return tudjiBorder.withOpacity(0.5);
      case CardState.nepokupljeno:
        return defaultBorder.withOpacity(0.10);
    }
  }

  // ---------------------------------------------------------------------------
  // SHADOW KARTICE
  // ---------------------------------------------------------------------------

  /// Vraca boju senke kartice
  static Color getShadowColor(Putnik putnik) {
    final state = getCardState(putnik);
    switch (state) {
      case CardState.odsustvo:
        return odsustueBorder.withOpacity(0.2);
      case CardState.otkazano:
        return otkazanoBorder.withOpacity(0.08);
      case CardState.placeno:
        return placenoBorder.withOpacity(0.15);
      case CardState.pokupljeno:
        return pokupljenoBorder.withOpacity(0.15);
      case CardState.tudji:
        return tudjiBorder.withOpacity(0.15);
      case CardState.nepokupljeno:
        return Colors.black.withOpacity(0.07);
    }
  }

  // ---------------------------------------------------------------------------
  // TEKST KARTICE
  // ---------------------------------------------------------------------------

  /// Vraca boju teksta za karticu
  static Color getTextColor(Putnik putnik, BuildContext context) {
    final state = getCardState(putnik);
    switch (state) {
      case CardState.odsustvo:
        return odsustvoText;
      case CardState.otkazano:
        return otkazanoText;
      case CardState.placeno:
        return Theme.of(context).colorScheme.primary; // successPrimary
      case CardState.pokupljeno:
        return pokupljenoText;
      case CardState.tudji:
        return tudjiText;
      case CardState.nepokupljeno:
        return defaultText;
    }
  }

  /// Vraca boju teksta sa fallback na successPrimary iz teme
  static Color getTextColorWithTheme(
    Putnik putnik,
    BuildContext context, {
    required Color successPrimary,
  }) {
    final state = getCardState(putnik);
    switch (state) {
      case CardState.odsustvo:
        return odsustvoText;
      case CardState.otkazano:
        return otkazanoText;
      case CardState.placeno:
        return successPrimary;
      case CardState.pokupljeno:
        return pokupljenoText;
      case CardState.tudji:
        return tudjiText;
      case CardState.nepokupljeno:
        return defaultText;
    }
  }

  // ---------------------------------------------------------------------------
  // SEKUNDARNE BOJE (adresa, telefon, ikone)
  // ---------------------------------------------------------------------------

  /// Vraca boju za adresu/sekundarni tekst (bleda verzija glavne boje)
  static Color getSecondaryTextColor(Putnik putnik) {
    final state = getCardState(putnik);
    switch (state) {
      case CardState.odsustvo:
        return const Color(0xFFFF9800).withOpacity(0.8); // Orange[500]
      case CardState.otkazano:
        return const Color(0xFFE57373).withOpacity(0.8); // Red[300]
      case CardState.placeno:
        return const Color(0xFF4CAF50).withOpacity(0.8); // Green[500]
      case CardState.pokupljeno:
        return pokupljenoText.withOpacity(0.8);
      case CardState.tudji:
        return const Color(0xFF9E9E9E).withOpacity(0.8); // Grey[500]
      case CardState.nepokupljeno:
        return const Color(0xFF757575).withOpacity(0.8); // Grey[600]
    }
  }

  /// Vraca boju za ikone akcija
  static Color getIconColor(Putnik putnik, BuildContext context) {
    final state = getCardState(putnik);
    switch (state) {
      case CardState.odsustvo:
        return Colors.orange;
      case CardState.otkazano:
        return Colors.red;
      case CardState.placeno:
        return Colors.green;
      case CardState.pokupljeno:
        return Theme.of(context).colorScheme.primary;
      case CardState.tudji:
        return Colors.grey;
      case CardState.nepokupljeno:
        return Theme.of(context).colorScheme.primary;
    }
  }

  // ---------------------------------------------------------------------------
  // KOMPLETNA DEKORACIJA
  // ---------------------------------------------------------------------------

  /// Vraca kompletnu BoxDecoration za karticu (bez provere vozaca)
  static BoxDecoration getCardDecoration(Putnik putnik) {
    final gradient = getBackgroundGradient(putnik);

    return BoxDecoration(
      gradient: gradient,
      color: gradient == null ? getBackgroundColor(putnik) : null,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: getBorderColor(putnik),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: getShadowColor(putnik),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Vraca kompletnu BoxDecoration za karticu SA proverom vozaca (za sivu boju)
  static BoxDecoration getCardDecorationWithDriver(Putnik putnik, String currentDriver) {
    final state = getCardStateWithDriver(putnik, currentDriver);
    final gradient = _getGradientForState(state);

    return BoxDecoration(
      gradient: gradient,
      color: gradient == null ? _getBackgroundForState(state) : null,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: _getBorderForState(state),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: _getShadowForState(state),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Vraca boju teksta SA proverom vozaca
  static Color getTextColorWithDriver(
    Putnik putnik,
    String currentDriver,
    BuildContext context, {
    required Color successPrimary,
  }) {
    final state = getCardStateWithDriver(putnik, currentDriver);
    return _getTextForState(state, successPrimary);
  }

  /// Vraca sekundarnu boju teksta SA proverom vozaca
  static Color getSecondaryTextColorWithDriver(Putnik putnik, String currentDriver) {
    final state = getCardStateWithDriver(putnik, currentDriver);
    return _getSecondaryTextForState(state);
  }

  // ---------------------------------------------------------------------------
  // PRIVATNE HELPER METODE ZA STATE
  // ---------------------------------------------------------------------------

  static Color _getBackgroundForState(CardState state) {
    switch (state) {
      case CardState.odsustvo:
        return odsustvoBackground;
      case CardState.otkazano:
        return otkazanoBackground;
      case CardState.placeno:
        return placenoBackground;
      case CardState.pokupljeno:
        return pokupljenoBackground;
      case CardState.tudji:
        return tudjiBackground;
      case CardState.nepokupljeno:
        return defaultBackground.withOpacity(0.70);
    }
  }

  static Gradient? _getGradientForState(CardState state) {
    switch (state) {
      case CardState.odsustvo:
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.98),
            odsustvoBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardState.otkazano:
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.98),
            otkazanoBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardState.placeno:
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.98),
            placenoBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardState.pokupljeno:
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.98),
            pokupljenoBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardState.tudji:
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.98),
            tudjiBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardState.nepokupljeno:
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.98),
            Colors.white.withOpacity(0.98),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  static Color _getBorderForState(CardState state) {
    switch (state) {
      case CardState.odsustvo:
        return odsustueBorder.withOpacity(0.6);
      case CardState.otkazano:
        return otkazanoBorder.withOpacity(0.25);
      case CardState.placeno:
        return placenoBorder.withOpacity(0.4);
      case CardState.pokupljeno:
        return pokupljenoBorder.withOpacity(0.4);
      case CardState.tudji:
        return tudjiBorder.withOpacity(0.5);
      case CardState.nepokupljeno:
        return defaultBorder.withOpacity(0.10);
    }
  }

  static Color _getShadowForState(CardState state) {
    switch (state) {
      case CardState.odsustvo:
        return odsustueBorder.withOpacity(0.2);
      case CardState.otkazano:
        return otkazanoBorder.withOpacity(0.08);
      case CardState.placeno:
        return placenoBorder.withOpacity(0.15);
      case CardState.pokupljeno:
        return pokupljenoBorder.withOpacity(0.15);
      case CardState.tudji:
        return tudjiBorder.withOpacity(0.15);
      case CardState.nepokupljeno:
        return Colors.black.withOpacity(0.07);
    }
  }

  static Color _getTextForState(CardState state, Color successPrimary) {
    switch (state) {
      case CardState.odsustvo:
        return odsustvoText;
      case CardState.otkazano:
        return otkazanoText;
      case CardState.placeno:
        return successPrimary;
      case CardState.pokupljeno:
        return pokupljenoText;
      case CardState.tudji:
        return tudjiText;
      case CardState.nepokupljeno:
        return defaultText;
    }
  }

  static Color _getSecondaryTextForState(CardState state) {
    switch (state) {
      case CardState.odsustvo:
        return const Color(0xFFFF9800).withOpacity(0.8);
      case CardState.otkazano:
        return const Color(0xFFE57373).withOpacity(0.8);
      case CardState.placeno:
        return const Color(0xFF4CAF50).withOpacity(0.8);
      case CardState.pokupljeno:
        return pokupljenoText.withOpacity(0.8);
      case CardState.tudji:
        return const Color(0xFF9E9E9E).withOpacity(0.8);
      case CardState.nepokupljeno:
        return const Color(0xFF757575).withOpacity(0.8);
    }
  }

  // ---------------------------------------------------------------------------
  // DEBUG HELPER
  // ---------------------------------------------------------------------------

  /// Debug string za stanje kartice
  static String getStateDebugString(Putnik putnik) {
    final state = getCardState(putnik);
    return 'CardState: ${state.name} | '
        'jeOdsustvo: ${putnik.jeOdsustvo} | '
        'jeOtkazan: ${putnik.jeOtkazan} | '
        'jePokupljen: ${putnik.jePokupljen} | '
        'mesecnaKarta: ${putnik.mesecnaKarta} | '
        'iznosPlacanja: ${putnik.iznosPlacanja}';
  }
}
