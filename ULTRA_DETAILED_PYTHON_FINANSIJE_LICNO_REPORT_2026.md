
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: FINANSIJE_LICNO
## 📅 Datum: 2026-01-29 22:12:26

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `finansije_licno`
- **Ukupno redova**: 3
- **Ukupno kolona**: 5
- **Veličina podataka**: 0.00 MB


### 📅 Vremenski raspon (created_at)
- **Početak**: 2026-01-17 00:45:13.329197+00:00
- **Kraj**: 2026-01-17 00:47:26.088331+00:00
- **Trajanje dana**: 0


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 3 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 3 | N/A | N/A | N/A |
| `tip` | str | 0.0% | 2 | N/A | N/A | N/A |
| `naziv` | str | 0.0% | 3 | N/A | N/A | N/A |
| `iznos` | float64 | 0.0% | 3 | 374235.33 | 12306.00 | 820400.00 |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "created_at",
    "tip",
    "naziv",
    "iznos"
  ],
  "null_percentages": [
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
    "datetime64[us, UTC]",
    "float64"
  ],
  "counts": [
    3,
    1,
    1
  ]
}
```



## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 3,
  "total_columns": 5,
  "column_analysis": {
    "id": {
      "total_values": 3,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 3,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "created_at": {
      "total_values": 3,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 3,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "tip": {
      "total_values": 3,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "naziv": {
      "total_values": 3,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 3,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "iznos": {
      "total_values": 3,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 3,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 374235.3333333333,
      "median": 290000.0,
      "std": 410579.6777062077,
      "min": 12306.0,
      "max": 820400.0
    }
  },
  "data_size_mb": 0.00072479248046875,
  "created_at_range": {
    "min": "2026-01-17 00:45:13.329197+00:00",
    "max": "2026-01-17 00:47:26.088331+00:00",
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
