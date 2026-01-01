# HUAWEI AppGallery

## Osnovni podaci
- **App ID:** 116046535
- **Developer:** BOJAN GAVRILOVIC
- **Default jezik:** sr (srpski)
- **Zemlja objavljivanja:** RS (Srbija)
- **Privacy Policy:** https://bojanbc83.github.io/gavra_android/privacy-policy.html

## Status
- **Release State:** Reviewing (Na pregledu)
- **Poslednji update:** 2026-01-01 04:56:57

## Verzija na Huawei
- **Verzija:** 6.0.0
- **Version Code:** 1
- **Version ID:** 1825193948692350912

## Rating
- **Content Rate:** 3+

## Test nalog za review
- **Test Account:** Nije postavljen
- **Test Password:** Nije postavljen
- **Test Remark:** Nije postavljen

## Uredjaji
- **Device Type:** 4 (Phone)
- **App Adapters:** 4,15

## Napomena
- Nova verzija 6.0.6 (348) je poslata i trenutno je na REVIEWING statusu
- Ceka se odobrenje od Huawei tima

---

# iOS App Store

## Osnovni podaci
- **App ID:** 6757114361
- **Ime:** Gavra 013
- **Bundle ID:** com.gavra013.gavra013ios
- **SKU:** gavra013ios
- **Primary Locale:** en-US

## App Store Status
- **Verzija:** 1.0
- **Status:** WAITING_FOR_REVIEW (Ceka pregled)
- **Release Type:** AFTER_APPROVAL (automatski nakon odobrenja)
- **Kreiran:** 2025-12-27
- **Live verzije:** Nema (prva verzija)

## TestFlight Status
- **Poslednji build:** 11
- **Upload datum:** 2025-12-31 20:42:04
- **Processing State:** VALID - Ready for Testing
- **Expired:** Ne

## Napomena
- Verzija 1.0 ceka Apple review
- TestFlight build 11 (6.0.6) je spreman za testiranje
- Nakon odobrenja, automatski ce biti objavljen na App Store

---

# Google Play Store

## Osnovni podaci
- **Package Name:** com.gavra013.gavra_android
- **Ime:** Gavra 013

## Trackovi i verzije

### Production
- **Status:** PRAZNO
- **Verzija:** Nema

### Beta (Closed Testing)
- **Status:** PRAZNO
- **Verzija:** Nema

### Alpha (Zatvoreno testiranje)
- **Status:** LIVE
- **Verzija:** v6.0.6
- **Build:** 348
- **Status opisa:** Published - Live on Google Play
- **Opis:** Za odabrane testere (email lista), bez Google review-a

### Internal Testing
- **Status:** DRAFT + LIVE
- **Draft:** main (build 1, 320)
- **Live:** 1 (6.0.0) - build 1

### Custom Track "6.0.3"
- **Status:** LIVE
- **Verzija:** 324 (6.0.3)

## Workflow konfiguracija
- **Trenutni track za deploy:** alpha
- **Fajl:** .github/workflows/release-all-platforms.yml

## PROBLEM
- Verzija 6.0.5 (347) koju korisnik ima instaliranu NIJE pronadjena ni na jednom tracku
- Workflow salje na alpha track, ali korisnik mozda nije registrovan kao alpha tester
- Potrebno utvrditi na kom tracku je korisnik registrovan kao tester
