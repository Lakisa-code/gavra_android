# SISTEMSKI TIMEOUT BUG - MASOVNA REPARACIJA

## Problem
19+ putnika ima VS smene SAS NULL `vs_adresa_danas` u `polasci_po_danu`.
Ovo je rezultat geocoding timeout-a u sistema koji briše VS smene sa null adresama.

## Rješenje
Ažuriranje `polasci_po_danu` sa `vs_adresa_danas` iz `registrovani_putnici.adresa_vrsac_id` reference.

## SQL UPDATE Statements

### Putnik 1: Predic Djordje
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Bolnica"'), 
            '{sre,vs_adresa_danas}', '"Bolnica"')
WHERE id = '6ef369a3-037f-406e-aebb-e276fd1d2483'
RETURNING putnik_ime, polasci_po_danu->>'cet' as cet, polasci_po_danu->>'sre' as sre;
```

### Putnik 2: Dusica Mojsilov
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Helvecija"'), 
            '{sre,vs_adresa_danas}', '"Helvecija"')
WHERE id = 'af283386-50f9-40b2-802d-f53ca4eabef1';
```

### Putnik 3: Josipa Mancu
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Bolnica"'), 
            '{sre,vs_adresa_danas}', '"Bolnica"')
WHERE id = '2cf33687-f914-4dbb-99c2-6af515cf9bb0';
```

### Putnik 4: Beker Dragana (samo SRE ima VS)
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = jsonb_set(polasci_po_danu, '{sre,vs_adresa_danas}', '"Bolnica"')
WHERE id = '4c6cd755-d164-4440-8537-b40dee50fd32';
```

### Putnik 5: Boba Borislava
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Psihijatrija"'), 
            '{sre,vs_adresa_danas}', '"Psihijatrija"')
WHERE id = '4ad9b63b-48f1-4fda-ab78-120331d9a497';
```

### Putnik 6: Nikola Vojnović
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Bolnica"'), 
            '{sre,vs_adresa_danas}', '"Bolnica"')
WHERE id = '1a64d59c-6ae4-45b1-9950-6b1872ab55f8';
```

### Putnik 7: Ana Cortan
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Fresenius"'), 
            '{sre,vs_adresa_danas}', '"Fresenius"')
WHERE id = 'ccb806e2-1208-4358-a235-ab046df7a7aa';
```

### Putnik 8: Nesa Carea (samo SRE ima null)
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = jsonb_set(polasci_po_danu, '{sre,vs_adresa_danas}', '"Hemofarm"')
WHERE id = 'd6a16f1a-6213-497b-954b-1d1f33117ff6';
```

### Putnik 9: Maja Stojanovic (samo SRE ima VS)
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = jsonb_set(polasci_po_danu, '{sre,vs_adresa_danas}', '"Zive Jovanovica 29"')
WHERE id = '09b12b1e-a202-4b0a-9318-d8d86f19635d';
```

### Putnik 10: Saška notar
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Notar Sinzar"'), 
            '{sre,vs_adresa_danas}', '"Notar Sinzar"')
WHERE id = 'd7ed7e10-58a3-4e04-b8c7-4e46af34530f';
```

### Putnik 11: Marin (samo SRE)
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = jsonb_set(polasci_po_danu, '{sre,vs_adresa_danas}', '"Psihijatrija"')
WHERE id = 'af1bc58a-b9eb-408b-9786-946cd5ca9f6d';
```

### Putnik 12: Dr Perisic Ljiljana
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Karpatska 34"'), 
            '{sre,vs_adresa_danas}', '"Karpatska 34"')
WHERE id = 'a48071ba-b70a-444f-b7fb-9744d83c7688';
```

### Putnik 13: Radovan Jezdic
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Jasenovo skola"'), 
            '{sre,vs_adresa_danas}', '"Jasenovo skola"')
WHERE id = 'a56eeae5-5a49-41a4-af0e-687cfaf43411';
```

### Putnik 14: Djordje Janikic
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Hemofarm"'), 
            '{sre,vs_adresa_danas}', '"Hemofarm"')
WHERE id = 'b5298eb7-36ed-449f-8a29-618f5c5f7646';
```

### Putnik 15: Dragana Mitrovic
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Bolnica"'), 
            '{sre,vs_adresa_danas}', '"Bolnica"')
WHERE id = '224e5bb7-0fe8-4ed3-aadc-7213e5c4ee7d';
```

### Putnik 16: Marinkovic Jasmina
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Zitobanat"'), 
            '{sre,vs_adresa_danas}', '"Zitobanat"')
WHERE id = 'cf081326-df86-489d-a746-b0defd2859b0';
```

### Putnik 17: Sara Gmijovic
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Prima pumpa"'), 
            '{sre,vs_adresa_danas}', '"Prima pumpa"')
WHERE id = 'bb1a777d-24fa-4d56-99e0-484b148267eb';
```

### Putnik 18: Marusa
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Bolnica"'), 
            '{sre,vs_adresa_danas}', '"Bolnica"')
WHERE id = '1eb7f4b9-7677-49f4-a0e7-10c2b5078a23';
```

### Putnik 19: Ljilja Rakićević
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Jat akademija"'), 
            '{sre,vs_adresa_danas}', '"Jat akademija"')
WHERE id = '8f9217c1-4f31-476c-b70e-0b6ce54904b6';
```

### Putnik 20: David (pilic)
```sql
UPDATE registrovani_putnici
SET polasci_po_danu = 
  jsonb_set(jsonb_set(polasci_po_danu, '{cet,vs_adresa_danas}', '"Mesara Srpko"'), 
            '{sre,vs_adresa_danas}', '"Mesara Srpko"')
WHERE id = '0466f1d0-7c59-4513-be2d-8a45538cf5d1';
```

---

## Status: WAITING FOR EXECUTION
Trebam potvrdu pre nego što izvršim ove updatove na svim 20 putnika.
