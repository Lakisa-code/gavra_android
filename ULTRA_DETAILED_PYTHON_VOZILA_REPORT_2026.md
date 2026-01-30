
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: VOZILA
## 📅 Datum: 2026-01-29 22:12:28

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `vozila`
- **Ukupno redova**: 5
- **Ukupno kolona**: 36
- **Veličina podataka**: 0.00 MB


### 📅 Vremenski raspon (mali_servis_datum)
- **Početak**: 2026-01-01 00:00:00
- **Kraj**: 2026-01-29 00:00:00
- **Trajanje dana**: 28


### 📅 Vremenski raspon (veliki_servis_datum)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (alternator_datum)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (alternator_km)
- **Početak**: 1970-01-01 00:00:00.000254
- **Kraj**: 1970-01-01 00:00:00.000440
- **Trajanje dana**: 0


### 📅 Vremenski raspon (gume_datum)
- **Početak**: 2026-01-01 00:00:00
- **Kraj**: 2026-01-13 00:00:00
- **Trajanje dana**: 12


### 📅 Vremenski raspon (akumulator_datum)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (akumulator_km)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (plocice_datum)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (trap_datum)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (gume_prednje_datum)
- **Početak**: 2025-01-08 00:00:00
- **Kraj**: 2026-01-13 00:00:00
- **Trajanje dana**: 370


### 📅 Vremenski raspon (gume_zadnje_datum)
- **Početak**: 2026-01-01 00:00:00
- **Kraj**: 2026-01-01 00:00:00
- **Trajanje dana**: 0


### 📅 Vremenski raspon (plocice_prednje_datum)
- **Početak**: 2026-01-22 00:00:00
- **Kraj**: 2026-01-22 00:00:00
- **Trajanje dana**: 0


