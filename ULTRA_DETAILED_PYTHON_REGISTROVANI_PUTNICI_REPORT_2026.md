
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: REGISTROVANI_PUTNICI
## 📅 Datum: 2026-01-29 22:12:27

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `registrovani_putnici`
- **Ukupno redova**: 212
- **Ukupno kolona**: 34
- **Veličina podataka**: 0.27 MB


### 📅 Vremenski raspon (status)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (datum_pocetka_meseca)
- **Početak**: 2025-11-01 00:00:00
- **Kraj**: 2026-02-01 00:00:00
- **Trajanje dana**: 92


### 📅 Vremenski raspon (datum_kraja_meseca)
- **Početak**: 2025-11-30 00:00:00
- **Kraj**: 2026-02-28 00:00:00
- **Trajanje dana**: 90


### 📅 Vremenski raspon (created_at)
- **Početak**: 2025-11-20 04:50:13.488505+00:00
- **Kraj**: 2026-01-29 17:07:19.243593+00:00
- **Trajanje dana**: 70


### 📅 Vremenski raspon (updated_at)
- **Početak**: 2025-11-25 22:04:31.538192+00:00
- **Kraj**: 2026-01-29 21:00:00.044830+00:00
- **Trajanje dana**: 64


### 📅 Vremenski raspon (is_duplicate)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 212 | N/A | N/A | N/A |
| `putnik_ime` | str | 0.0% | 211 | N/A | N/A | N/A |
| `tip` | str | 0.0% | 4 | N/A | N/A | N/A |
| `tip_skole` | str | 73.6% | 5 | N/A | N/A | N/A |
| `broj_telefona` | str | 4.7% | 200 | N/A | N/A | N/A |
| `broj_telefona_oca` | str | 93.9% | 12 | N/A | N/A | N/A |
| `broj_telefona_majke` | str | 93.4% | 13 | N/A | N/A | N/A |
| `polasci_po_danu` | object | 0.0% | 133 | N/A | N/A | N/A |
| `aktivan` | bool | 0.0% | 2 | 1.00 | 0.00 | 1.00 |
| `status` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `datum_pocetka_meseca` | datetime64[us] | 0.0% | 4 | N/A | N/A | N/A |
| `datum_kraja_meseca` | datetime64[us] | 0.0% | 4 | N/A | N/A | N/A |
| `vozac_id` | str | 4.2% | 4 | N/A | N/A | N/A |
| `obrisan` | bool | 0.0% | 2 | 0.08 | 0.00 | 1.00 |
| `created_at` | datetime64[us, UTC] | 0.0% | 212 | N/A | N/A | N/A |
| `updated_at` | datetime64[us, UTC] | 0.0% | 149 | N/A | N/A | N/A |
| `adresa_bela_crkva_id` | str | 22.6% | 65 | N/A | N/A | N/A |
| `adresa_vrsac_id` | str | 26.9% | 24 | N/A | N/A | N/A |
| `pin` | str | 81.1% | 38 | N/A | N/A | N/A |
| `cena_po_danu` | float64 | 54.7% | 8 | 634.39 | 1.00 | 1200.00 |
| `broj_telefona_2` | str | 98.1% | 4 | N/A | N/A | N/A |
| `email` | str | 77.8% | 45 | N/A | N/A | N/A |
| `uklonjeni_termini` | object | 0.0% | 64 | N/A | N/A | N/A |
| `firma_naziv` | str | 99.5% | 1 | N/A | N/A | N/A |
| `firma_pib` | str | 99.5% | 1 | N/A | N/A | N/A |
| `firma_mb` | str | 99.5% | 1 | N/A | N/A | N/A |
| `firma_ziro` | str | 99.5% | 1 | N/A | N/A | N/A |
| `firma_adresa` | object | 100.0% | 0 | N/A | N/A | N/A |
| `treba_racun` | bool | 0.0% | 2 | 0.02 | 0.00 | 1.00 |
| `tip_prikazivanja` | str | 0.0% | 2 | N/A | N/A | N/A |
| `broj_mesta` | int64 | 0.0% | 1 | 1.00 | 1.00 | 1.00 |
| `merged_into_id` | object | 100.0% | 0 | N/A | N/A | N/A |
| `is_duplicate` | datetime64[ns] | 100.0% | 0 | N/A | N/A | N/A |
| `radni_dani` | str | 1.4% | 19 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (4)

