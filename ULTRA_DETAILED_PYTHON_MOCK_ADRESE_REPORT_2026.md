
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: ADRESE
## 📅 Datum: 2026-01-29 22:09:20
## 🔧 OFFLINE MODE (MOCK DATA)

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `adrese`
- **Ukupno redova**: 30
- **Ukupno kolona**: 5
- **Veličina podataka**: 0.01 MB
- **Režim**: Mock podaci (demonstracija)


### 📅 Vremenski raspon (koordinate)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (created_at)
- **Početak**: 2025-02-16 22:09:20.250271
- **Kraj**: 2026-01-12 22:09:20.250271
- **Trajanje dana**: 330


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 30 | N/A | N/A | N/A |
| `naziv` | str | 0.0% | 30 | N/A | N/A | N/A |
| `koordinate` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `grad` | str | 0.0% | 4 | N/A | N/A | N/A |
| `created_at` | datetime64[us] | 0.0% | 27 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "naziv",
    "koordinate",
    "grad",
    "created_at"
  ],
  "null_percentages": [
    0.0,
    0.0,
    100.0,
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
    "datetime64[s]",
    "datetime64[us]"
  ],
  "counts": [
    3,
    1,
    1
  ]
}
```



## 💡 PREPORUKE (1)

1. Kolona koordinate ima 100.0% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 30,
  "total_columns": 5,
  "column_analysis": {
    "id": {
      "total_values": 30,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 30,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "naziv": {
      "total_values": 30,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 30,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "koordinate": {
      "total_values": 30,
      "null_values": 30,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "grad": {
      "total_values": 30,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "created_at": {
      "total_values": 30,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 27,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    }
  },
  "data_size_mb": 0.005671501159667969,
  "koordinate_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "created_at_range": {
    "min": "2025-02-16 22:09:20.250271",
    "max": "2026-01-12 22:09:20.250271",
    "span_days": 330
  }
}
```

---

## ✅ ZAKLJUČAK

**Status**: ✅ ISPRAVNO

**Vizuelizacije**: ✅ GENERISANE

**Preporučeno**: ✅ SPREMNO ZA PRODUKCIJU

---
*Generisano Ultra Detailed Python Analyzer v2.1*
