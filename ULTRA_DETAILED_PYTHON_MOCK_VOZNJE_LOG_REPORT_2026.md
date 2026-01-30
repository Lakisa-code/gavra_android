
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: VOZNJE_LOG
## 📅 Datum: 2026-01-29 22:09:20
## 🔧 OFFLINE MODE (MOCK DATA)

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `voznje_log`
- **Ukupno redova**: 100
- **Ukupno kolona**: 6
- **Veličina podataka**: 0.02 MB
- **Režim**: Mock podaci (demonstracija)


### 📅 Vremenski raspon (created_at)
- **Početak**: 2025-12-30 22:09:20.216173
- **Kraj**: 2026-01-29 22:09:20.218187
- **Trajanje dana**: 30


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 100 | N/A | N/A | N/A |
| `putnik_id` | str | 0.0% | 40 | N/A | N/A | N/A |
| `vozac_id` | str | 0.0% | 4 | N/A | N/A | N/A |
| `iznos` | float64 | 0.0% | 100 | 260.97 | 52.12 | 475.14 |
| `tip` | str | 0.0% | 3 | N/A | N/A | N/A |
| `created_at` | datetime64[us] | 0.0% | 46 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (4)

### Null Analysis
```json
{
  "columns": [
    "id",
    "putnik_id",
    "vozac_id",
    "iznos",
    "tip",
    "created_at"
  ],
  "null_percentages": [
    0.0,
    0.0,
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
    "datetime64[us]"
  ],
  "counts": [
    4,
    1,
    1
  ]
}
```

### Ride Types
```json
{
  "types": [
    "express",
    "standard",
    "vip"
  ],
  "counts": [
    37,
    32,
    31
  ]
}
```

### Amount Distribution
```json
{
  "ranges": [
    "Negative",
    "0-100",
    "100-200",
    "200-500",
    "500-1000",
    "1000+"
  ],
  "counts": [
    0,
    10,
    24,
    66,
    0,
    0
  ]
}
```



## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 100,
  "total_columns": 6,
  "column_analysis": {
    "id": {
      "total_values": 100,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 100,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "putnik_id": {
      "total_values": 100,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 40,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "vozac_id": {
      "total_values": 100,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "iznos": {
      "total_values": 100,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 100,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 260.97009999999995,
      "median": 260.325,
      "std": 118.67814964440673,
      "min": 52.12,
      "max": 475.14
    },
    "tip": {
      "total_values": 100,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 3,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "created_at": {
      "total_values": 100,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 46,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    }
  },
  "data_size_mb": 0.02327442169189453,
  "created_at_range": {
    "min": "2025-12-30 22:09:20.216173",
    "max": "2026-01-29 22:09:20.218187",
    "span_days": 30
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
