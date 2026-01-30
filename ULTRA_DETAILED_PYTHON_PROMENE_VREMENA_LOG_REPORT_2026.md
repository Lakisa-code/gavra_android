
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: PROMENE_VREMENA_LOG
## 📅 Datum: 2026-01-29 22:12:27

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `promene_vremena_log`
- **Ukupno redova**: 57
- **Ukupno kolona**: 7
- **Veličina podataka**: 0.01 MB


### 📅 Vremenski raspon (datum)
- **Početak**: 2025-12-13 00:00:00
- **Kraj**: 2026-01-25 00:00:00
- **Trajanje dana**: 43


### 📅 Vremenski raspon (created_at)
- **Početak**: 2025-12-13 01:19:32.592661+00:00
- **Kraj**: 2026-01-25 11:57:53.054284+00:00
- **Trajanje dana**: 43


### 📅 Vremenski raspon (datum_polaska)
- **Početak**: 2026-01-12 00:00:00
- **Kraj**: 2026-01-26 00:00:00
- **Trajanje dana**: 14


### 📅 Vremenski raspon (sati_unapred)
- **Početak**: 1970-01-01 00:00:00
- **Kraj**: 1970-01-01 00:00:00.000000129
- **Trajanje dana**: 0


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 57 | N/A | N/A | N/A |
| `putnik_id` | str | 0.0% | 13 | N/A | N/A | N/A |
| `datum` | datetime64[us] | 0.0% | 15 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 57 | N/A | N/A | N/A |
| `ciljni_dan` | str | 0.0% | 5 | N/A | N/A | N/A |
| `datum_polaska` | datetime64[us] | 14.0% | 10 | N/A | N/A | N/A |
| `sati_unapred` | datetime64[ns] | 0.0% | 17 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "putnik_id",
    "datum",
    "created_at",
    "ciljni_dan",
    "datum_polaska",
    "sati_unapred"
  ],
  "null_percentages": [
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    14.035087719298245,
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
    "datetime64[us, UTC]",
    "datetime64[ns]"
  ],
  "counts": [
    3,
    2,
    1,
    1
  ]
}
```



## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 57,
  "total_columns": 7,
  "column_analysis": {
    "id": {
      "total_values": 57,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 57,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "putnik_id": {
      "total_values": 57,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 13,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "datum": {
      "total_values": 57,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 15,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "created_at": {
      "total_values": 57,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 57,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "ciljni_dan": {
      "total_values": 57,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 5,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "datum_polaska": {
      "total_values": 57,
      "null_values": 8,
      "null_percentage": 14.035087719298245,
      "unique_values": 10,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "sati_unapred": {
      "total_values": 57,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 17,
      "data_types": [
        "datetime64[ns]"
      ],
      "dtype": "datetime64[ns]"
    }
  },
  "data_size_mb": 0.013933181762695312,
  "datum_range": {
    "min": "2025-12-13 00:00:00",
    "max": "2026-01-25 00:00:00",
    "span_days": 43
  },
  "created_at_range": {
    "min": "2025-12-13 01:19:32.592661+00:00",
    "max": "2026-01-25 11:57:53.054284+00:00",
    "span_days": 43
  },
  "datum_polaska_range": {
    "min": "2026-01-12 00:00:00",
    "max": "2026-01-26 00:00:00",
    "span_days": 14
  },
  "sati_unapred_range": {
    "min": "1970-01-01 00:00:00",
    "max": "1970-01-01 00:00:00.000000129",
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
