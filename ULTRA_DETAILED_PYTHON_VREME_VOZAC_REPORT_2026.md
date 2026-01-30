
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: VREME_VOZAC
## 📅 Datum: 2026-01-29 22:12:30

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `vreme_vozac`
- **Ukupno redova**: 68
- **Ukupno kolona**: 7
- **Veličina podataka**: 0.02 MB


### 📅 Vremenski raspon (created_at)
- **Početak**: 2026-01-12 00:20:18.357818+00:00
- **Kraj**: 2026-01-29 20:45:00.858183+00:00
- **Trajanje dana**: 17


### 📅 Vremenski raspon (updated_at)
- **Početak**: 2026-01-12 01:20:18.328383+00:00
- **Kraj**: 2026-01-29 20:45:01.821431+00:00
- **Trajanje dana**: 17


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 68 | N/A | N/A | N/A |
| `grad` | str | 0.0% | 2 | N/A | N/A | N/A |
| `vreme` | str | 0.0% | 18 | N/A | N/A | N/A |
| `dan` | str | 0.0% | 5 | N/A | N/A | N/A |
| `vozac_ime` | str | 0.0% | 4 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 68 | N/A | N/A | N/A |
| `updated_at` | datetime64[us, UTC] | 0.0% | 68 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "grad",
    "vreme",
    "dan",
    "vozac_ime",
    "created_at",
    "updated_at"
  ],
  "null_percentages": [
    0.0,
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
    "datetime64[us, UTC]"
  ],
  "counts": [
    5,
    2
  ]
}
```



## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 68,
  "total_columns": 7,
  "column_analysis": {
    "id": {
      "total_values": 68,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 68,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "grad": {
      "total_values": 68,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "vreme": {
      "total_values": 68,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 18,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "dan": {
      "total_values": 68,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 5,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "vozac_ime": {
      "total_values": 68,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "created_at": {
      "total_values": 68,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 68,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "updated_at": {
      "total_values": 68,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 68,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    }
  },
  "data_size_mb": 0.021704673767089844,
  "created_at_range": {
    "min": "2026-01-12 00:20:18.357818+00:00",
    "max": "2026-01-29 20:45:00.858183+00:00",
    "span_days": 17
  },
  "updated_at_range": {
    "min": "2026-01-12 01:20:18.328383+00:00",
    "max": "2026-01-29 20:45:01.821431+00:00",
    "span_days": 17
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
