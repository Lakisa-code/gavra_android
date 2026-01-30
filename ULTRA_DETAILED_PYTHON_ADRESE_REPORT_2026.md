
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: ADRESE
## 📅 Datum: 2026-01-29 22:12:25

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `adrese`
- **Ukupno redova**: 94
- **Ukupno kolona**: 6
- **Veličina podataka**: 0.03 MB


### 📅 Vremenski raspon (koordinate)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 94 | N/A | N/A | N/A |
| `naziv` | str | 0.0% | 92 | N/A | N/A | N/A |
| `grad` | str | 0.0% | 3 | N/A | N/A | N/A |
| `ulica` | str | 6.4% | 84 | N/A | N/A | N/A |
| `broj` | str | 88.3% | 11 | N/A | N/A | N/A |
| `koordinate` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "naziv",
    "grad",
    "ulica",
    "broj",
    "koordinate"
  ],
  "null_percentages": [
    0.0,
    0.0,
    0.0,
    6.382978723404255,
    88.29787234042553,
    100.0
  ]
}
```

### Dtype Distribution
```json
{
  "dtypes": [
    "str",
    "datetime64[s]"
  ],
  "counts": [
    5,
    1
  ]
}
```



## 💡 PREPORUKE (2)

1. Kolona broj ima 88.3% NULL vrednosti - razmotriti optimizaciju
2. Kolona koordinate ima 100.0% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 94,
  "total_columns": 6,
  "column_analysis": {
    "id": {
      "total_values": 94,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 94,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "naziv": {
      "total_values": 94,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 92,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "grad": {
      "total_values": 94,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 3,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "ulica": {
      "total_values": 94,
      "null_values": 6,
      "null_percentage": 6.382978723404255,
      "unique_values": 84,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "broj": {
      "total_values": 94,
      "null_values": 83,
      "null_percentage": 88.29787234042553,
      "unique_values": 11,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "koordinate": {
      "total_values": 94,
      "null_values": 94,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    }
  },
  "data_size_mb": 0.028609275817871094,
  "koordinate_range": {
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
