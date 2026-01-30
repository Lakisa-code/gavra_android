
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: VOZILA_ISTORIJA
## 📅 Datum: 2026-01-29 22:12:28

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `vozila_istorija`
- **Ukupno redova**: 25
- **Ukupno kolona**: 9
- **Veličina podataka**: 0.01 MB


### 📅 Vremenski raspon (datum)
- **Početak**: 2025-01-08 00:00:00
- **Kraj**: 2026-01-29 00:00:00
- **Trajanje dana**: 386


### 📅 Vremenski raspon (created_at)
- **Početak**: 2026-01-13 07:00:33.174131+00:00
- **Kraj**: 2026-01-29 03:35:34.978237+00:00
- **Trajanje dana**: 15


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 25 | N/A | N/A | N/A |
| `vozilo_id` | str | 0.0% | 5 | N/A | N/A | N/A |
| `tip` | str | 0.0% | 5 | N/A | N/A | N/A |
| `datum` | datetime64[us] | 0.0% | 7 | N/A | N/A | N/A |
| `km` | float64 | 72.0% | 5 | 443966.43 | 271765.00 | 498000.00 |
| `opis` | str | 24.0% | 12 | N/A | N/A | N/A |
| `cena` | object | 100.0% | 0 | N/A | N/A | N/A |
| `pozicija` | str | 24.0% | 2 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 25 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "vozilo_id",
    "tip",
    "datum",
    "km",
    "opis",
    "cena",
    "pozicija",
    "created_at"
  ],
  "null_percentages": [
    0.0,
    0.0,
    0.0,
    0.0,
    72.0,
    24.0,
    100.0,
    24.0,
    0.0
  ]
}
```

### Dtype Distribution
```json
{
  "dtypes": [
    "str",
    "datetime64[us]",
    "float64",
    "object",
    "datetime64[us, UTC]"
  ],
  "counts": [
    5,
    1,
    1,
    1,
    1
  ]
}
```



## 💡 PREPORUKE (2)

1. Kolona km ima 72.0% NULL vrednosti - razmotriti optimizaciju
2. Kolona cena ima 100.0% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 25,
  "total_columns": 9,
  "column_analysis": {
    "id": {
      "total_values": 25,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 25,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "vozilo_id": {
      "total_values": 25,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 5,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "tip": {
      "total_values": 25,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 5,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "datum": {
      "total_values": 25,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 7,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "km": {
      "total_values": 25,
      "null_values": 18,
      "null_percentage": 72.0,
      "unique_values": 5,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 443966.4285714286,
      "median": 471000.0,
      "std": 76933.83232331781,
      "min": 271765.0,
      "max": 498000.0
    },
    "opis": {
      "total_values": 25,
      "null_values": 6,
      "null_percentage": 24.0,
      "unique_values": 12,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "cena": {
      "total_values": 25,
      "null_values": 25,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "object"
    },
    "pozicija": {
      "total_values": 25,
      "null_values": 6,
      "null_percentage": 24.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "created_at": {
      "total_values": 25,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 25,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    }
  },
  "data_size_mb": 0.009978294372558594,
  "datum_range": {
    "min": "2025-01-08 00:00:00",
    "max": "2026-01-29 00:00:00",
    "span_days": 386
  },
  "created_at_range": {
    "min": "2026-01-13 07:00:33.174131+00:00",
    "max": "2026-01-29 03:35:34.978237+00:00",
    "span_days": 15
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
