
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: FUEL_LOGS
## 📅 Datum: 2026-01-29 22:12:26

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `fuel_logs`
- **Ukupno redova**: 13
- **Ukupno kolona**: 10
- **Veličina podataka**: 0.00 MB


### 📅 Vremenski raspon (created_at)
- **Početak**: 2026-01-14 10:00:00+00:00
- **Kraj**: 2026-01-23 11:30:00+00:00
- **Trajanje dana**: 9


### 📅 Vremenski raspon (metadata)
- **Početak**: NaT
- **Kraj**: NaT
- **Trajanje dana**: 0


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 13 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 46.2% | 7 | N/A | N/A | N/A |
| `type` | str | 0.0% | 3 | N/A | N/A | N/A |
| `liters` | float64 | 30.8% | 5 | 630.89 | 15.50 | 2926.00 |
| `amount` | object | 100.0% | 0 | N/A | N/A | N/A |
| `price` | object | 100.0% | 0 | N/A | N/A | N/A |
| `km` | object | 100.0% | 0 | N/A | N/A | N/A |
| `pump_meter` | float64 | 23.1% | 6 | 119729.30 | 119102.00 | 120009.00 |
| `metadata` | datetime64[s] | 100.0% | 0 | N/A | N/A | N/A |
| `vozilo_uuid` | str | 53.8% | 4 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (2)

### Null Analysis
```json
{
  "columns": [
    "id",
    "created_at",
    "type",
    "liters",
    "amount",
    "price",
    "km",
    "pump_meter",
    "metadata",
    "vozilo_uuid"
  ],
  "null_percentages": [
    0.0,
    46.15384615384615,
    0.0,
    30.76923076923077,
    100.0,
    100.0,
    100.0,
    23.076923076923077,
    100.0,
    53.84615384615385
  ]
}
```

### Dtype Distribution
```json
{
  "dtypes": [
    "str",
    "datetime64[us, UTC]",
    "float64",
    "object",
    "datetime64[s]"
  ],
  "counts": [
    3,
    1,
    2,
    3,
    1
  ]
}
```



## 💡 PREPORUKE (5)

1. Kolona amount ima 100.0% NULL vrednosti - razmotriti optimizaciju
2. Kolona price ima 100.0% NULL vrednosti - razmotriti optimizaciju
3. Kolona km ima 100.0% NULL vrednosti - razmotriti optimizaciju
4. Kolona metadata ima 100.0% NULL vrednosti - razmotriti optimizaciju
5. Kolona vozilo_uuid ima 53.8% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 13,
  "total_columns": 10,
  "column_analysis": {
    "id": {
      "total_values": 13,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 13,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "created_at": {
      "total_values": 13,
      "null_values": 6,
      "null_percentage": 46.15384615384615,
      "unique_values": 7,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "type": {
      "total_values": 13,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 3,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "liters": {
      "total_values": 13,
      "null_values": 4,
      "null_percentage": 30.76923076923077,
      "unique_values": 5,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 630.8888888888889,
      "median": 73.5,
      "std": 1112.0312152143533,
      "min": 15.5,
      "max": 2926.0
    },
    "amount": {
      "total_values": 13,
      "null_values": 13,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "object"
    },
    "price": {
      "total_values": 13,
      "null_values": 13,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "object"
    },
    "km": {
      "total_values": 13,
      "null_values": 13,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "object"
    },
    "pump_meter": {
      "total_values": 13,
      "null_values": 3,
      "null_percentage": 23.076923076923077,
      "unique_values": 6,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 119729.3,
      "median": 119715.0,
      "std": 298.9154655677012,
      "min": 119102.0,
      "max": 120009.0
    },
    "metadata": {
      "total_values": 13,
      "null_values": 13,
      "null_percentage": 100.0,
      "unique_values": 0,
      "data_types": [
        "empty"
      ],
      "dtype": "datetime64[s]"
    },
    "vozilo_uuid": {
      "total_values": 13,
      "null_values": 7,
      "null_percentage": 53.84615384615385,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    }
  },
  "data_size_mb": 0.0038661956787109375,
  "created_at_range": {
    "min": "2026-01-14 10:00:00+00:00",
    "max": "2026-01-23 11:30:00+00:00",
    "span_days": 9
  },
  "metadata_range": {
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