### Null Analysis
```json
{
  "columns": [
    "id",
    "putnik_ime",
    "tip",
    "tip_skole",
    "broj_telefona",
    "broj_telefona_oca",
    "broj_telefona_majke",
    "polasci_po_danu",
    "aktivan",
    "status",
    "datum_pocetka_meseca",
    "datum_kraja_meseca",
    "vozac_id",
    "obrisan",
    "created_at",
    "updated_at",
    "adresa_bela_crkva_id",
    "adresa_vrsac_id",
    "pin",
    "cena_po_danu",
    "broj_telefona_2",
    "email",
    "uklonjeni_termini",
    "firma_naziv",
    "firma_pib",
    "firma_mb",
    "firma_ziro",
    "firma_adresa",
    "treba_racun",
    "tip_prikazivanja",
    "broj_mesta",
    "merged_into_id",
    "is_duplicate",
    "radni_dani"
  ],
  "null_percentages": [
    0.0,
    0.0,
    0.0,
    73.58490566037736,
    4.716981132075472,
    93.86792452830188,
    93.39622641509435,
    0.0,
    0.0,
    100.0,
    0.0,
    0.0,
    4.245283018867925,
    0.0,
    0.0,
    0.0,
    22.641509433962266,
    26.88679245283019,
    81.13207547169812,
    54.71698113207547,
    98.11320754716981,
    77.83018867924528,
    0.0,
    99.52830188679245,
    99.52830188679245,
    99.52830188679245,
    99.52830188679245,
    100.0,
    0.0,
    0.0,
    0.0,
    100.0,
    100.0,
    1.4150943396226416
  ]
}
```

### Dtype Distribution
```json
{
  "dtypes": [
    "str",
    "object",
    "bool",
    "datetime64[s]",
    "datetime64[us]",
    "datetime64[us, UTC]",
    "float64",
    "int64",
    "datetime64[ns]"
  ],
  "counts": [
    19,
    4,
    3,
    1,
    2,
    2,
    1,
    1,
    1
  ]
}
```

### Passenger Types
```json
{
  "types": [
    "dnevni",
    "ucenik",
    "radnik",
    "posiljka"
  ],
  "counts": [
    101,
    62,
    45,
    4
  ]
}
```

### Price Distribution
```json
{
  "ranges": [
    "0-100",
    "100-200",
    "200-300",
    "300-500",
    "500-1000",
    "1000+"
  ],
  "counts": [
    1,
    0,
    1,
    3,
    89,
    2
  ]
}
```



## 💡 PREPORUKE (15)

