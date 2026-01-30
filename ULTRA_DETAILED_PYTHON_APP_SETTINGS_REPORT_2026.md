
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: APP_SETTINGS
## 📅 Datum: 2026-01-29 22:12:25

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `app_settings`
- **Ukupno redova**: 1
- **Ukupno kolona**: 9
- **Veličina podataka**: 0.00 MB


### 📅 Vremenski raspon (updated_at)
- **Početak**: 2026-01-29 08:07:50.461590+00:00
- **Kraj**: 2026-01-29 08:07:50.461590+00:00
- **Trajanje dana**: 0


### 📅 Vremenski raspon (updated_by)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


### 📅 Vremenski raspon (latest_version)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 1 | N/A | N/A | N/A |
| `updated_at` | datetime64[us, UTC] | 0.0% | 1 | N/A | N/A | N/A |
| `updated_by` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `nav_bar_type` | str | 0.0% | 1 | N/A | N/A | N/A |
| `dnevni_zakazivanje_aktivno` | bool | 0.0% | 1 | 1.00 | 1.00 | 1.00 |
| `min_version` | str | 0.0% | 1 | N/A | N/A | N/A |
| `latest_version` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `store_url_android` | str | 0.0% | 1 | N/A | N/A | N/A |
| `store_url_huawei` | str | 0.0% | 1 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "updated_at",
    "updated_by",
    "nav_bar_type",
    "dnevni_zakazivanje_aktivno",
    "min_version",
    "latest_version",
    "store_url_android",
    "store_url_huawei"
  ],
  "null_percentages": [
    0.0,
    0.0,
    100.0,
    0.0,
    0.0,
    0.0,
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
    "datetime64[us, UTC]",
    "datetime64[s]",
    "bool"
  ],
  "counts": [
    5,
    1,
    2,
    1
  ]
}
```



## 💡 PREPORUKE (2)

1. Kolona updated_by ima 100.0% NULL vrednosti - razmotriti optimizaciju
2. Kolona latest_version ima 100.0% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 1,
  "total_columns": 9,
  "column_analysis": {
    "id": {
      "total_values": 1,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "updated_at": {
      "total_values": 1,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "updated_by": {
      "total_values": 1,
      "null_values": 1,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "nav_bar_type": {
      "total_values": 1,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "dnevni_zakazivanje_aktivno": {
      "total_values": 1,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "bool"
      ],
      "dtype": "bool",
      "mean": 1.0,
      "median": 1.0,
      "std": NaN,
      "min": 1.0,
      "max": 1.0
    },
    "min_version": {
      "total_values": 1,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "latest_version": {
      "total_values": 1,
      "null_values": 1,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "store_url_android": {
      "total_values": 1,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "store_url_huawei": {
      "total_values": 1,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    }
  },
  "data_size_mb": 0.0005159378051757812,
  "updated_at_range": {
    "min": "2026-01-29 08:07:50.461590+00:00",
    "max": "2026-01-29 08:07:50.461590+00:00",
    "span_days": 0
  },
  "updated_by_range": {
    "min": "NaT",
    "max": "NaT",
    "span_days": 0
  },
  "latest_version_range": {
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
