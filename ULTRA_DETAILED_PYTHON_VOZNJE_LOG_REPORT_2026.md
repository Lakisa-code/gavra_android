
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: VOZNJE_LOG
## 📅 Datum: 2026-01-29 22:12:29

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `voznje_log`
- **Ukupno redova**: 1,000
- **Ukupno kolona**: 13
- **Veličina podataka**: 0.48 MB


### 📅 Vremenski raspon (datum)
- **Početak**: 2026-01-10 00:00:00
- **Kraj**: 2026-01-29 00:00:00
- **Trajanje dana**: 19


### 📅 Vremenski raspon (created_at)
- **Početak**: 2026-01-10 04:41:20.182863+00:00
- **Kraj**: 2026-01-29 21:00:00.044830+00:00
- **Trajanje dana**: 19


### 📅 Vremenski raspon (sati_pre_polaska)
- **Početak**: 1970-01-01 00:00:00
- **Kraj**: 1970-01-01 00:00:00.000000023
- **Trajanje dana**: 0


## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
| `id` | str | 0.0% | 1,000 | N/A | N/A | N/A |
| `putnik_id` | str | 0.3% | 130 | N/A | N/A | N/A |
| `datum` | datetime64[us] | 0.0% | 10 | N/A | N/A | N/A |
| `tip` | str | 0.0% | 10 | N/A | N/A | N/A |
| `iznos` | float64 | 0.0% | 10 | 77.10 | 0.00 | 12000.00 |
| `vozac_id` | str | 46.6% | 4 | N/A | N/A | N/A |
| `created_at` | datetime64[us, UTC] | 0.0% | 887 | N/A | N/A | N/A |
| `placeni_mesec` | float64 | 51.5% | 2 | 1.00 | 1.00 | 2.00 |
| `placena_godina` | float64 | 51.5% | 1 | 2026.00 | 2026.00 | 2026.00 |
| `sati_pre_polaska` | datetime64[ns] | 95.6% | 12 | N/A | N/A | N/A |
| `broj_mesta` | int64 | 0.0% | 1 | 1.00 | 1.00 | 1.00 |
| `detalji` | str | 78.3% | 110 | N/A | N/A | N/A |
| `meta` | object | 53.2% | 87 | N/A | N/A | N/A |


## 📊 VIZUELIZACIJE (4)

### Null Analysis
```json
{
  "columns": [
    "id",
    "putnik_id",
    "datum",
    "tip",
    "iznos",
    "vozac_id",
    "created_at",
    "placeni_mesec",
    "placena_godina",
    "sati_pre_polaska",
    "broj_mesta",
    "detalji",
    "meta"
  ],
  "null_percentages": [
    0.0,
    0.3,
    0.0,
    0.0,
    0.0,
    46.6,
    0.0,
    51.5,
    51.5,
    95.6,
    0.0,
    78.3,
    53.2
  ]
}
```

### Dtype Distribution
```json
{
  "dtypes": [
    "str",
    "datetime64[us]",
    "float64",
    "datetime64[us, UTC]",
    "datetime64[ns]",
    "int64",
    "object"
  ],
  "counts": [
    5,
    1,
    3,
    1,
    1,
    1,
    1
  ]
}
```

### Ride Types
```json
{
  "types": [
    "voznja",
    "prijava",
    "potvrda_zakazivanja",
    "zakazivanje_putnika",
    "otkazivanje",
    "otkazivanje_putnika",
    "uplata_dnevna",
    "uplata_mesecna",
    "greska_zahteva",
    "admin_akcija"
  ],
  "counts": [
    470,
    230,
    110,
    54,
    45,
    39,
    20,
    18,
    11,
    3
  ]
}
```

### Amount Distribution
```json
{
  "ranges": [
    "Negative",
    "0-100",
    "100-200",
    "200-500",
    "500-1000",
    "1000+"
  ],
  "counts": [
    962,
    1,
    0,
    3,
    24,
    10
  ]
}
```



## 💡 PREPORUKE (5)

1. Kolona placeni_mesec ima 51.5% NULL vrednosti - razmotriti optimizaciju
2. Kolona placena_godina ima 51.5% NULL vrednosti - razmotriti optimizaciju
3. Kolona sati_pre_polaska ima 95.6% NULL vrednosti - razmotriti optimizaciju
4. Kolona detalji ima 78.3% NULL vrednosti - razmotriti optimizaciju
5. Kolona meta ima 53.2% NULL vrednosti - razmotriti optimizaciju


## 📊 DETALJNA STATISTIKA

```json
{
  "total_rows": 1000,
  "total_columns": 13,
  "column_analysis": {
    "id": {
      "total_values": 1000,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 1000,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "putnik_id": {
      "total_values": 1000,
      "null_values": 3,
      "null_percentage": 0.3,
      "unique_values": 130,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "datum": {
      "total_values": 1000,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 10,
      "data_types": [
        "datetime64[us]"
      ],
      "dtype": "datetime64[us]"
    },
    "tip": {
      "total_values": 1000,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 10,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "iznos": {
      "total_values": 1000,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 10,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 77.097,
      "median": 0.0,
      "std": 754.9936933962218,
      "min": 0.0,
      "max": 12000.0
    },
    "vozac_id": {
      "total_values": 1000,
      "null_values": 466,
      "null_percentage": 46.6,
      "unique_values": 4,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "created_at": {
      "total_values": 1000,
      "null_values": 0,
      "null_percentage": 0.0,
      "unique_values": 887,
      "data_types": [
        "datetime64[us, UTC]"
      ],
      "dtype": "datetime64[us, UTC]"
    },
    "placeni_mesec": {
      "total_values": 1000,
      "null_values": 515,
      "null_percentage": 51.5,
      "unique_values": 2,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 1.002061855670103,
      "median": 1.0,
      "std": 0.04540766091864998,
      "min": 1.0,
      "max": 2.0
    },
    "placena_godina": {
      "total_values": 1000,
      "null_values": 515,
      "null_percentage": 51.5,
      "unique_values": 1,
      "data_types": [
        "float64"
      ],
      "dtype": "float64",
      "mean": 2026.0,
      "median": 2026.0,
      "std": 0.0,
      "min": 2026.0,
      "max": 2026.0
    },
    "sati_pre_polaska": {
      "total_values": 1000,
      "null_values": 956,
      "null_percentage": 95.6,
      "unique_values": 12,
      "data_types": [
        "datetime64[ns]"
      ],
      "dtype": "datetime64[ns]"
    },
    "broj_mesta": {
      "total_values": 1000,
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
    "detalji": {
      "total_values": 1000,
      "null_values": 783,
      "null_percentage": 78.3,
      "unique_values": 110,
      "data_types": [
        "str"
      ],
      "dtype": "str"
    },
    "meta": {
      "total_values": 1000,
      "null_values": 532,
      "null_percentage": 53.2,
      "unique_values": 87,
      "data_types": [
        "object"
      ],
      "dtype": "object"
    }
  },
  "data_size_mb": 0.4819612503051758,
  "datum_range": {
    "min": "2026-01-10 00:00:00",
    "max": "2026-01-29 00:00:00",
    "span_days": 19
  },
  "created_at_range": {
    "min": "2026-01-10 04:41:20.182863+00:00",
    "max": "2026-01-29 21:00:00.044830+00:00",
    "span_days": 19
  },
  "sati_pre_polaska_range": {
    "min": "1970-01-01 00:00:00",
    "max": "1970-01-01 00:00:00.000000023",
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
