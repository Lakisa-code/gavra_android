
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: WEATHER_ALERTS_LOG
## 📅 Datum: 2026-01-29 22:12:30

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `weather_alerts_log`
- **Ukupno redova**: 8
- **Ukupno kolona**: 4
- **Veličina podataka**: 0.00 MB


### 📅 Vremenski raspon (alert_date)
- **Početak**: 2026-01-09 00:00:00
- **Kraj**: 2026-01-26 00:00:00
- **Trajanje dana**: 17


### 📅 Vremenski raspon (created_at)
- **Početak**: 2026-01-09 17:59:01.945928+00:00
- **Kraj**: 2026-01-23 02:56:35.710551+00:00
- **Trajanje dana**: 13


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 8 | N/A | N/A | N/A |
| `alert_date` | datetime64[us] | 0.0% | 8 | N/A | N/A | N/A |
| `alert_types` | str | 0.0% | 4 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 8 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "alert_date",
    "alert_types",
    "created_at"
  ],
  "null_percentages": [
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
    "datetime64[us, UTC]"
  ],
  "counts": [
    2,
    1,
    1
  ]
}
```



## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 8,
  "total_columns": 4,
  "column_analysis": {
    "id": {
      "total_values": 8,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 8,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "alert_date": {
      "total_values": 8,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 8,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "alert_types": {
      "total_values": 8,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "created_at": {
      "total_values": 8,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 8,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    }
  },
  "data_size_mb": 0.0023193359375,
  "alert_date_range": {
    "min": "2026-01-09 00:00:00",
    "max": "2026-01-26 00:00:00",
    "span_days": 17
  },
  "created_at_range": {
    "min": "2026-01-09 17:59:01.945928+00:00",
    "max": "2026-01-23 02:56:35.710551+00:00",
    "span_days": 13
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
