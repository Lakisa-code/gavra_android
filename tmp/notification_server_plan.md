# Plan za sigurni notifications server i rotaciju kljuceva

Datum: 30.09.2025
Autor: automatski generisani plan

## Cilj
Napraviti siguran, testiran i proizvodno-prikladan server koji: 
- bezbedno šalje FCM poruke koristeći Firebase Admin service account
- (opciono) prosleđuje request-e OneSignal REST API-ju sa server-side ključem
- ne čuva tajne u repozitorijumu, već koristi environment varijable ili secret manager
- ima jednostavnu autentifikaciju za klijentske pozive

## Kratki pregled koraka
1. Hitna bezbednosna akcija: rotiraj/revokuj izložene ključeve odmah
2. Kreiraj (ili izaberi) service account za slanje FCM i preuzmi JSON ključ
3. Napravi minimalni Node.js server (`tools/notification_server`) koji koristi `firebase-admin`
4. Dodaj jednostavnu zaštitu endpoint-a (X-API-KEY header) i proveru
5. Konfiguriši env varijable: `SERVER_API_KEY`, `GOOGLE_APPLICATION_CREDENTIALS`, `ONE_SIGNAL_REST_KEY`, `ONE_SIGNAL_APP_ID`
6. Testiraj lokalno koristeći PowerShell i curl/postman
7. (Opcija) Deploy na Cloud Run / Heroku / DigitalOcean i koristi Secret Manager
8. Monitoring i rotacija ključeva: pravilo za rotaciju i procedura za incident

## Detaljan korak-po-korak plan
### 1) Hitna bezbednosna akcija (uradi odmah)
- Pretpostavi da su ključevi kompromitovani ako su javno objavljeni. Obriši ili rotiraj:
  - API keys u GCP Console (APIs & Services -> Credentials)
  - JSON ključeve service account-a (IAM & Admin -> Service accounts -> Keys)
  - OAuth client secrets (APIs & Services -> Credentials)
- Kreiraj nove ključeve samo kada si spreman da ih odmah upotrebiš i postavi ih u siguran vault.

### 2) Napravi ili izaberi service account za FCM
- Console: IAM & Admin -> Service Accounts -> Create service account (npr. `notifier-sa`)
- Dodaj minimum potrebnih uloga (preferiraj najmanje privilegija): `Firebase Admin SDK Service Agent` ili odgovarajuću rolu za slanje poruka
- Keys -> Add Key -> JSON -> Download
- Sačuvaj JSON izvan repozitorijuma (npr. `C:\secrets\gavra-notifier-sa.json`)

### 3) Server skeleton (lokalno i u repo)
- Struktura fajlova (predlog):
  - `tools/notification_server/package.json`
  - `tools/notification_server/index.js` (server kod)
  - `tools/notification_server/README.md`

- Sadržaj `index.js`: (koristi `firebase-admin` + `express` + `axios`)
  - Endpoint `POST /api/send-fcm` koji prima `{ token, title, body, data }` i poziva `admin.messaging().send(...)`
  - Endpoint `POST /api/onesignal/notify` koji prosleđuje OneSignal poziv (server-side ključ)
  - Middleware `requireApiKey` koji proverava `X-API-KEY`

### 4) Sigurnost endpoint-a
- Postavi `SERVER_API_KEY` kao slučajan string (npr. 32+ bytes) i ne stavljaj u git
- Za produkciju: umesto prostog header-a, koristi JWT ili OAuth2, i/ili Cloud IAM (Cloud Run IAM invoker)
- Ograniči CORS i rate-limit (npr. `express-rate-limit`)

### 5) Environment varijable (lokalno i produkcija)
- Lokalne varijable (PowerShell primer):
  - `$env:SERVER_API_KEY = "<tvoja-tajna>"`
  - `$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account.json"`
  - `$env:ONE_SIGNAL_REST_KEY = "<onesignal-rest-key>"`
  - `$env:ONE_SIGNAL_APP_ID = "<onesignal-app-id>"`
