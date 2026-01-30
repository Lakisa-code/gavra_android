
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: VOZNJE_LOG_WITH_NAMES
## 📅 Datum: 2026-01-29 22:12:29

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `voznje_log_with_names`
- **Ukupno redova**: 1,000
- **Ukupno kolona**: 14
- **Veličina podataka**: 0.59 MB


### 📅 Vremenski raspon (datum)
- **Početak**: 2025-11-23 00:00:00
- **Kraj**: 2026-01-29 00:00:00
- **Trajanje dana**: 67


### 📅 Vremenski raspon (created_at)
- **Početak**: 2025-11-23 21:37:03.322124+00:00
- **Kraj**: 2026-01-29 21:00:00.044830+00:00
- **Trajanje dana**: 66


### 📅 Vremenski raspon (sati_pre_polaska)
- **Početak**: 1970-01-01 00:00:00
- **Kraj**: 1970-01-01 00:00:00.000000017
- **Trajanje dana**: 0


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 1,000 | N/A | N/A | N/A |
| `putnik_id` | str | 0.0% | 62 | N/A | N/A | N/A |
| `datum` | datetime64[us] | 0.0% | 20 | N/A | N/A | N/A |
| `tip` | str | 0.0% | 10 | N/A | N/A | N/A |
| `iznos` | float64 | 0.0% | 15 | 257.00 | 0.00 | 14000.00 |
| `vozac_id` | str | 29.8% | 4 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 933 | N/A | N/A | N/A |
| `placeni_mesec` | float64 | 64.4% | 3 | 1.47 | 1.00 | 12.00 |
| `placena_godina` | float64 | 64.4% | 2 | 2025.96 | 2025.00 | 2026.00 |
| `sati_pre_polaska` | datetime64[ns] | 96.0% | 10 | N/A | N/A | N/A |
| `broj_mesta` | int64 | 0.0% | 1 | 1.00 | 1.00 | 1.00 |
| `detalji` | str | 87.5% | 78 | N/A | N/A | N/A |
| `meta` | object | 26.6% | 65 | N/A | N/A | N/A |
| `putnik_ime` | str | 0.0% | 62 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "putnik_id",
    "datum",
    "tip",
    "iznos",
    "vozac_id",
    "created_at",
    "placeni_mesec",
    "placena_godina",
    "sati_pre_polaska",
    "broj_mesta",
    "detalji",
    "meta",
    "putnik_ime"
  ],
  "null_percentages": [
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    29.799999999999997,
    0.0,
    64.4,
    64.4,
    96.0,
    0.0,
    87.5,
    26.6,
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
    "datetime64[us, UTC]",
    "datetime64[ns]",
    "int64",
    "object"
  ],
  "counts": [
    6,
    1,
    3,
    1,
    1,
    1,
    1
  ]
}
```



## 💡 PREPORUKE (4)

1. Kolona placeni_mesec ima 64.4% NULL vrednosti - razmotriti optimizaciju
2. Kolona placena_godina ima 64.4% NULL vrednosti - razmotriti optimizaciju
3. Kolona sati_pre_polaska ima 96.0% NULL vrednosti - razmotriti optimizaciju
4. Kolona detalji ima 87.5% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 1000,
  "total_columns": 14,
  "column_analysis": {
    "id": {
      "total_values": 1000,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1000,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "putnik_id": {
      "total_values": 1000,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 62,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "datum": {
      "total_values": 1000,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 20,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "tip": {
      "total_values": 1000,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 10,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "iznos": {
      "total_values": 1000,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 15,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 257.0,
      "median": 0.0,
      "std": 1525.2269723937213,
      "min": 0.0,
      "max": 14000.0
    },
    "vozac_id": {
      "total_values": 1000,
      "null_values": 298,
      "null_percentage": 29.799999999999997,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "created_at": {
      "total_values": 1000,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 933,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "placeni_mesec": {
      "total_values": 1000,
      "null_values": 644,
      "null_percentage": 64.4,
      "unique_values": 3,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 1.4747191011235956,
      "median": 1.0,
      "std": 2.193956148797279,
      "min": 1.0,
      "max": 12.0
    },
    "placena_godina": {
      "total_values": 1000,
      "null_values": 644,
      "null_percentage": 64.4,
      "unique_values": 2,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 2025.9550561797753,
      "median": 2026.0,
      "std": 0.2074723730218956,
      "min": 2025.0,
      "max": 2026.0
    },
    "sati_pre_polaska": {
      "total_values": 1000,
      "null_values": 960,
      "null_percentage": 96.0,
      "unique_values": 10,
      "data_types": [
        "datetime64[ns]"
      ],
      "dtype": "datetime64[ns]"
    },
    "broj_mesta": {
      "total_values": 1000,
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
    "detalji": {
      "total_values": 1000,
      "null_values": 875,
      "null_percentage": 87.5,
      "unique_values": 78,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "meta": {
      "total_values": 1000,
      "null_values": 266,
      "null_percentage": 26.6,
      "unique_values": 65,
      "data_types": [
        "object"
      ],
      "dtype": "object"
    },
    "putnik_ime": {
      "total_values": 1000,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 62,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    }
  },
  "data_size_mb": 0.5871114730834961,
  "datum_range": {
    "min": "2025-11-23 00:00:00",
    "max": "2026-01-29 00:00:00",
    "span_days": 67
  },
  "created_at_range": {
    "min": "2025-11-23 21:37:03.322124+00:00",
    "max": "2026-01-29 21:00:00.044830+00:00",
    "span_days": 66
  },
  "sati_pre_polaska_range": {
    "min": "1970-01-01 00:00:00",
    "max": "1970-01-01 00:00:00.000000017",
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
