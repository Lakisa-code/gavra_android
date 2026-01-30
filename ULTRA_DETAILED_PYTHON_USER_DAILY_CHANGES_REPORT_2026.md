
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: USER_DAILY_CHANGES
## 📅 Datum: 2026-01-29 22:12:28

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `user_daily_changes`
- **Ukupno redova**: 2
- **Ukupno kolona**: 6
- **Veličina podataka**: 0.00 MB


### 📅 Vremenski raspon (datum)
- **Početak**: 2026-01-14 00:00:00
- **Kraj**: 2026-01-14 00:00:00
- **Trajanje dana**: 0


### 📅 Vremenski raspon (last_change_at)
- **Početak**: 2026-01-14 08:02:16.830874+00:00
- **Kraj**: 2026-01-14 10:33:26.650494+00:00
- **Trajanje dana**: 0


### 📅 Vremenski raspon (created_at)
- **Početak**: 2026-01-14 08:02:16.830874+00:00
- **Kraj**: 2026-01-14 10:33:26.650494+00:00
- **Trajanje dana**: 0


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 2 | N/A | N/A | N/A |
| `putnik_id` | str | 0.0% | 2 | N/A | N/A | N/A |
| `datum` | datetime64[us] | 0.0% | 1 | N/A | N/A | N/A |
| `changes_count` | int64 | 0.0% | 1 | 1.00 | 1.00 | 1.00 |
| `last_change_at` | datetime64[us, UTC] | 0.0% | 2 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 2 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "putnik_id",
    "datum",
    "changes_count",
    "last_change_at",
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
    "datetime64[us]",
    "int64",
    "datetime64[us, UTC]"
  ],
  "counts": [
    2,
    1,
    1,
    2
  ]
}
```



## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 2,
  "total_columns": 6,
  "column_analysis": {
    "id": {
      "total_values": 2,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "putnik_id": {
      "total_values": 2,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "datum": {
      "total_values": 2,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "changes_count": {
      "total_values": 2,
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
    },
    "last_change_at": {
      "total_values": 2,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "created_at": {
      "total_values": 2,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    }
  },
  "data_size_mb": 0.00051116943359375,
  "datum_range": {
    "min": "2026-01-14 00:00:00",
    "max": "2026-01-14 00:00:00",
    "span_days": 0
  },
  "last_change_at_range": {
    "min": "2026-01-14 08:02:16.830874+00:00",
    "max": "2026-01-14 10:33:26.650494+00:00",
    "span_days": 0
  },
  "created_at_range": {
    "min": "2026-01-14 08:02:16.830874+00:00",
    "max": "2026-01-14 10:33:26.650494+00:00",
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
