
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: PENDING_RESOLUTION_QUEUE
## 📅 Datum: 2026-01-29 22:12:26

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `pending_resolution_queue`
- **Ukupno redova**: 271
- **Ukupno kolona**: 13
- **Veličina podataka**: 0.20 MB


### 📅 Vremenski raspon (old_status)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (new_status)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (created_at)
- **Početak**: 2026-01-15 11:16:16.480881+00:00
- **Kraj**: 2026-01-27 09:58:00.019423+00:00
- **Trajanje dana**: 11


### 📅 Vremenski raspon (sent_at)
- **Početak**: 2026-01-15 11:19:22.436769+00:00
- **Kraj**: 2026-01-27 09:59:00.022225+00:00
- **Trajanje dana**: 11


### 📅 Vremenski raspon (alternative_time)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 271 | N/A | N/A | N/A |
| `putnik_id` | str | 0.0% | 24 | N/A | N/A | N/A |
| `grad` | str | 0.0% | 2 | N/A | N/A | N/A |
| `dan` | str | 0.0% | 5 | N/A | N/A | N/A |
| `vreme` | str | 0.0% | 18 | N/A | N/A | N/A |
| `old_status` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `new_status` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `message_title` | str | 0.7% | 5 | N/A | N/A | N/A |
| `message_body` | str | 0.7% | 34 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 130 | N/A | N/A | N/A |
| `sent` | bool | 0.0% | 1 | 1.00 | 1.00 | 1.00 |
| `sent_at` | datetime64[us, UTC] | 0.0% | 129 | N/A | N/A | N/A |
| `alternative_time` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "putnik_id",
    "grad",
    "dan",
    "vreme",
    "old_status",
    "new_status",
    "message_title",
    "message_body",
    "created_at",
    "sent",
    "sent_at",
    "alternative_time"
  ],
  "null_percentages": [
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    100.0,
    100.0,
    0.7380073800738007,
    0.7380073800738007,
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
    "datetime64[s]",
    "datetime64[us, UTC]",
    "bool"
  ],
  "counts": [
    7,
    3,
    2,
    1
  ]
}
```



## 💡 PREPORUKE (3)

1. Kolona old_status ima 100.0% NULL vrednosti - razmotriti optimizaciju
2. Kolona new_status ima 100.0% NULL vrednosti - razmotriti optimizaciju
3. Kolona alternative_time ima 100.0% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 271,
  "total_columns": 13,
  "column_analysis": {
    "id": {
      "total_values": 271,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 271,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "putnik_id": {
      "total_values": 271,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 24,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "grad": {
      "total_values": 271,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "dan": {
      "total_values": 271,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 5,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "vreme": {
      "total_values": 271,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 18,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "old_status": {
      "total_values": 271,
      "null_values": 271,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "new_status": {
      "total_values": 271,
      "null_values": 271,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "message_title": {
      "total_values": 271,
      "null_values": 2,
      "null_percentage": 0.7380073800738007,
      "unique_values": 5,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "message_body": {
      "total_values": 271,
      "null_values": 2,
      "null_percentage": 0.7380073800738007,
      "unique_values": 34,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "created_at": {
      "total_values": 271,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 130,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "sent": {
      "total_values": 271,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "bool"
      ],
      "dtype": "bool",
      "mean": 1.0,
      "median": 1.0,
      "std": 0.0,
      "min": 1.0,
      "max": 1.0
    },
    "sent_at": {
      "total_values": 271,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 129,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "alternative_time": {
      "total_values": 271,
      "null_values": 271,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    }
  },
  "data_size_mb": 0.2008218765258789,
  "old_status_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "new_status_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "created_at_range": {
    "min": "2026-01-15 11:16:16.480881+00:00",
    "max": "2026-01-27 09:58:00.019423+00:00",
    "span_days": 11
  },
  "sent_at_range": {
    "min": "2026-01-15 11:19:22.436769+00:00",
    "max": "2026-01-27 09:59:00.022225+00:00",
    "span_days": 11
  },
  "alternative_time_range": {
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
