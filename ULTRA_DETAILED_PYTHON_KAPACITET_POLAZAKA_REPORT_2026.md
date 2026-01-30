
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: KAPACITET_POLAZAKA
## 📅 Datum: 2026-01-29 22:12:26

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `kapacitet_polazaka`
- **Ukupno redova**: 25
- **Ukupno kolona**: 6
- **Veličina podataka**: 0.01 MB


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 25 | N/A | N/A | N/A |
| `grad` | str | 0.0% | 2 | N/A | N/A | N/A |
| `vreme` | str | 0.0% | 17 | N/A | N/A | N/A |
| `max_mesta` | int64 | 0.0% | 6 | 10.56 | 8.00 | 20.00 |
| `aktivan` | bool | 0.0% | 1 | 1.00 | 1.00 | 1.00 |
| `napomena` | object | 100.0% | 0 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "grad",
    "vreme",
    "max_mesta",
    "aktivan",
    "napomena"
  ],
  "null_percentages": [
    0.0,
    0.0,
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
    "int64",
    "bool",
    "object"
  ],
  "counts": [
    3,
    1,
    1,
    1
  ]
}
```



## 💡 PREPORUKE (1)

1. Kolona napomena ima 100.0% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 25,
  "total_columns": 6,
  "column_analysis": {
    "id": {
      "total_values": 25,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 25,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "grad": {
      "total_values": 25,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 2,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "vreme": {
      "total_values": 25,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 17,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "max_mesta": {
      "total_values": 25,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 6,
      "data_types": [
        "int64"
      ],
      "dtype": "int64",
      "mean": 10.56,
      "median": 8.0,
      "std": 4.223742416388575,
      "min": 8.0,
      "max": 20.0
    },
    "aktivan": {
      "total_values": 25,
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
    "napomena": {
      "total_values": 25,
      "null_values": 25,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "object"
    }
  },
  "data_size_mb": 0.005440711975097656
}
```

---

## ✅ ZAKLJUČAK

**Status**: ✅ ISPRAVNO

**Vizuelizacije**: ✅ GENERISANE

**Preporučeno**: ✅ SPREMNO ZA PRODUKCIJU

---
*Generisano Ultra Detailed Python Analyzer v2.0*
