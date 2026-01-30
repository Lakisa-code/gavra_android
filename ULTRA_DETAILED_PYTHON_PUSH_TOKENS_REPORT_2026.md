
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: PUSH_TOKENS
## 📅 Datum: 2026-01-29 22:12:27

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `push_tokens`
- **Ukupno redova**: 46
- **Ukupno kolona**: 9
- **Veličina podataka**: 0.02 MB


### 📅 Vremenski raspon (created_at)
- **Početak**: 2026-01-13 08:44:12.302642+00:00
- **Kraj**: 2026-01-29 21:07:56.341842+00:00
- **Trajanje dana**: 16


### 📅 Vremenski raspon (updated_at)
- **Početak**: 2026-01-13 10:30:27.498968+00:00
- **Kraj**: 2026-01-29 22:07:55.441098+00:00
- **Trajanje dana**: 16


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 46 | N/A | N/A | N/A |
| `provider` | str | 0.0% | 2 | N/A | N/A | N/A |
| `token` | str | 0.0% | 46 | N/A | N/A | N/A |
| `user_id` | str | 37.0% | 29 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 46 | N/A | N/A | N/A |
| `updated_at` | datetime64[us, UTC] | 0.0% | 46 | N/A | N/A | N/A |
| `user_type` | str | 0.0% | 2 | N/A | N/A | N/A |
| `putnik_id` | str | 50.0% | 23 | N/A | N/A | N/A |
| `vozac_id` | str | 97.8% | 1 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "provider",
    "token",
    "user_id",
    "created_at",
    "updated_at",
    "user_type",
    "putnik_id",
    "vozac_id"
  ],
  "null_percentages": [
    0.0,
    0.0,
    0.0,
    36.95652173913043,
    0.0,
    0.0,
    0.0,
    50.0,
    97.82608695652173
  ]
}
```

### Dtype Distribution
```json
{
  "dtypes": [
    "str",
    "datetime64[us, UTC]"
  ],
  "counts": [
    7,
    2
  ]
}
```



## 💡 PREPORUKE (1)

1. Kolona vozac_id ima 97.8% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 46,
  "total_columns": 9,
  "column_analysis": {
    "id": {
      "total_values": 46,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 46,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "provider": {
      "total_values": 46,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "token": {
      "total_values": 46,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 46,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "user_id": {
      "total_values": 46,
      "null_values": 17,
      "null_percentage": 36.95652173913043,
      "unique_values": 29,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "created_at": {
      "total_values": 46,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 46,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "updated_at": {
      "total_values": 46,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 46,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "user_type": {
      "total_values": 46,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "putnik_id": {
      "total_values": 46,
      "null_values": 23,
      "null_percentage": 50.0,
      "unique_values": 23,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "vozac_id": {
      "total_values": 46,
      "null_values": 45,
      "null_percentage": 97.82608695652173,
      "unique_values": 1,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    }
  },
  "data_size_mb": 0.02410125732421875,
  "created_at_range": {
    "min": "2026-01-13 08:44:12.302642+00:00",
    "max": "2026-01-29 21:07:56.341842+00:00",
    "span_days": 16
  },
  "updated_at_range": {
    "min": "2026-01-13 10:30:27.498968+00:00",
    "max": "2026-01-29 22:07:55.441098+00:00",
    "span_days": 16
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
