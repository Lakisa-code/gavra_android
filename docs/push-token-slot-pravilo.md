# Push Token Slot Pravilo (V3)

## Cilj

Po jednom nalogu dozvoljena su **najviše 2 uređaja**.

To znači:

- `installation_id` + `push_token` = **slot 1**
- `installation_id_2` + `push_token_2` = **slot 2**

## Obavezna pravila

1. Maksimalno 2 uređaja po nalogu.
2. Svaki uređaj mora imati stabilan `installation_id`.
3. Push token se uvek upisuje u slot koji odgovara tom `installation_id`.
4. Ako je uređaj već poznat (`installation_id` postoji), update ide u isti slot.
5. Ako su oba slota zauzeta drugim uređajima, novi treći uređaj se odbija.

## Slot mapiranje

- Ako `incoming_installation_id == installation_id` → upis u `push_token`.
- Ako `incoming_installation_id == installation_id_2` → upis u `push_token_2`.
- Ako `installation_id` prazno → dodeli slot 1 (`installation_id`, `push_token`).
- Ako `installation_id_2` prazno → dodeli slot 2 (`installation_id_2`, `push_token_2`).
- Ako su oba popunjena i ne poklapaju se → `device_limit_reached`.

## Važna napomena

- `push_token_2` je **drugi slot uređaja**, ne posebna platformska kolona.
- Ne menjati semantiku kolona bez migracije i dogovora.

## Primer toka

1. Prvi login sa uređaja A:
   - upisuje `installation_id=A`, `push_token=tokenA`.
2. Login sa uređaja B:
   - upisuje `installation_id_2=B`, `push_token_2=tokenB`.
3. Refresh tokena na uređaju A:
   - menja samo `push_token` (slot 1), slot 2 ostaje netaknut.

## Šta ne raditi

- Ne tretirati `push_token_2` kao APNs-only polje.
- Ne prepisivati slot 1 podacima slota 2 (i obrnuto).
- Ne uvoditi treći uređaj bez eksplicitne promene pravila i šeme.
