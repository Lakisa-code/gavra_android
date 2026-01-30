
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: SEAT_REQUEST_NOTIFICATIONS
## 📅 Datum: 2026-01-29 22:12:28

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `seat_request_notifications`
- **Ukupno redova**: 16
- **Ukupno kolona**: 8
- **Veličina podataka**: 0.01 MB


### 📅 Vremenski raspon (seat_request_id)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (sent_at)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (created_at)
- **Početak**: 2026-01-28 08:00:00.039519+00:00
- **Kraj**: 2026-01-29 20:50:00.049690+00:00
- **Trajanje dana**: 1


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 16 | N/A | N/A | N/A |
| `putnik_id` | str | 0.0% | 6 | N/A | N/A | N/A |
| `seat_request_id` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `title` | str | 0.0% | 3 | N/A | N/A | N/A |
| `body` | str | 0.0% | 7 | N/A | N/A | N/A |
| `sent` | bool | 0.0% | 1 | 0.00 | 0.00 | 0.00 |
| `sent_at` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 10 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "putnik_id",
    "seat_request_id",
    "title",
    "body",
    "sent",
    "sent_at",
    "created_at"
  ],
  "null_percentages": [
    0.0,
    0.0,
    100.0,
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
    "bool",
    "datetime64[us, UTC]"
  ],
  "counts": [
    4,
    2,
    1,
    1
  ]
}
```



## 💡 PREPORUKE (2)

1. Kolona seat_request_id ima 100.0% NULL vrednosti - razmotriti optimizaciju
2. Kolona sent_at ima 100.0% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 16,
  "total_columns": 8,
  "column_analysis": {
    "id": {
      "total_values": 16,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 16,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "putnik_id": {
      "total_values": 16,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 6,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "seat_request_id": {
      "total_values": 16,
      "null_values": 16,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "title": {
      "total_values": 16,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 3,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "body": {
      "total_values": 16,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 7,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "sent": {
      "total_values": 16,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "bool"
      ],
      "dtype": "bool",
      "mean": 0.0,
      "median": 0.0,
      "std": 0.0,
      "min": 0.0,
      "max": 0.0
    },
    "sent_at": {
      "total_values": 16,
      "null_values": 16,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "created_at": {
      "total_values": 16,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 10,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    }
  },
  "data_size_mb": 0.007923126220703125,
  "seat_request_id_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "sent_at_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "created_at_range": {
    "min": "2026-01-28 08:00:00.039519+00:00",
    "max": "2026-01-29 20:50:00.049690+00:00",
    "span_days": 1
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
