# Analiza Privatne Distribucije Aplikacija

**Datum:** 11. decembar 2025.  
**Aplikacija:** Gavra Bus  
**Cilj:** Distribucija privatne aplikacije ograničenom broju korisnika

---

## 📋 SADRŽAJ

1. [Apple iOS App Store](#1-apple-ios-app-store)
2. [Google Play Store](#2-google-play-store)
3. [Huawei AppGallery](#3-huawei-appgallery)
4. [Uporedna Tabela](#4-uporedna-tabela)
5. [Preporuka za Gavra Bus](#5-preporuka-za-gavra-bus)

---

## 1. Apple iOS App Store

### 📌 Opcije za Privatnu Distribuciju

#### 1.1 TestFlight (PREPORUČENO za testiranje)
| Karakteristika | Detalji |
|----------------|---------|
| **Tip** | Beta testiranje |
| **Interni testeri** | Do 100 članova tima |
| **Eksterni testeri** | Do 10,000 korisnika |
| **Trajanje builda** | 90 dana |
| **Cena** | Besplatno (deo Apple Developer Program) |
| **App Review** | Potreban za eksterne testere |
| **Javna dostupnost** | NE - samo putem pozivnice |

**Prednosti:**
- ✅ Ne zahteva javnu objavu
- ✅ Korisnici primaju automatske update-ove
- ✅ Feedback mehanizam ugrađen
- ✅ Crash reporti automatski

**Nedostaci:**
- ❌ Buildovi ističu posle 90 dana
- ❌ Potreban stalni upload novih verzija
- ❌ Limit od 10,000 eksternih testera

**Idealno za:** Dugoročno testiranje, pilot projekti, ograničena korisnička baza

---

#### 1.2 Unlisted App Distribution (PREPORUČENO za produkciju)
| Karakteristika | Detalji |
|----------------|---------|
| **Tip** | Produkcijska distribucija |
| **Vidljivost** | Nije u pretrazi, kategorijama, ni listama |
| **Pristup** | Samo putem direktnog linka |
| **App Review** | DA - potreban |
| **Cena** | Besplatno (deo Apple Developer Program - $99/god) |
| **Trajanje** | Neograničeno |

**Kako funkcioniše:**
1. Aplikacija prolazi normalan App Review
2. Podnosi se zahtev za "Unlisted" status
3. Apple odobrava zahtev
4. Aplikacija dobija direktan link
5. Link se deli samo željenim korisnicima

**Prednosti:**
- ✅ Produkcijska stabilnost
- ✅ Nema vremenskog ograničenja
- ✅ Normalni update mehanizam
- ✅ Dostupna preko Apple Business/School Manager

**Nedostaci:**
- ❌ Potrebno odobrenje Apple-a
- ❌ Aplikacija mora proći Review Guidelines
- ❌ Ko ima link - može instalirati (nema stroge kontrole)

**Zahtev za Unlisted:** https://developer.apple.com/contact/request/unlisted-app/

---

#### 1.3 Apple Business Manager / Custom Apps
| Karakteristika | Detalji |
|----------------|---------|
| **Tip** | B2B distribucija |
| **Namena** | Specifične organizacije/kompanije |
| **Kontrola** | Stroga - samo odabrane organizacije |
| **MDM** | Podržava Mobile Device Management |

**Idealno za:** Korporativne aplikacije za partnere, klijente

---

#### 1.4 Apple Developer Enterprise Program
| Karakteristika | Detalji |
|----------------|---------|
| **Tip** | Interna distribucija |
| **Cena** | $299/godišnje |
| **Zahtev** | Kompanija sa 100+ zaposlenih |
| **Distribucija** | Samo zaposlenima |
| **App Store** | NE - potpuno van App Store-a |

**Prednosti:**
- ✅ Potpuna kontrola
- ✅ Nema App Review
- ✅ Interna distribucija

**Nedostaci:**
- ❌ Skupa opcija ($299/god)
- ❌ Zahteva 100+ zaposlenih
- ❌ Stroga verifikacija od Apple-a
- ❌ Ne sme se koristiti za eksterne korisnike!

**⚠️ NIJE za vašu situaciju** - Enterprise Program je samo za interne aplikacije velikih kompanija.

---

#### 1.5 Ad Hoc Distribution
| Karakteristika | Detalji |
|----------------|---------|
| **Tip** | Direktna instalacija na uređaje |
| **Limit** | 100 uređaja godišnje (po UDID) |
| **Zahtev** | Registracija svakog UDID-a |
| **Trajanje** | 1 godina |

**Nedostaci:**
- ❌ Ograničeno na 100 uređaja
- ❌ Potreban UDID svakog uređaja
- ❌ Nepraktično za veći broj korisnika

---

## 2. Google Play Store

### 📌 Opcije za Privatnu Distribuciju

#### 2.1 Internal Testing (PREPORUČENO za razvoj)
| Karakteristika | Detalji |
|----------------|---------|
| **Tip** | Interno testiranje |
| **Limit testera** | Do 100 |
| **Vidljivost** | NIJE u Play Store pretrazi |
| **App Review** | Minimalan |
| **Pristup** | Putem linka ili email liste |
| **Plaćene app** | Testeri instaliraju BESPLATNO |

**Prednosti:**
- ✅ Brz upload bez review-a
- ✅ Idealno za QA tim
- ✅ Nije javno vidljivo

**Nedostaci:**
- ❌ Samo 100 testera
- ❌ Nije za produkciju

---

#### 2.2 Closed Testing (PREPORUČENO za pilot)
| Karakteristika | Detalji |
|----------------|---------|
| **Tip** | Zatvoreno testiranje |
| **Limit testera** | Neograničen |
| **Vidljivost** | NIJE u pretrazi (osim ako tester traži po imenu) |
| **Metode pozivanja** | Email lista, Google Groups |
| **Plaćene app** | Testeri moraju platiti |

**Kako funkcioniše:**
1. Kreiraš Closed Testing track
2. Dodaš email adrese testera ili Google Group
3. Podeliš opt-in link testerima
4. Testeri prihvataju pozivnicu i instaliraju

**Prednosti:**
- ✅ Neograničen broj testera
- ✅ Može se koristiti dugoročno
- ✅ Feedback privatno (ne utiče na javni rating)
- ✅ Može se kreirati više closed tracks

**Nedostaci:**
- ❌ Testeri moraju imati Google nalog
- ❌ Za plaćene app - testeri plaćaju

---

#### 2.3 Open Testing
| Karakteristika | Detalji |
|----------------|---------|
| **Tip** | Javno beta testiranje |
| **Vidljivost** | VIDLJIVO u Play Store! |
| **Pristup** | Bilo ko se može prijaviti |

**⚠️ NIJE privatno** - aplikacija je vidljiva javno.

---

#### 2.4 Managed Google Play (za organizacije)
| Karakteristika | Detalji |
|----------------|---------|
| **Tip** | Enterprise/B2B distribucija |
| **Namena** | Kompanije sa Google Workspace |
| **Kontrola** | Stroga - samo zaposleni |
| **EMM/MDM** | Podržava enterprise upravljanje |

**Kako funkcioniše:**
1. Aplikacija se objavi kao "Private app"
2. Vidljiva samo zaposlenima organizacije
3. Distribuira se kroz EMM konzolu

**Idealno za:** Interne korporativne aplikacije

---

#### 2.5 Private Apps (Managed Google Play)
| Karakteristika | Detalji |
|----------------|---------|
| **Tip** | Privatna distribucija |
| **Zahtev** | Google Workspace / Cloud Identity |
| **Vidljivost** | Samo za odabranu organizaciju |
| **Javna pretraga** | NE |

**Prednosti:**
- ✅ Potpuno privatno
- ✅ Kontrola pristupa
- ✅ Ne prolazi pun review

**Nedostaci:**
- ❌ Zahteva organizacioni Google Workspace nalog
- ❌ Komplikovanije podešavanje

---

## 3. Huawei AppGallery

### 📌 Opcije za Privatnu Distribuciju

#### 3.1 Beta Test (Open Beta)
| Karakteristika | Detalji |
|----------------|---------|
| **Tip** | Beta testiranje |
| **Limit** | Do 2,000 testera |
| **Trajanje** | Do 90 dana |
| **Vidljivost** | Delimično vidljivo |
| **Pristup** | Putem linka |

**Prednosti:**
- ✅ Feedback od korisnika
- ✅ Crash reporti

**Nedostaci:**
- ❌ Vremenski ograničeno
- ❌ Ograničen broj testera

---

#### 3.2 Phased Release
| Karakteristika | Detalji |
|----------------|---------|
| **Tip** | Postepeno puštanje |
| **Kontrola** | Procenat korisnika (1%, 5%, 10%...) |
| **Namena** | Kontrolisano puštanje update-a |

**Napomena:** Ovo nije pravo rešenje za privatnu distribuciju - aplikacija je i dalje javna.

---

#### 3.3 Enterprise App Distribution
| Karakteristika | Detalji |
|----------------|---------|
| **Tip** | Korporativna distribucija |
| **Zahtev** | Enterprise Developer nalog |
| **Namena** | Interne aplikacije za zaposlene |
| **MDM** | Podržava Huawei MDM |

**Prednosti:**
- ✅ Potpuno privatno
- ✅ Distribucija samo zaposlenima

**Nedostaci:**
- ❌ Zahteva enterprise verifikaciju
- ❌ Samo za interne potrebe

---

#### 3.4 AppGallery Invitation Test
| Karakteristika | Detalji |
|----------------|---------|
| **Tip** | Zatvoreni test |
| **Pristup** | Putem invitation linka |
| **Limit** | Zavisi od tipa naloga |

**Slično Google Closed Testing-u**

---

## 4. Uporedna Tabela

| Opcija | Platforma | Privatnost | Limit korisnika | Trajanje | Cena | Kompleksnost |
|--------|-----------|------------|-----------------|----------|------|--------------|
| **TestFlight** | iOS | ✅ Visoka | 10,000 | 90 dana | Besplatno | ⭐⭐ |
| **Unlisted App** | iOS | ✅ Srednja | Neograničeno | Neograničeno | $99/god | ⭐⭐⭐ |
| **Enterprise Program** | iOS | ✅ Najviša | Neograničeno | Neograničeno | $299/god | ⭐⭐⭐⭐⭐ |
| **Ad Hoc** | iOS | ✅ Visoka | 100 uređaja | 1 godina | Besplatno | ⭐⭐⭐ |
| **Internal Testing** | Android | ✅ Visoka | 100 | Neograničeno | $25 jednokratno | ⭐ |
| **Closed Testing** | Android | ✅ Visoka | Neograničeno | Neograničeno | $25 jednokratno | ⭐⭐ |
| **Private Apps** | Android | ✅ Najviša | Neograničeno | Neograničeno | Besplatno* | ⭐⭐⭐⭐ |
| **Beta Test** | Huawei | ✅ Srednja | 2,000 | 90 dana | Besplatno | ⭐⭐ |
| **Enterprise** | Huawei | ✅ Najviša | Neograničeno | Neograničeno | Besplatno** | ⭐⭐⭐⭐ |

*Zahteva Google Workspace  
**Zahteva Enterprise verifikaciju

---

## 5. Preporuka za Gavra Bus

### 🎯 Za vašu situaciju (privatna app za ograničen broj korisnika):

#### iOS - PREPORUKA:

| Opcija | Kada koristiti |
|--------|----------------|
| **TestFlight** | Za testiranje i pilot (do 10,000 korisnika, ali buildovi ističu 90 dana) |
| **Unlisted App** | Za dugoročnu privatnu distribuciju - aplikacija prolazi review, ali nije vidljiva u pretrazi |

**Preporučeni tok:**
1. Koristi **TestFlight** za razvoj i početno testiranje
2. Kada aplikacija bude stabilna, zatraži **Unlisted App** status
3. Deli link samo vozačima/korisnicima koji trebaju aplikaciju

---

#### Android - PREPORUKA:

| Opcija | Kada koristiti |
|--------|----------------|
| **Internal Testing** | Za razvoj (do 100 testera) |
| **Closed Testing** | Za produkcijsku privatnu distribuciju - neograničen broj korisnika |

**Preporučeni tok:**
1. Koristi **Internal Testing** za QA
2. Kreiraj **Closed Testing** track za krajnje korisnike
3. Dodaj korisnike putem email liste ili Google Grupe
4. Deli opt-in link samo željenim korisnicima

---

#### Huawei - PREPORUKA:

| Opcija | Kada koristiti |
|--------|----------------|
| **Beta Test** | Za testiranje (do 2,000, 90 dana) |
| **Invitation Test** | Za kontrolisanu distribuciju |

**Napomena:** Huawei ima manje opcija za dugoročnu privatnu distribuciju u poređenju sa iOS i Android.

---

## 📚 Korisni Linkovi

### Apple iOS
- [TestFlight dokumentacija](https://developer.apple.com/testflight/)
- [Unlisted App Distribution](https://developer.apple.com/support/unlisted-app-distribution/)
- [Zahtev za Unlisted status](https://developer.apple.com/contact/request/unlisted-app/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple Business Manager](https://business.apple.com/)

### Google Play
- [Internal/Closed/Open Testing](https://support.google.com/googleplay/android-developer/answer/9845334)
- [Private Apps (Managed Google Play)](https://support.google.com/googleplay/android-developer/answer/9874937)
- [Google Play Console](https://play.google.com/console/)

### Huawei AppGallery
- [Beta Testing](https://developer.huawei.com/consumer/en/doc/AppGallery-connect-Guides/agc-betatest-introduction-0000001071477284)
- [Enterprise Distribution](https://developer.huawei.com/consumer/en/doc/AppGallery-connect-Guides/agc-enterprise-app-distribution-0000001146196173)
- [Huawei Developer Console](https://developer.huawei.com/consumer/en/console)

---

## ⚠️ VAŽNE NAPOMENE

### Pravna pitanja:
1. **App Store/Play Store Review:** Čak i za privatne app, moraju zadovoljiti sve review guidelines
2. **Privatnost podataka:** GDPR/CCPA se i dalje primenjuju
3. **Uslovi korišćenja:** Korisnici moraju prihvatiti Terms of Service

### Bezbednosne preporuke:
1. Implementiraj autentifikaciju unutar app (login sistem)
2. Link sam po sebi nije dovoljna zaštita - ko ima link, može instalirati
3. Za veću sigurnost, koristi Apple Business Manager ili Google Managed Play

### Ažuriranje korisnika:
- TestFlight/Closed Testing: Automatski update-ovi
- Unlisted App: Normalni App Store update mehanizam
- Ad Hoc: Manualni re-install potreban

---

**Zaključak:** Za Gavra Bus aplikaciju, najbolja kombinacija je:
- **iOS:** TestFlight → Unlisted App
- **Android:** Internal Testing → Closed Testing
- **Huawei:** Beta Test → Invitation Test

Ovo omogućava privatnu distribuciju bez potrebe za Enterprise programom i bez javne vidljivosti.
