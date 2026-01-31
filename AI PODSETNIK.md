# 🤖 AI PODSETNIK: MCP Supabase Alati

## ⚠️ VAŽNO: Koristi MCP alate, NE CLI!

**Datum kreiranja:** 31.01.2026
**Ažuriranje:** 31.01.2026 - DIREKTNE KOLONE princip + NAZIVI FAJLOVA

---

## 📁 PRAVILO ZA NAZIVE NOVIH FAJLOVA

**SVI NOVI FAJLOVI MORAJU:**
- ✅ Počinjati sa `GAVRA SAMPION`
- ✅ Koristiti VELIKA SLOVA
- ✅ Biti deskriptivni

**Primeri:**
```
GAVRA SAMPION TEST ADMIN AUDIT LOGS DIRECT COLUMNS.py
GAVRA SAMPION TEST ADMIN AUDIT LOGS DIRECT COLUMNS.sql
GAVRA SAMPION TODO UPDATE.md
GAVRA SAMPION DATABASE SCHEMA CHECK.py
```

**Stari fajlovi:** Ostaju nepromenjeni za reference

---

## 🎯 ARHITEKTURSKI PRINCIP: DIREKTNE KOLONE vs JSONB

### ✅ KORISTIMO DIREKTNE KOLONE ZA CEO PROJEKAT:
- **inventory_liters** → DECIMAL kolona
- **total_debt** → DECIMAL kolona  
- **severity** → VARCHAR(20) kolona
- **metadata** → JSONB samo za dodatne/dinamičke podatke

### ❌ JSONB METADATA samo kada:
- Podaci se menjaju po akciji
- Ne-kritične informacije
- Retko upitovani podaci

### 📊 PREDNOSTI DIREKTNIH KOLONA:
- Brži upiti bez JSON parsing
- Bolje indeksiranje
- Tip sigurnost (DECIMAL vs string)
- Lakši SQL upiti
- Skripta validacija ✅ OK

---

## ✅ DOSTUPNI MCP SUPABASE ALATI

### 1. `mcp_supabase_list_tables`
- **Šta radi:** Lista sve tabele u public šemi
- **Primer:** Dobija listu tabela u bazi
- **Zamena za:** `supabase db describe`

### 2. `mcp_supabase_describe_table`
- **Šta radi:** Detaljan opis kolona u tabeli
- **Parametri:** `table_name` (obavezno)
- **Primer:** `mcp_supabase_describe_table(table_name="admin_audit_logs")`
- **Zamena za:** `supabase db describe table_name`

### 3. `mcp_supabase_execute_sql`
- **Šta radi:** Izvršava SQL upite (SELECT, INSERT, UPDATE, DELETE)
- **Parametri:** `query` (obavezno)
- **Primer:** `mcp_supabase_execute_sql(query="SELECT * FROM users;")`
- **Zamena za:** `supabase sql` ili `psql` konekcije

### 4. `mcp_supabase_add_column`
- **Šta radi:** Daje SQL komandu za dodavanje kolone
- **Parametri:** `table_name`, `column_name`, `column_type`
- **Primer:** `mcp_supabase_add_column(table_name="users", column_name="age", column_type="INTEGER")`
- **Zamena za:** Manuelno pisanje ALTER TABLE

---

## ❌ ŠTA NE RADITI

- ~~`supabase db reset`~~ → Koristi MCP execute_sql za DDL operacije
- ~~`supabase sql`~~ → Koristi `mcp_supabase_execute_sql`
- ~~`supabase db describe`~~ → Koristi `mcp_supabase_describe_table`
- ~~Terminal psql komande~~ → Koristi MCP alate

---

## 🔄 KADA KORISTITI MCP VS TERMINAL

### MCP Alati (PREFERIRANO):
- Čitanje podataka (SELECT)
- Pisanje podataka (INSERT/UPDATE/DELETE)
- Opisivanje šeme (describe table)
- Jednostavne DDL operacije

### Terminal (SAMO AKO MORA):
- Kompleksne migracije
- Bulk import/export
- Sistemska administracija

---

## 📝 MEMO ZA BUDUĆNOST

**31.01.2026:** Supabase CLI obrisan, MCP alati aktivni i testirani.
**Razlog:** Bolja kontrola i integracija sa AI asistentom.

**Testirano:**
- ✅ list_tables
- ✅ describe_table (9 kolona u admin_audit_logs)
- ✅ execute_sql (SELECT upiti)
- ✅ add_column (daje SQL komande)

---

## 🚨 HITAN SLUČAJ

Ako MCP alati ne rade, prvo proveri konekciju i dozvole, zatim koristi terminal kao fallback.</content>
<parameter name="filePath">c:\Users\Bojan\gavra_android\AI PODSETNIK.md