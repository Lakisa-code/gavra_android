# VS Zahtev Sistem

## Kratki opis
Sistem za rezervaciju VS termina (povratak iz Vršca).

---

## 📅 ZA TEKUĆI (DANAŠNJI) DAN

### Pravilo
Bez obzira na tip putnika (učenik/radnik):

1.  **Odmah se zahtev beleži kao `pending`**
2.  **Pokreće se Timer: 10 minuta**
3.  **Nakon isteka 10 minuta:**
    *   Vrši se provera **slobodnih mesta** za traženi termin.
    *   **Ako IMA mesta**: Zahtev se potvrđuje (`confirmed`).
    *   **Ako NEMA mesta**: Zahtev se odbija uz ponudu alternativa.

---

## 📅 ZA NAREDNE DANE

*(Definisati pravila...)*
