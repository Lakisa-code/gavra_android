# Testiranje Višestruke Naplate za Mesečne Putnike

## Implementirane izmene:

### 1. MesecniPutnikService
- ✅ Uklonjena logika koja sprečava dupla plaćanja 
- ✅ Svako novo plaćanje se uvek dodaje kao novi red u `putovanja_istorija`
- ✅ Dodana `_izracunajUkupnuSumuZaMesec` metoda koja sabira sva plaćanja za mesec
- ✅ Ažurirana `mesecni_putnici` tabela sa ukupnom sumom svih plaćanja

### 2. PlacanjeService  
- ✅ Ažuriran `getStvarnaPlacanja` da sabira SVA plaćanja iz istorije
- ✅ Dodane nove metode:
  - `getUkupanIznosZaMesec` - ukupan iznos za određeni mesec
  - `getDetaljnaPlacanjaZaMesec` - lista svih plaćanja za mesec

### 3. UI Izmene (mesecni_putnici_screen.dart)
- ✅ Ažuriran dialog za plaćanje da pokazuje postojeća plaćanja
- ✅ Dodato objašnjenje da se novo plaćanje dodaje na postojeća
- ✅ Promenjen tekst dugmeta: "Sačuvaj" → "Dodaj plaćanje" kad postoje postojeća plaćanja
- ✅ Ažurirana success poruka da pokazuje da je plaćanje dodato

## Test Scenario:

1. **Prvi put plati mesečnu kartu:**
   - Otvori mesečnog putnika
   - Pritisni "Naplati" 
   - Unesi iznos (npr. 2000 RSD)
   - Dugme će biti "Sačuvaj" 
   - Nakon čuvanja, putnik će biti označen kao plaćen sa 2000 RSD

2. **Drugi put dodaj plaćanje za isti mesec:**
   - Otvori istog mesečnog putnika
   - Pritisni "Naplati" opet
   - Dialog će pokazati "Ukupno plaćeno: 2000 RSD"
   - Unesi dodatni iznos (npr. 1000 RSD)
   - Dugme će biti "Dodaj plaćanje"
   - Napomena će reći "Dodavanje novog plaćanja (biće dodato na postojeća)"
   - Nakon čuvanja, putnik će imati ukupno 3000 RSD

3. **Proveri da li se ukupna suma prikazuje:**
   - U listi putnika će se videti ukupno 3000 RSD
   - U detaljima putnika će se videti sva plaćanja pojedinačno

## Tehnički detalji:

- Svako plaćanje se čuva kao zaseban red u `putovanja_istorija` tabeli
- `PlacanjeService.getStvarnaPlacanja()` sabira sva plaćanja po putnik ID-u
- UI prikazuje ukupnu sumu iz všeh plaćanja
- Postojeća logika za statistike i izveštaje će automatski raditi sa novim podacima

## Napomene:

- Funkcionalnost je backward compatible - postojeća plaćanja će i dalje raditi
- Sistem sada podržava neograničen broj plaćanja po mesecu
- Sva plaćanja se čuvaju u istoriji sa detaljima o vozaču i datumu