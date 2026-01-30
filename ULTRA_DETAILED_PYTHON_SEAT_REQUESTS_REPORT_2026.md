
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: SEAT_REQUESTS
## 📅 Datum: 2026-01-29 22:12:28

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `seat_requests`
- **Ukupno redova**: 16
- **Ukupno kolona**: 15
- **Veličina podataka**: 0.01 MB


### 📅 Vremenski raspon (datum)
- **Početak**: 2026-01-28 00:00:00
- **Kraj**: 2026-01-30 00:00:00
- **Trajanje dana**: 2


### 📅 Vremenski raspon (status)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (created_at)
- **Početak**: 2026-01-28 07:55:49.243004+00:00
- **Kraj**: 2026-01-29 20:46:14.385651+00:00
- **Trajanje dana**: 1


### 📅 Vremenski raspon (updated_at)
- **Početak**: 2026-01-28 08:00:00.039519+00:00
- **Kraj**: 2026-01-29 20:50:00.049690+00:00
- **Trajanje dana**: 1


### 📅 Vremenski raspon (processed_at)
- **Početak**: 2026-01-28 08:00:00.039519+00:00
- **Kraj**: 2026-01-29 20:50:00.049690+00:00
- **Trajanje dana**: 1


### 📅 Vremenski raspon (batch_id)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (alternatives)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 16 | N/A | N/A | N/A |
| `putnik_id` | str | 0.0% | 6 | N/A | N/A | N/A |
| `grad` | str | 0.0% | 2 | N/A | N/A | N/A |
| `datum` | datetime64[us] | 0.0% | 3 | N/A | N/A | N/A |
| `zeljeno_vreme` | str | 0.0% | 7 | N/A | N/A | N/A |
| `dodeljeno_vreme` | str | 0.0% | 7 | N/A | N/A | N/A |
| `status` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 16 | N/A | N/A | N/A |
| `updated_at` | datetime64[us, UTC] | 0.0% | 10 | N/A | N/A | N/A |
| `processed_at` | datetime64[us, UTC] | 0.0% | 10 | N/A | N/A | N/A |
| `priority` | int64 | 0.0% | 3 | 1.56 | 0.00 | 2.00 |
| `batch_id` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `alternatives` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `changes_count` | int64 | 0.0% | 1 | 0.00 | 0.00 | 0.00 |
| `broj_mesta` | int64 | 0.0% | 1 | 1.00 | 1.00 | 1.00 |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "putnik_id",
    "grad",
    "datum",
    "zeljeno_vreme",
    "dodeljeno_vreme",
    "status",
    "created_at",
    "updated_at",
    "processed_at",
    "priority",
    "batch_id",
    "alternatives",
    "changes_count",
    "broj_mesta"
  ],
  "null_percentages": [
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    100.0,
    0.0,
    0.0,
    0.0,
    0.0,
    100.0,
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
    "datetime64[us]",
    "datetime64[s]",
    "datetime64[us, UTC]",
    "int64"
  ],
  "counts": [
    5,
    1,
    3,
    3,
    3
  ]
}
```



## 💡 PREPORUKE (3)

1. Kolona status ima 100.0% NULL vrednosti - razmotriti optimizaciju
2. Kolona batch_id ima 100.0% NULL vrednosti - razmotriti optimizaciju
3. Kolona alternatives ima 100.0% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 16,
  "total_columns": 15,
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
    "grad": {
      "total_values": 16,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "datum": {
      "total_values": 16,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 3,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "zeljeno_vreme": {
      "total_values": 16,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 7,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "dodeljeno_vreme": {
      "total_values": 16,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 7,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "status": {
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
      "unique_values": 16,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "updated_at": {
      "total_values": 16,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 10,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "processed_at": {
      "total_values": 16,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 10,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "priority": {
      "total_values": 16,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 3,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 1.5625,
      "median": 2.0,
      "std": 0.6291528696058958,
      "min": 0.0,
      "max": 2.0
    },
    "batch_id": {
      "total_values": 16,
      "null_values": 16,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "alternatives": {
      "total_values": 16,
      "null_values": 16,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "changes_count": {
      "total_values": 16,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 0.0,
      "median": 0.0,
      "std": 0.0,
      "min": 0.0,
      "max": 0.0
    },
    "broj_mesta": {
      "total_values": 16,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 1.0,
      "median": 1.0,
      "std": 0.0,
      "min": 1.0,
      "max": 1.0
    }
  },
  "data_size_mb": 0.006366729736328125,
  "datum_range": {
    "min": "2026-01-28 00:00:00",
    "max": "2026-01-30 00:00:00",
    "span_days": 2
  },
  "status_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "created_at_range": {
    "min": "2026-01-28 07:55:49.243004+00:00",
    "max": "2026-01-29 20:46:14.385651+00:00",
    "span_days": 1
  },
  "updated_at_range": {
    "min": "2026-01-28 08:00:00.039519+00:00",
    "max": "2026-01-29 20:50:00.049690+00:00",
    "span_days": 1
  },
  "processed_at_range": {
    "min": "2026-01-28 08:00:00.039519+00:00",
    "max": "2026-01-29 20:50:00.049690+00:00",
    "span_days": 1
  },
  "batch_id_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "alternatives_range": {
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
