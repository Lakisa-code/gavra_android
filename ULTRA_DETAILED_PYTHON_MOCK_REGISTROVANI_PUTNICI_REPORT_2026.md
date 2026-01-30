
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: REGISTROVANI_PUTNICI
## 📅 Datum: 2026-01-29 22:09:20
## 🔧 OFFLINE MODE (MOCK DATA)

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `registrovani_putnici`
- **Ukupno redova**: 50
- **Ukupno kolona**: 8
- **Veličina podataka**: 0.02 MB
- **Režim**: Mock podaci (demonstracija)


### 📅 Vremenski raspon (created_at)
- **Početak**: 2025-01-30 22:09:20.162458
- **Kraj**: 2026-01-26 22:09:20.162458
- **Trajanje dana**: 361


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 50 | N/A | N/A | N/A |
| `ime` | str | 0.0% | 50 | N/A | N/A | N/A |
| `email` | str | 8.0% | 46 | N/A | N/A | N/A |
| `broj_telefona` | str | 0.0% | 50 | N/A | N/A | N/A |
| `tip` | str | 0.0% | 3 | N/A | N/A | N/A |
| `cena_po_danu` | float64 | 0.0% | 50 | 502.32 | 244.00 | 798.80 |
| `aktivan` | bool | 0.0% | 2 | 0.44 | 0.00 | 1.00 |
| `created_at` | datetime64[us] | 0.0% | 44 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (4)

### Null Analysis
```json
{
  "columns": [
    "id",
    "ime",
    "email",
    "broj_telefona",
    "tip",
    "cena_po_danu",
    "aktivan",
    "created_at"
  ],
  "null_percentages": [
    0.0,
    0.0,
    8.0,
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
    "bool",
    "datetime64[us]"
  ],
  "counts": [
    5,
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
    "senior",
    "student",
    "regular"
  ],
  "counts": [
    18,
    17,
    15
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
    0,
    0,
    9,
    18,
    23,
    0
  ]
}
```



## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 50,
  "total_columns": 8,
  "column_analysis": {
    "id": {
      "total_values": 50,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 50,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "ime": {
      "total_values": 50,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 50,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "email": {
      "total_values": 50,
      "null_values": 4,
      "null_percentage": 8.0,
      "unique_values": 46,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "broj_telefona": {
      "total_values": 50,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 50,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "tip": {
      "total_values": 50,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 3,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "cena_po_danu": {
      "total_values": 50,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 50,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 502.3172,
      "median": 473.005,
      "std": 171.1791325380807,
      "min": 244.0,
      "max": 798.8
    },
    "aktivan": {
      "total_values": 50,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "bool"
      ],
      "dtype": "bool",
      "mean": 0.44,
      "median": 0.0,
      "std": 0.501426536422407,
      "min": 0.0,
      "max": 1.0
    },
    "created_at": {
      "total_values": 50,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 44,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    }
  },
  "data_size_mb": 0.0151519775390625,
  "created_at_range": {
    "min": "2025-01-30 22:09:20.162458",
    "max": "2026-01-26 22:09:20.162458",
    "span_days": 361
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