1. Kolona tip_skole ima 73.6% NULL vrednosti - razmotriti optimizaciju
2. Kolona broj_telefona_oca ima 93.9% NULL vrednosti - razmotriti optimizaciju
3. Kolona broj_telefona_majke ima 93.4% NULL vrednosti - razmotriti optimizaciju
4. Kolona status ima 100.0% NULL vrednosti - razmotriti optimizaciju
5. Kolona pin ima 81.1% NULL vrednosti - razmotriti optimizaciju
6. Kolona cena_po_danu ima 54.7% NULL vrednosti - razmotriti optimizaciju
7. Kolona broj_telefona_2 ima 98.1% NULL vrednosti - razmotriti optimizaciju
8. Kolona email ima 77.8% NULL vrednosti - razmotriti optimizaciju
9. Kolona firma_naziv ima 99.5% NULL vrednosti - razmotriti optimizaciju
10. Kolona firma_pib ima 99.5% NULL vrednosti - razmotriti optimizaciju
11. Kolona firma_mb ima 99.5% NULL vrednosti - razmotriti optimizaciju
12. Kolona firma_ziro ima 99.5% NULL vrednosti - razmotriti optimizaciju
13. Kolona firma_adresa ima 100.0% NULL vrednosti - razmotriti optimizaciju
14. Kolona merged_into_id ima 100.0% NULL vrednosti - razmotriti optimizaciju
15. Kolona is_duplicate ima 100.0% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 212,
  "total_columns": 34,
  "column_analysis": {
    "id": {
      "total_values": 212,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 212,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "putnik_ime": {
      "total_values": 212,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 211,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "tip": {
      "total_values": 212,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "tip_skole": {
      "total_values": 212,
      "null_values": 156,
      "null_percentage": 73.58490566037736,
      "unique_values": 5,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "broj_telefona": {
      "total_values": 212,
      "null_values": 10,
      "null_percentage": 4.716981132075472,
      "unique_values": 200,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "broj_telefona_oca": {
      "total_values": 212,
      "null_values": 199,
      "null_percentage": 93.86792452830188,
      "unique_values": 12,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "broj_telefona_majke": {
      "total_values": 212,
      "null_values": 198,
      "null_percentage": 93.39622641509435,
      "unique_values": 13,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "polasci_po_danu": {
      "total_values": 212,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 133,
      "data_types": [
        "object"
      ],
      "dtype": "object"
    },
    "aktivan": {
      "total_values": 212,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "bool"
      ],
      "dtype": "bool",
      "mean": 0.9952830188679245,
      "median": 1.0,
      "std": 0.0686802819743445,
      "min": 0.0,
      "max": 1.0
    },
    "status": {
      "total_values": 212,
      "null_values": 212,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "datum_pocetka_meseca": {
      "total_values": 212,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 4,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "datum_kraja_meseca": {
      "total_values": 212,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 4,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "vozac_id": {
      "total_values": 212,
      "null_values": 9,
      "null_percentage": 4.245283018867925,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "obrisan": {
      "total_values": 212,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "bool"
      ],
      "dtype": "bool",
      "mean": 0.08490566037735849,
      "median": 0.0,
      "std": 0.2794010020880532,
      "min": 0.0,
      "max": 1.0
    },
    "created_at": {
      "total_values": 212,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 212,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "updated_at": {
      "total_values": 212,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 149,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "adresa_bela_crkva_id": {
      "total_values": 212,
      "null_values": 48,
      "null_percentage": 22.641509433962266,
      "unique_values": 65,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "adresa_vrsac_id": {
      "total_values": 212,
      "null_values": 57,
      "null_percentage": 26.88679245283019,
      "unique_values": 24,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "pin": {
      "total_values": 212,
      "null_values": 172,
      "null_percentage": 81.13207547169812,
      "unique_values": 38,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "cena_po_danu": {
      "total_values": 212,
      "null_values": 116,
      "null_percentage": 54.71698113207547,
      "unique_values": 8,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 634.3854166666666,
      "median": 600.0,
      "std": 125.45893601969124,
      "min": 1.0,
      "max": 1200.0
    },
    "broj_telefona_2": {
      "total_values": 212,
      "null_values": 208,
      "null_percentage": 98.11320754716981,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "email": {
      "total_values": 212,
      "null_values": 165,
      "null_percentage": 77.83018867924528,
      "unique_values": 45,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "uklonjeni_termini": {
      "total_values": 212,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 64,
      "data_types": [
        "object"
      ],
      "dtype": "object"
    },
    "firma_naziv": {
      "total_values": 212,
      "null_values": 211,
      "null_percentage": 99.52830188679245,
      "unique_values": 1,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "firma_pib": {
      "total_values": 212,
      "null_values": 211,
      "null_percentage": 99.52830188679245,
      "unique_values": 1,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "firma_mb": {
      "total_values": 212,
      "null_values": 211,
      "null_percentage": 99.52830188679245,
      "unique_values": 1,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "firma_ziro": {
      "total_values": 212,
      "null_values": 211,
      "null_percentage": 99.52830188679245,
      "unique_values": 1,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "firma_adresa": {
      "total_values": 212,
      "null_values": 212,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "object"
    },
    "treba_racun": {
      "total_values": 212,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "bool"
      ],
      "dtype": "bool",
      "mean": 0.02358490566037736,
      "median": 0.0,
      "std": 0.1521111384615436,
      "min": 0.0,
      "max": 1.0
    },
    "tip_prikazivanja": {
      "total_values": 212,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "broj_mesta": {
      "total_values": 212,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 1.0,
      "median": 1.0,
      "std": 0.0,
      "min": 1.0,
      "max": 1.0
    },
    "merged_into_id": {
      "total_values": 212,
      "null_values": 212,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "object"
    },
    "is_duplicate": {
      "total_values": 212,
      "null_values": 212,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[ns]"
    },
    "radni_dani": {
      "total_values": 212,
      "null_values": 3,
      "null_percentage": 1.4150943396226416,
      "unique_values": 19,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    }
  },
  "data_size_mb": 0.2709808349609375,
  "status_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "datum_pocetka_meseca_range": {
    "min": "2025-11-01 00:00:00",
    "max": "2026-02-01 00:00:00",
    "span_days": 92
  },
  "datum_kraja_meseca_range": {
    "min": "2025-11-30 00:00:00",
    "max": "2026-02-28 00:00:00",
    "span_days": 90
  },
  "created_at_range": {
    "min": "2025-11-20 04:50:13.488505+00:00",
    "max": "2026-01-29 17:07:19.243593+00:00",
    "span_days": 70
  },
  "updated_at_range": {
    "min": "2025-11-25 22:04:31.538192+00:00",
    "max": "2026-01-29 21:00:00.044830+00:00",
    "span_days": 64
  },
  "is_duplicate_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  }
}
```

---

## ✅ ZAKLJUČAK

**Status**: ✅ ISPRAVNO

**Vizuelizacije**: ✅ GENERISANE

**Preporučeno**: ✅ SPREMNO ZA PRODUKCIJU

---
*Generisano Ultra Detailed Python Analyzer v2.0*
