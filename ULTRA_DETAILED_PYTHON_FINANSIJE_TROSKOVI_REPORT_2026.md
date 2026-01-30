
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: FINANSIJE_TROSKOVI
## 📅 Datum: 2026-01-29 22:12:26

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `finansije_troskovi`
- **Ukupno redova**: 18
- **Ukupno kolona**: 11
- **Veličina podataka**: 0.00 MB


### 📅 Vremenski raspon (created_at)
- **Početak**: 2026-01-10 06:55:36.301611+00:00
- **Kraj**: 2026-01-29 05:48:09.915822+00:00
- **Trajanje dana**: 18


### 📅 Vremenski raspon (updated_at)
- **Početak**: 2026-01-15 12:05:33.521333+00:00
- **Kraj**: 2026-01-29 05:48:09.915822+00:00
- **Trajanje dana**: 13


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 18 | N/A | N/A | N/A |
| `naziv` | str | 0.0% | 11 | N/A | N/A | N/A |
| `tip` | str | 0.0% | 11 | N/A | N/A | N/A |
| `iznos` | float64 | 0.0% | 15 | 26772.22 | 0.00 | 146600.00 |
| `mesecno` | bool | 0.0% | 1 | 1.00 | 1.00 | 1.00 |
| `aktivan` | bool | 0.0% | 1 | 1.00 | 1.00 | 1.00 |
| `vozac_id` | object | 100.0% | 0 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 18 | N/A | N/A | N/A |
| `updated_at` | datetime64[us, UTC] | 0.0% | 18 | N/A | N/A | N/A |
| `mesec` | int64 | 0.0% | 1 | 1.00 | 1.00 | 1.00 |
| `godina` | int64 | 0.0% | 1 | 2026.00 | 2026.00 | 2026.00 |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "naziv",
    "tip",
    "iznos",
    "mesecno",
    "aktivan",
    "vozac_id",
    "created_at",
    "updated_at",
    "mesec",
    "godina"
  ],
  "null_percentages": [
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    100.0,
    0.0,
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
    "float64",
    "bool",
    "object",
    "datetime64[us, UTC]",
    "int64"
  ],
  "counts": [
    3,
    1,
    2,
    1,
    2,
    2
  ]
}
```



## 💡 PREPORUKE (1)

1. Kolona vozac_id ima 100.0% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 18,
  "total_columns": 11,
  "column_analysis": {
    "id": {
      "total_values": 18,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 18,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "naziv": {
      "total_values": 18,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 11,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "tip": {
      "total_values": 18,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 11,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "iznos": {
      "total_values": 18,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 15,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 26772.222222222223,
      "median": 15000.0,
      "std": 35149.44239463259,
      "min": 0.0,
      "max": 146600.0
    },
    "mesecno": {
      "total_values": 18,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "bool"
      ],
      "dtype": "bool",
      "mean": 1.0,
      "median": 1.0,
      "std": 0.0,
      "min": 1.0,
      "max": 1.0
    },
    "aktivan": {
      "total_values": 18,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "bool"
      ],
      "dtype": "bool",
      "mean": 1.0,
      "median": 1.0,
      "std": 0.0,
      "min": 1.0,
      "max": 1.0
    },
    "vozac_id": {
      "total_values": 18,
      "null_values": 18,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "object"
    },
    "created_at": {
      "total_values": 18,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 18,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "updated_at": {
      "total_values": 18,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 18,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "mesec": {
      "total_values": 18,
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
    "godina": {
      "total_values": 18,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 2026.0,
      "median": 2026.0,
      "std": 0.0,
      "min": 2026.0,
      "max": 2026.0
    }
  },
  "data_size_mb": 0.004750251770019531,
  "created_at_range": {
    "min": "2026-01-10 06:55:36.301611+00:00",
    "max": "2026-01-29 05:48:09.915822+00:00",
    "span_days": 18
  },
  "updated_at_range": {
    "min": "2026-01-15 12:05:33.521333+00:00",
    "max": "2026-01-29 05:48:09.915822+00:00",
    "span_days": 13
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
