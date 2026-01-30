
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: DAILY_REPORTS
## 📅 Datum: 2026-01-29 22:10:11
## 🌐 LIVE MODE - STVARNI PODACI IZ SUPABASE

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `daily_reports`
- **Ukupno redova**: 95
- **Ukupno kolona**: 16
- **Veličina podataka**: 0.04 MB


### 📅 Vremenski raspon (datum)
- **Početak**: 2025-11-26 00:00:00
- **Kraj**: 2026-01-29 00:00:00
- **Trajanje dana**: 64


### 📅 Vremenski raspon (automatski_generisan)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (created_at)
- **Početak**: 2025-11-26 03:54:10.211195+00:00
- **Kraj**: 2026-01-29 22:07:51.162870+00:00
- **Trajanje dana**: 64


### 📅 Vremenski raspon (updated_at)
- **Početak**: 2026-01-29 20:57:15.880967+00:00
- **Kraj**: 2026-01-29 20:57:15.880967+00:00
- **Trajanje dana**: 0


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 95 | N/A | N/A | N/A |
| `vozac` | str | 0.0% | 4 | N/A | N/A | N/A |
| `datum` | datetime64[us] | 0.0% | 35 | N/A | N/A | N/A |
| `ukupan_pazar` | float64 | 0.0% | 28 | 2930.56 | 0.00 | 33700.00 |
| `sitan_novac` | float64 | 0.0% | 7 | 92.96 | 0.00 | 500.00 |
| `checkin_vreme` | str | 0.0% | 95 | N/A | N/A | N/A |
| `otkazani_putnici` | int64 | 0.0% | 9 | 1.22 | 0.00 | 9.00 |
| `naplaceni_putnici` | int64 | 0.0% | 10 | 1.16 | 0.00 | 16.00 |
| `pokupljeni_putnici` | int64 | 0.0% | 28 | 15.69 | 0.00 | 52.00 |
| `dugovi_putnici` | int64 | 0.0% | 8 | 0.68 | 0.00 | 14.00 |
| `mesecne_karte` | int64 | 0.0% | 8 | 0.87 | 0.00 | 12.00 |
| `kilometraza` | float64 | 0.0% | 1 | 0.00 | 0.00 | 0.00 |
| `automatski_generisan` | datetime64[ns] | 100.0% | 0 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 59 | N/A | N/A | N/A |
| `vozac_id` | str | 0.0% | 4 | N/A | N/A | N/A |
| `updated_at` | datetime64[us, UTC] | 0.0% | 1 | N/A | N/A | N/A |


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
    "checkin_vreme",
    "otkazani_putnici",
    "naplaceni_putnici",
    "pokupljeni_putnici",
    "dugovi_putnici",
    "mesecne_karte",
    "kilometraza",
    "automatski_generisan",
    "created_at",
    "vozac_id",
    "updated_at"
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
    100.0,
    0.0,
    0.0,
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
    "int64",
    "datetime64[ns]",
    "datetime64[us, UTC]"
  ],
  "counts": [
    4,
    1,
    3,
    5,
    1,
    2
  ]
}
```

### Daily Revenue Trend
```json
{
  "dates": [
    "2025-11-26",
    "2025-11-27",
    "2025-11-28",
    "2025-11-29",
    "2025-12-01",
    "2025-12-20",
    "2025-12-21",
    "2025-12-22",
    "2025-12-23",
    "2025-12-24",
    "2025-12-25",
    "2026-01-02",
    "2026-01-07",
    "2026-01-08",
    "2026-01-09",
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
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    40900.0,
    5500.0,
    21100.0,
    0.0,
    0.0,
    30703.0,
    2500.0,
    37300.0,
    50300.0,
    15600.0,
    0.0,
    0.0,
    18400.0,
    4500.0,
    28600.0,
    23000.0
  ]
}
```



## 💡 PREPORUKE (1)

1. Kolona automatski_generisan ima 100.0% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 95,
  "total_columns": 16,
  "column_analysis": {
    "id": {
      "total_values": 95,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 95,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "vozac": {
      "total_values": 95,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "datum": {
      "total_values": 95,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 35,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "ukupan_pazar": {
      "total_values": 95,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 28,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 2930.557894736842,
      "median": 0.0,
      "std": 6624.05729899251,
      "min": 0.0,
      "max": 33700.0
    },
    "sitan_novac": {
      "total_values": 95,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 7,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 92.9578947368421,
      "median": 1.0,
      "std": 184.93989338629316,
      "min": 0.0,
      "max": 500.0
    },
    "checkin_vreme": {
      "total_values": 95,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 95,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "otkazani_putnici": {
      "total_values": 95,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 9,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 1.2210526315789474,
      "median": 0.0,
      "std": 2.104599559467569,
      "min": 0.0,
      "max": 9.0
    },
    "naplaceni_putnici": {
      "total_values": 95,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 10,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 1.1578947368421053,
      "median": 0.0,
      "std": 2.5819166123360975,
      "min": 0.0,
      "max": 16.0
    },
    "pokupljeni_putnici": {
      "total_values": 95,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 28,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 15.694736842105263,
      "median": 0.0,
      "std": 20.03458376090116,
      "min": 0.0,
      "max": 52.0
    },
    "dugovi_putnici": {
      "total_values": 95,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 8,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 0.6842105263157895,
      "median": 0.0,
      "std": 2.027802279036776,
      "min": 0.0,
      "max": 14.0
    },
    "mesecne_karte": {
      "total_values": 95,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 8,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 0.8736842105263158,
      "median": 0.0,
      "std": 1.9906275353070215,
      "min": 0.0,
      "max": 12.0
    },
    "kilometraza": {
      "total_values": 95,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 0.0,
      "median": 0.0,
      "std": 0.0,
      "min": 0.0,
      "max": 0.0
    },
    "automatski_generisan": {
      "total_values": 95,
      "null_values": 95,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[ns]"
    },
    "created_at": {
      "total_values": 95,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 59,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "vozac_id": {
      "total_values": 95,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "updated_at": {
      "total_values": 95,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    }
  },
  "data_size_mb": 0.0364990234375,
  "datum_range": {
    "min": "2025-11-26 00:00:00",
    "max": "2026-01-29 00:00:00",
    "span_days": 64
  },
  "automatski_generisan_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "created_at_range": {
    "min": "2025-11-26 03:54:10.211195+00:00",
    "max": "2026-01-29 22:07:51.162870+00:00",
    "span_days": 64
  },
  "updated_at_range": {
    "min": "2026-01-29 20:57:15.880967+00:00",
    "max": "2026-01-29 20:57:15.880967+00:00",
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
*Generisano Ultra Detailed Python Analyzer v2.2 - LIVE MODE*
