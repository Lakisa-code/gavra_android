
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: DAILY_REPORTS
## 📅 Datum: 2026-01-29 22:09:20
## 🔧 OFFLINE MODE (MOCK DATA)

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `daily_reports`
- **Ukupno redova**: 20
- **Ukupno kolona**: 15
- **Veličina podataka**: 0.01 MB
- **Režim**: Mock podaci (demonstracija)


### 📅 Vremenski raspon (datum)
- **Početak**: 2026-01-10 00:00:00
- **Kraj**: 2026-01-29 00:00:00
- **Trajanje dana**: 19


### 📅 Vremenski raspon (created_at)
- **Početak**: 2025-12-30 22:09:20.058017
- **Kraj**: 2026-01-29 22:09:20.058017
- **Trajanje dana**: 30


### 📅 Vremenski raspon (automatski_generisan)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 20 | N/A | N/A | N/A |
| `vozac` | str | 0.0% | 4 | N/A | N/A | N/A |
| `datum` | datetime64[s] | 0.0% | 20 | N/A | N/A | N/A |
| `ukupan_pazar` | float64 | 0.0% | 20 | 627.11 | 109.21 | 980.52 |
| `sitan_novac` | float64 | 0.0% | 20 | 23.47 | 0.99 | 48.45 |
| `kilometraza` | float64 | 0.0% | 20 | 128.49 | 52.39 | 199.06 |
| `pokupljeni_putnici` | int64 | 0.0% | 11 | 15.50 | 5.00 | 25.00 |
| `naplaceni_putnici` | int64 | 0.0% | 12 | 13.45 | 6.00 | 23.00 |
| `otkazani_putnici` | int64 | 0.0% | 3 | 1.65 | 0.00 | 3.00 |
| `mesecne_karte` | int64 | 0.0% | 6 | 3.00 | 0.00 | 5.00 |
| `dugovi_putnici` | int64 | 0.0% | 3 | 0.95 | 0.00 | 2.00 |
| `checkin_vreme` | datetime64[us] | 0.0% | 14 | N/A | N/A | N/A |
| `created_at` | datetime64[us] | 0.0% | 16 | N/A | N/A | N/A |
| `automatski_generisan` | datetime64[ns] | 100.0% | 0 | N/A | N/A | N/A |
| `vozac_id` | str | 0.0% | 4 | N/A | N/A | N/A |


## ❌ PRONAĐENI PROBLEMI (1)

1. 10 redova ima više naplaćenih nego pokupljenih putnika


## 📊 VIZUELIZACIJE (3)

### Null Analysis
```json
{
  "columns": [
    "id",
    "vozac",
    "datum",
    "ukupan_pazar",
    "sitan_novac",
    "kilometraza",
    "pokupljeni_putnici",
    "naplaceni_putnici",
    "otkazani_putnici",
    "mesecne_karte",
    "dugovi_putnici",
    "checkin_vreme",
    "created_at",
    "automatski_generisan",
    "vozac_id"
  ],
  "null_percentages": [
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    100.0,
    0.0
  ]
}
```

### Dtype Distribution
```json
{
  "dtypes": [
    "str",
    "datetime64[s]",
    "float64",
    "int64",
    "datetime64[us]",
    "datetime64[ns]"
  ],
  "counts": [
    3,
    1,
    3,
    5,
    2,
    1
  ]
}
```

### Daily Revenue Trend
```json
{
  "dates": [
    "2026-01-10",
    "2026-01-11",
    "2026-01-12",
    "2026-01-13",
    "2026-01-14",
    "2026-01-15",
    "2026-01-16",
    "2026-01-17",
    "2026-01-18",
    "2026-01-19",
    "2026-01-20",
    "2026-01-21",
    "2026-01-22",
    "2026-01-23",
    "2026-01-24",
    "2026-01-25",
    "2026-01-26",
    "2026-01-27",
    "2026-01-28",
    "2026-01-29"
  ],
  "revenue": [
    930.42,
    966.5,
    648.3,
    685.16,
    627.4,
    187.6,
    109.21,
    518.5,
    980.52,
    526.28,
    792.59,
    289.3,
    859.56,
    914.77,
    574.96,
    229.2,
    474.03,
    965.67,
    481.34,
    780.91
  ]
}
```



## 💡 PREPORUKE (2)

1. Kolona automatski_generisan ima 100.0% NULL vrednosti - razmotriti optimizaciju
2. Popraviti 1 identifikovanih problema


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 20,
  "total_columns": 15,
  "column_analysis": {
    "id": {
      "total_values": 20,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 20,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "vozac": {
      "total_values": 20,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "datum": {
      "total_values": 20,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 20,
      "data_types": [
        "datetime64[s]"
      ],
      "dtype": "datetime64[s]"
    },
    "ukupan_pazar": {
      "total_values": 20,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 20,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 627.111,
      "median": 637.8499999999999,
      "std": 275.44648139835954,
      "min": 109.21,
      "max": 980.52
    },
    "sitan_novac": {
      "total_values": 20,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 20,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 23.471000000000004,
      "median": 22.744999999999997,
      "std": 14.948065497089019,
      "min": 0.99,
      "max": 48.45
    },
    "kilometraza": {
      "total_values": 20,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 20,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 128.49249999999998,
      "median": 128.875,
      "std": 49.38244316982558,
      "min": 52.39,
      "max": 199.06
    },
    "pokupljeni_putnici": {
      "total_values": 20,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 11,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 15.5,
      "median": 13.5,
      "std": 6.3120603025603215,
      "min": 5.0,
      "max": 25.0
    },
    "naplaceni_putnici": {
      "total_values": 20,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 12,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 13.45,
      "median": 11.0,
      "std": 6.151379819537283,
      "min": 6.0,
      "max": 23.0
    },
    "otkazani_putnici": {
      "total_values": 20,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 3,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 1.65,
      "median": 2.0,
      "std": 1.3088765773505315,
      "min": 0.0,
      "max": 3.0
    },
    "mesecne_karte": {
      "total_values": 20,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 6,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 3.0,
      "median": 3.0,
      "std": 1.5894388284780525,
      "min": 0.0,
      "max": 5.0
    },
    "dugovi_putnici": {
      "total_values": 20,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 3,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 0.95,
      "median": 1.0,
      "std": 0.9445132413883326,
      "min": 0.0,
      "max": 2.0
    },
    "checkin_vreme": {
      "total_values": 20,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 14,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "created_at": {
      "total_values": 20,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 16,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "automatski_generisan": {
      "total_values": 20,
      "null_values": 20,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[ns]"
    },
    "vozac_id": {
      "total_values": 20,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    }
  },
  "data_size_mb": 0.005219459533691406,
  "datum_range": {
    "min": "2026-01-10 00:00:00",
    "max": "2026-01-29 00:00:00",
    "span_days": 19
  },
  "created_at_range": {
    "min": "2025-12-30 22:09:20.058017",
    "max": "2026-01-29 22:09:20.058017",
    "span_days": 30
  },
  "automatski_generisan_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  }
}
```

---

## ✅ ZAKLJUČAK

**Status**: ⚠️ ZAHTEVA POPRAVKE

**Vizuelizacije**: ✅ GENERISANE

**Preporučeno**: 🔧 POTREBNE POPRAVKE

---
*Generisano Ultra Detailed Python Analyzer v2.1*