### 📅 Vremenski raspon (plocice_zadnje_datum)
- **Početak**: 2026-01-23 00:00:00
- **Kraj**: 2026-01-23 00:00:00
- **Trajanje dana**: 0


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 5 | N/A | N/A | N/A |
| `registarski_broj` | str | 0.0% | 5 | N/A | N/A | N/A |
| `marka` | str | 0.0% | 1 | N/A | N/A | N/A |
| `model` | str | 0.0% | 1 | N/A | N/A | N/A |
| `godina_proizvodnje` | int64 | 0.0% | 5 | 2008.80 | 2006.00 | 2012.00 |
| `broj_mesta` | int64 | 0.0% | 3 | 9.60 | 8.00 | 14.00 |
| `naziv` | str | 20.0% | 4 | N/A | N/A | N/A |
| `broj_sasije` | str | 0.0% | 5 | N/A | N/A | N/A |
| `registracija_vazi_do` | str | 0.0% | 5 | N/A | N/A | N/A |
| `mali_servis_datum` | datetime64[us] | 20.0% | 4 | N/A | N/A | N/A |
| `mali_servis_km` | float64 | 20.0% | 4 | 423691.25 | 271765.00 | 498000.00 |
| `veliki_servis_datum` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `veliki_servis_km` | float64 | 60.0% | 2 | 388500.00 | 337000.00 | 440000.00 |
| `alternator_datum` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `alternator_km` | datetime64[ns] | 60.0% | 2 | N/A | N/A | N/A |
| `gume_datum` | datetime64[us] | 60.0% | 2 | N/A | N/A | N/A |
| `gume_opis` | str | 60.0% | 2 | N/A | N/A | N/A |
| `napomena` | str | 80.0% | 1 | N/A | N/A | N/A |
| `akumulator_datum` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `akumulator_km` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `plocice_datum` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `plocice_km` | object | 100.0% | 0 | N/A | N/A | N/A |
| `trap_datum` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `trap_km` | object | 100.0% | 0 | N/A | N/A | N/A |
| `radio` | str | 40.0% | 3 | N/A | N/A | N/A |
| `gume_prednje_datum` | datetime64[us] | 40.0% | 3 | N/A | N/A | N/A |
| `gume_prednje_opis` | str | 40.0% | 2 | N/A | N/A | N/A |
| `gume_zadnje_datum` | datetime64[us] | 60.0% | 1 | N/A | N/A | N/A |
| `gume_zadnje_opis` | str | 60.0% | 2 | N/A | N/A | N/A |
| `kilometraza` | float64 | 0.0% | 5 | 339763.80 | 0.00 | 498000.00 |
| `plocice_prednje_datum` | datetime64[us] | 80.0% | 1 | N/A | N/A | N/A |
| `plocice_prednje_km` | float64 | 80.0% | 1 | 468000.00 | 468000.00 | 468000.00 |
| `plocice_zadnje_datum` | datetime64[us] | 80.0% | 1 | N/A | N/A | N/A |
| `plocice_zadnje_km` | float64 | 80.0% | 1 | 471000.00 | 471000.00 | 471000.00 |
| `gume_prednje_km` | float64 | 80.0% | 1 | 471000.00 | 471000.00 | 471000.00 |
| `gume_zadnje_km` | object | 100.0% | 0 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "registarski_broj",
    "marka",
    "model",
    "godina_proizvodnje",
    "broj_mesta",
    "naziv",
    "broj_sasije",
    "registracija_vazi_do",
    "mali_servis_datum",
    "mali_servis_km",
    "veliki_servis_datum",
    "veliki_servis_km",
    "alternator_datum",
    "alternator_km",
    "gume_datum",
    "gume_opis",
    "napomena",
    "akumulator_datum",
    "akumulator_km",
    "plocice_datum",
    "plocice_km",
    "trap_datum",
    "trap_km",
    "radio",
    "gume_prednje_datum",
    "gume_prednje_opis",
    "gume_zadnje_datum",
    "gume_zadnje_opis",
    "kilometraza",
    "plocice_prednje_datum",
    "plocice_prednje_km",
    "plocice_zadnje_datum",
    "plocice_zadnje_km",
    "gume_prednje_km",
    "gume_zadnje_km"
  ],
  "null_percentages": [
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    20.0,
    0.0,
    0.0,
    20.0,
    20.0,
    100.0,
    60.0,
    100.0,
    60.0,
    60.0,
    60.0,
    80.0,
    100.0,
    100.0,
    100.0,
    100.0,
    100.0,
    100.0,
    40.0,
    40.0,
    40.0,
    60.0,
    60.0,
    0.0,
    80.0,
    80.0,
    80.0,
    80.0,
    80.0,
    100.0
  ]
}
```

### Dtype Distribution
```json
{
  "dtypes": [
    "str",
    "int64",
    "datetime64[us]",
    "float64",
    "datetime64[s]",
    "datetime64[ns]",
    "object"
  ],
  "counts": [
    12,
    2,
    6,
    6,
    6,
    1,
    3
  ]
}
```



## 💡 PREPORUKE (21)

1. Kolona veliki_servis_datum ima 100.0% NULL vrednosti - razmotriti optimizaciju
2. Kolona veliki_servis_km ima 60.0% NULL vrednosti - razmotriti optimizaciju
3. Kolona alternator_datum ima 100.0% NULL vrednosti - razmotriti optimizaciju
4. Kolona alternator_km ima 60.0% NULL vrednosti - razmotriti optimizaciju
5. Kolona gume_datum ima 60.0% NULL vrednosti - razmotriti optimizaciju
6. Kolona gume_opis ima 60.0% NULL vrednosti - razmotriti optimizaciju
7. Kolona napomena ima 80.0% NULL vrednosti - razmotriti optimizaciju
8. Kolona akumulator_datum ima 100.0% NULL vrednosti - razmotriti optimizaciju
9. Kolona akumulator_km ima 100.0% NULL vrednosti - razmotriti optimizaciju
10. Kolona plocice_datum ima 100.0% NULL vrednosti - razmotriti optimizaciju
11. Kolona plocice_km ima 100.0% NULL vrednosti - razmotriti optimizaciju
12. Kolona trap_datum ima 100.0% NULL vrednosti - razmotriti optimizaciju
13. Kolona trap_km ima 100.0% NULL vrednosti - razmotriti optimizaciju
14. Kolona gume_zadnje_datum ima 60.0% NULL vrednosti - razmotriti optimizaciju
15. Kolona gume_zadnje_opis ima 60.0% NULL vrednosti - razmotriti optimizaciju
16. Kolona plocice_prednje_datum ima 80.0% NULL vrednosti - razmotriti optimizaciju
17. Kolona plocice_prednje_km ima 80.0% NULL vrednosti - razmotriti optimizaciju
18. Kolona plocice_zadnje_datum ima 80.0% NULL vrednosti - razmotriti optimizaciju
19. Kolona plocice_zadnje_km ima 80.0% NULL vrednosti - razmotriti optimizaciju
20. Kolona gume_prednje_km ima 80.0% NULL vrednosti - razmotriti optimizaciju
21. Kolona gume_zadnje_km ima 100.0% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 5,
  "total_columns": 36,
  "column_analysis": {
    "id": {
      "total_values": 5,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 5,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "registarski_broj": {
      "total_values": 5,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 5,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "marka": {
      "total_values": 5,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "model": {
      "total_values": 5,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "godina_proizvodnje": {
      "total_values": 5,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 5,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 2008.8,
      "median": 2009.0,
      "std": 2.3874672772626644,
      "min": 2006.0,
      "max": 2012.0
    },
    "broj_mesta": {
      "total_values": 5,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 3,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 9.6,
      "median": 8.0,
      "std": 2.6076809620810595,
      "min": 8.0,
      "max": 14.0
    },
    "naziv": {
      "total_values": 5,
      "null_values": 1,
      "null_percentage": 20.0,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "broj_sasije": {
      "total_values": 5,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 5,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "registracija_vazi_do": {
      "total_values": 5,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 5,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "mali_servis_datum": {
      "total_values": 5,
      "null_values": 1,
      "null_percentage": 20.0,
      "unique_values": 4,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "mali_servis_km": {
      "total_values": 5,
      "null_values": 1,
      "null_percentage": 20.0,
      "unique_values": 4,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 423691.25,
      "median": 462500.0,
      "std": 102755.55770654614,
      "min": 271765.0,
      "max": 498000.0
    },
    "veliki_servis_datum": {
      "total_values": 5,
      "null_values": 5,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "veliki_servis_km": {
      "total_values": 5,
      "null_values": 3,
      "null_percentage": 60.0,
      "unique_values": 2,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 388500.0,
      "median": 388500.0,
      "std": 72831.9984622144,
      "min": 337000.0,
      "max": 440000.0
    },
    "alternator_datum": {
      "total_values": 5,
      "null_values": 5,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "alternator_km": {
      "total_values": 5,
      "null_values": 3,
      "null_percentage": 60.0,
      "unique_values": 2,
      "data_types": [
        "datetime64[ns]"
      ],
      "dtype": "datetime64[ns]"
    },
    "gume_datum": {
      "total_values": 5,
      "null_values": 3,
      "null_percentage": 60.0,
      "unique_values": 2,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "gume_opis": {
      "total_values": 5,
      "null_values": 3,
      "null_percentage": 60.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "napomena": {
      "total_values": 5,
      "null_values": 4,
      "null_percentage": 80.0,
      "unique_values": 1,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "akumulator_datum": {
      "total_values": 5,
      "null_values": 5,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "akumulator_km": {
      "total_values": 5,
      "null_values": 5,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "plocice_datum": {
      "total_values": 5,
      "null_values": 5,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "plocice_km": {
      "total_values": 5,
      "null_values": 5,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "object"
    },
    "trap_datum": {
      "total_values": 5,
      "null_values": 5,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "trap_km": {
      "total_values": 5,
      "null_values": 5,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "object"
    },
    "radio": {
      "total_values": 5,
      "null_values": 2,
      "null_percentage": 40.0,
      "unique_values": 3,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "gume_prednje_datum": {
      "total_values": 5,
      "null_values": 2,
      "null_percentage": 40.0,
      "unique_values": 3,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "gume_prednje_opis": {
      "total_values": 5,
      "null_values": 2,
      "null_percentage": 40.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "gume_zadnje_datum": {
      "total_values": 5,
      "null_values": 3,
      "null_percentage": 60.0,
      "unique_values": 1,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "gume_zadnje_opis": {
      "total_values": 5,
      "null_values": 3,
      "null_percentage": 60.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "kilometraza": {
      "total_values": 5,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 5,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 339763.8,
      "median": 458054.0,
      "std": 209950.87710509807,
      "min": 0.0,
      "max": 498000.0
    },
    "plocice_prednje_datum": {
      "total_values": 5,
      "null_values": 4,
      "null_percentage": 80.0,
      "unique_values": 1,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "plocice_prednje_km": {
      "total_values": 5,
      "null_values": 4,
      "null_percentage": 80.0,
      "unique_values": 1,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 468000.0,
      "median": 468000.0,
      "std": NaN,
      "min": 468000.0,
      "max": 468000.0
    },
    "plocice_zadnje_datum": {
      "total_values": 5,
      "null_values": 4,
      "null_percentage": 80.0,
      "unique_values": 1,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "plocice_zadnje_km": {
      "total_values": 5,
      "null_values": 4,
      "null_percentage": 80.0,
      "unique_values": 1,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 471000.0,
      "median": 471000.0,
      "std": NaN,
      "min": 471000.0,
      "max": 471000.0
    },
    "gume_prednje_km": {
      "total_values": 5,
      "null_values": 4,
      "null_percentage": 80.0,
      "unique_values": 1,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 471000.0,
      "median": 471000.0,
      "std": NaN,
      "min": 471000.0,
      "max": 471000.0
    },
    "gume_zadnje_km": {
      "total_values": 5,
      "null_values": 5,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "object"
    }
  },
  "data_size_mb": 0.0047321319580078125,
  "mali_servis_datum_range": {
    "min": "2026-01-01 00:00:00",
    "max": "2026-01-29 00:00:00",
    "span_days": 28
  },
  "veliki_servis_datum_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "alternator_datum_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "alternator_km_range": {
    "min": "1970-01-01 00:00:00.000254",
    "max": "1970-01-01 00:00:00.000440",
    "span_days": 0
  },
  "gume_datum_range": {
    "min": "2026-01-01 00:00:00",
    "max": "2026-01-13 00:00:00",
    "span_days": 12
  },
  "akumulator_datum_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "akumulator_km_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "plocice_datum_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "trap_datum_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "gume_prednje_datum_range": {
    "min": "2025-01-08 00:00:00",
    "max": "2026-01-13 00:00:00",
    "span_days": 370
  },
  "gume_zadnje_datum_range": {
    "min": "2026-01-01 00:00:00",
    "max": "2026-01-01 00:00:00",
    "span_days": 0
  },
  "plocice_prednje_datum_range": {
    "min": "2026-01-22 00:00:00",
    "max": "2026-01-22 00:00:00",
    "span_days": 0
  },
  "plocice_zadnje_datum_range": {
    "min": "2026-01-23 00:00:00",
    "max": "2026-01-23 00:00:00",
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
