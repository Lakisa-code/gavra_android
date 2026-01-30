
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: PAYMENT_REMINDERS_LOG
## 📅 Datum: 2026-01-29 22:12:26

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `payment_reminders_log`
- **Ukupno redova**: 2
- **Ukupno kolona**: 7
- **Veličina podataka**: 0.00 MB


### 📅 Vremenski raspon (reminder_date)
- **Početak**: 2026-01-27 00:00:00
- **Kraj**: 2026-02-05 00:00:00
- **Trajanje dana**: 9


### 📅 Vremenski raspon (total_notifications_sent)
- **Početak**: 1970-01-01 00:00:00.000000003
- **Kraj**: 1970-01-01 00:00:00.000000012
- **Trajanje dana**: 0


### 📅 Vremenski raspon (created_at)
- **Početak**: 2026-01-12 12:33:31.573430+00:00
- **Kraj**: 2026-01-21 08:16:58.098906+00:00
- **Trajanje dana**: 8


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 2 | N/A | N/A | N/A |
| `reminder_date` | datetime64[us] | 0.0% | 2 | N/A | N/A | N/A |
| `reminder_type` | str | 0.0% | 2 | N/A | N/A | N/A |
| `triggered_by` | object | 100.0% | 0 | N/A | N/A | N/A |
| `total_unpaid_passengers` | int64 | 0.0% | 2 | 7.50 | 3.00 | 12.00 |
| `total_notifications_sent` | datetime64[ns] | 0.0% | 2 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 2 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "reminder_date",
    "reminder_type",
    "triggered_by",
    "total_unpaid_passengers",
    "total_notifications_sent",
    "created_at"
  ],
  "null_percentages": [
    0.0,
    0.0,
    0.0,
    100.0,
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
    "object",
    "int64",
    "datetime64[ns]",
    "datetime64[us, UTC]"
  ],
  "counts": [
    2,
    1,
    1,
    1,
    1,
    1
  ]
}
```



## 💡 PREPORUKE (1)

1. Kolona triggered_by ima 100.0% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 2,
  "total_columns": 7,
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
    "reminder_date": {
      "total_values": 2,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "reminder_type": {
      "total_values": 2,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "triggered_by": {
      "total_values": 2,
      "null_values": 2,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "object"
    },
    "total_unpaid_passengers": {
      "total_values": 2,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 7.5,
      "median": 7.5,
      "std": 6.363961030678928,
      "min": 3.0,
      "max": 12.0
    },
    "total_notifications_sent": {
      "total_values": 2,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "datetime64[ns]"
      ],
      "dtype": "datetime64[ns]"
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
  "data_size_mb": 0.0005121231079101562,
  "reminder_date_range": {
    "min": "2026-01-27 00:00:00",
    "max": "2026-02-05 00:00:00",
    "span_days": 9
  },
  "total_notifications_sent_range": {
    "min": "1970-01-01 00:00:00.000000003",
    "max": "1970-01-01 00:00:00.000000012",
    "span_days": 0
  },
  "created_at_range": {
    "min": "2026-01-12 12:33:31.573430+00:00",
    "max": "2026-01-21 08:16:58.098906+00:00",
    "span_days": 8
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
