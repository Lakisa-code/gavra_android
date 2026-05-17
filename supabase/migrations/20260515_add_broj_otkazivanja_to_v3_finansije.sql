alter table public.v3_finansije
add column if not exists broj_otkazivanja integer not null default 0;
