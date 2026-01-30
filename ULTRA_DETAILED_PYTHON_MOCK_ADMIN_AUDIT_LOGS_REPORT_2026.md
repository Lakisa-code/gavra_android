
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: ADMIN_AUDIT_LOGS
## 📅 Datum: 2026-01-29 22:09:20
## 🔧 OFFLINE MODE (MOCK DATA)

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `admin_audit_logs`
- **Ukupno redova**: 200
- **Ukupno kolona**: 5
- **Veličina podataka**: 0.04 MB
- **Režim**: Mock podaci (demonstracija)


### 📅 Vremenski raspon (created_at)
- **Početak**: 2025-12-30 22:09:20.303842
- **Kraj**: 2026-01-29 11:09:20.303842
- **Trajanje dana**: 29


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 200 | N/A | N/A | N/A |
| `admin_name` | str | 0.0% | 3 | N/A | N/A | N/A |
| `action_type` | str | 0.0% | 4 | N/A | N/A | N/A |
| `details` | str | 0.0% | 200 | N/A | N/A | N/A |
| `created_at` | datetime64[us] | 0.0% | 183 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "admin_name",
    "action_type",
    "details",
    "created_at"
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
    "datetime64[us]"
  ],
  "counts": [
    4,
    1
  ]
}
```



## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 200,
  "total_columns": 5,
  "column_analysis": {
    "id": {
      "total_values": 200,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 200,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "admin_name": {
      "total_values": 200,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 3,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "action_type": {
      "total_values": 200,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "details": {
      "total_values": 200,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 200,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "created_at": {
      "total_values": 200,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 183,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    }
  },
  "data_size_mb": 0.044490814208984375,
  "created_at_range": {
    "min": "2025-12-30 22:09:20.303842",
    "max": "2026-01-29 11:09:20.303842",
    "span_days": 29
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
