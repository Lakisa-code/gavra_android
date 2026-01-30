
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: PIN_ZAHTEVI
## 📅 Datum: 2026-01-29 22:12:26

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `pin_zahtevi`
- **Ukupno redova**: 45
- **Ukupno kolona**: 6
- **Veličina podataka**: 0.01 MB


### 📅 Vremenski raspon (status)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (created_at)
- **Početak**: 2026-01-02 17:55:51.689920+00:00
- **Kraj**: 2026-01-29 07:26:56.096837+00:00
- **Trajanje dana**: 26


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 45 | N/A | N/A | N/A |
| `putnik_id` | str | 0.0% | 45 | N/A | N/A | N/A |
| `email` | str | 0.0% | 44 | N/A | N/A | N/A |
| `telefon` | str | 0.0% | 44 | N/A | N/A | N/A |
| `status` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 45 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "putnik_id",
    "email",
    "telefon",
    "status",
    "created_at"
  ],
  "null_percentages": [
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
    "datetime64[us, UTC]"
  ],
  "counts": [
    4,
    1,
    1
  ]
}
```



## 💡 PREPORUKE (1)

1. Kolona status ima 100.0% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 45,
  "total_columns": 6,
  "column_analysis": {
    "id": {
      "total_values": 45,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 45,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "putnik_id": {
      "total_values": 45,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 45,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "email": {
      "total_values": 45,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 44,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "telefon": {
      "total_values": 45,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 44,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "status": {
      "total_values": 45,
      "null_values": 45,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "created_at": {
      "total_values": 45,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 45,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    }
  },
  "data_size_mb": 0.013835906982421875,
  "status_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "created_at_range": {
    "min": "2026-01-02 17:55:51.689920+00:00",
    "max": "2026-01-29 07:26:56.096837+00:00",
    "span_days": 26
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
