# 🇷🇸 Državni praznici Srbije (neradni dani)

## Fiksni praznici

| Praznik | Datum | Neradni dani |
|---------|-------|--------------|
| **Nova godina** | 1. i 2. januar | 2 dana |
| **Božić** (pravoslavni) | 7. januar | 1 dan ☦️ |
| **Sretenje** (Dan državnosti) | 15. i 16. februar | 2 dana |
| **Praznik rada** | 1. i 2. maj | 2 dana |
| **Dan pobede** | 9. maj | 1 dan |
| **Dan primirja** | 11. novembar | 1 dan |

## Pomični praznici (pravoslavni kalendar)

| Praznik | Opis |
|---------|------|
| **Veliki petak** | Petak pre Vaskrsa |
| **Vaskršnja subota** | Subota pre Vaskrsa |
| **Vaskrs** | Nedelja + ponedeljak (2 dana) |

### Datumi Vaskrsa po godinama:
- **2025**: 20. april (nedelja), 21. april (ponedeljak)
- **2026**: 12. april (nedelja), 13. april (ponedeljak)
- **2027**: 2. maj (nedelja), 3. maj (ponedeljak)
- **2028**: 16. april (nedelja), 17. april (ponedeljak)
- **2029**: 8. april (nedelja), 9. april (ponedeljak)
- **2030**: 28. april (nedelja), 29. april (ponedeljak)

## Napomene

1. **Ako praznik padne u nedelju** - sledeći radni dan (ponedeljak) je neradan
2. **Badnji dan (6. januar)** - nije državni praznik, ali mnogi ne rade
3. **Vidovdan (28. jun)** - državni praznik ali RADAN dan za većinu

## Verski praznici za druge konfesije (neradni samo za pripadnike)

| Praznik | Datum | Ko slavi |
|---------|-------|----------|
| Katolički Božić | 25. decembar | Katolici |
| Ramazanski bajram | pomični | Muslimani |
| Kurban bajram | pomični | Muslimani |
| Jom Kipur | pomični | Jevreji |

---

## 📱 Za aplikaciju GAVRA

Kada je praznik, koristiti **praznički red vožnje** (smanjeni broj polazaka):
- BC: 5:00, 6:00, 12:00, 13:00, 15:00
- VS: 6:00, 7:00, 13:00, 14:00, 15:30

### Automatska detekcija praznika (TODO)
```dart
// Primer koda za proveru da li je danas praznik
bool isDrzavniPraznik(DateTime date) {
  // Fiksni praznici
  final fiksniPraznici = [
    DateTime(date.year, 1, 1),   // Nova godina
    DateTime(date.year, 1, 2),   // Nova godina 2
    DateTime(date.year, 1, 7),   // Božić
    DateTime(date.year, 2, 15),  // Sretenje
    DateTime(date.year, 2, 16),  // Sretenje 2
    DateTime(date.year, 5, 1),   // Praznik rada
    DateTime(date.year, 5, 2),   // Praznik rada 2
    DateTime(date.year, 5, 9),   // Dan pobede
    DateTime(date.year, 11, 11), // Dan primirja
  ];
  
  // TODO: Dodati Vaskrs (pomični)
  
  return fiksniPraznici.any((p) => 
    p.day == date.day && p.month == date.month);
}
```