- U produkciji: koristi Cloud Run secrets / GitHub Actions secrets / Vault

### 6) Testiranje lokalno
- Instaliraj deps u `tools/notification_server`:
  - `npm init -y`
  - `npm i express body-parser firebase-admin axios`
- Start server:
  - `node index.js`
- Test sa curl/HTTP klijentom (PowerShell/curl primer):
```powershell
curl -X POST http://localhost:3000/api/send-fcm -H "Content-Type: application/json" -H "X-API-KEY: $env:SERVER_API_KEY" -d '{"token":"<device_token>","title":"Test","body":"Poruka"}'
```

### 7) Deploy preporuke
- Cloud Run + Secret Manager (preporučeno za GCP):
  - Upload service-account JSON to Secret Manager ili setuj `GOOGLE_APPLICATION_CREDENTIALS` u build step
  - Deploy Cloud Run service i dodeli IAM invoker pravila aplikaciji koja treba da poziva endpoint
- Alternativa: Heroku (config vars), DigitalOcean App Platform, AWS Lambda w/ API Gateway

### 8) Monitoring, logovi i rotacija
- Loguj svaki poziv servera (request id, timestamp, payload metadata)
- Postavi alert pri grešci > X% i rate-limit pretnjama
- Procedure za rotaciju: obriši kompromitovani ključ -> kreiraj novi -> update env var u deploy-u -> test -> obriši stari

## PowerShell korisni komandi (copy/paste)
```powershell
# primer setovanja env var u trenutnoj sesiji
$env:SERVER_API_KEY = "replace_with_strong_secret"
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secrets\gavra-notifier-sa.json"
$env:ONE_SIGNAL_REST_KEY = "replace_onesignal_key"
$env:ONE_SIGNAL_APP_ID = "replace_onesignal_app_id"

# pokretanje servera
cd tools\notification_server
node index.js

# test send (PowerShell)
curl -X POST http://localhost:3000/api/send-fcm -H "Content-Type: application/json" -H "X-API-KEY: $env:SERVER_API_KEY" -d '{"token":"<device_token>","title":"Test","body":"Hello"}'
```

## Hitni checklist (uradi sad)
- [ ] Obriši/rotiraj sve javno izložene API ključeve i JSON-ove
- [ ] Preuzmi novi service-account JSON i sačuvaj ga offline
- [ ] Postavi `SERVER_API_KEY` i testiraj lokalno
- [ ] Ne commituješ nikakve tajne u git

## Vremenski okvir (predlog)
- Hitna rotacija ključeva: 0-30 minuta
- Postavljanje lokalnog servera i test: 30–90 minuta
- Deploy na Cloud Run + Secret Manager: 1–2 sata
- Hardening (JWT + rate-limit + monitoring): 2–4 sata

## Sledeći koraci koje mogu da uradim za tebe (izaberi jednu)
1. "create server in repo" — napravim `tools/notification_server` sa kodom i README (bez ključeva)
2. "harden onesignal forwarder" — ubacim API key auth u postojeći forwarder i ažuriram klijentski kod
3. "step-by-step rotate" — napišem tačan red koraka za svaku stvarnu key ID iz tvoje GCP konzole
4. "run app" — pokrenem `flutter run` na tvom računaru (ako mi dozvoliš pristup terminalu)

### Kako povezati klijenta sa serverom (kratko)
- U `lib/main.dart` nakon Firebase inicijalizacije pozovi:
  ```dart
  // Postavi adresu tvog servera koji forwarduje OneSignal pozive
  RealtimeNotificationService.setOneSignalServerUrl('https://your-server.example.com/api/onesignal/notify');
  ```
- Alternativno: učitaj URL iz Remote Config ili sačuvaj u constants fajlu, ali NIKADA ne stavljaj OneSignal REST key u klijenta.

---

Fajl je sačuvan u `tmp/notification_server_plan.md` u repo folderu.
