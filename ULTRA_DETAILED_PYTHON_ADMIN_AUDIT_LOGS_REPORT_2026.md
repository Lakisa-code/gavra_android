
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: ADMIN_AUDIT_LOGS
## 📅 Datum: 2026-01-29 22:12:25

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `admin_audit_logs`
- **Ukupno redova**: 45
- **Ukupno kolona**: 6
- **Veličina podataka**: 0.01 MB


### 📅 Vremenski raspon (created_at)
- **Početak**: 2026-01-17 07:45:36.809871+00:00
- **Kraj**: 2026-01-29 11:07:53.465172+00:00
- **Trajanje dana**: 12


### 📅 Vremenski raspon (metadata)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 45 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 45 | N/A | N/A | N/A |
| `admin_name` | str | 0.0% | 2 | N/A | N/A | N/A |
| `action_type` | str | 0.0% | 4 | N/A | N/A | N/A |
| `details` | str | 0.0% | 33 | N/A | N/A | N/A |
| `metadata` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "created_at",
    "admin_name",
    "action_type",
    "details",
    "metadata"
  ],
  "null_percentages": [
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    100.0
  ]
}
```

### Dtype Distribution
```json
{
  "dtypes": [
    "str",
    "datetime64[us, UTC]",
    "datetime64[s]"
  ],
  "counts": [
    4,
    1,
    1
  ]
}
```



## 💡 PREPORUKE (1)

1. Kolona metadata ima 100.0% NULL vrednosti - razmotriti optimizaciju


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
    "created_at": {
      "total_values": 45,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 45,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "admin_name": {
      "total_values": 45,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "action_type": {
      "total_values": 45,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "details": {
      "total_values": 45,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 33,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "metadata": {
      "total_values": 45,
      "null_values": 45,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    }
  },
  "data_size_mb": 0.014233589172363281,
  "created_at_range": {
    "min": "2026-01-17 07:45:36.809871+00:00",
    "max": "2026-01-29 11:07:53.465172+00:00",
    "span_days": 12
  },
  "metadata_range": {
    "min": "NaT",
    "max": "NaT",
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
