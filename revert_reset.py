
import json
import logging
from supabase import create_client, Client

# Mocking the process of updating the DB via SQL calls since I don't have the python lib installed usually 
# I will generate the SQL statements instead.

queue_data = [
  {"putnik_id": "4c6cd755-d164-4440-8537-b40dee50fd32", "dan": "uto", "grad": "BC", "vreme": "06:00", "new_status": "confirmed"},
  {"putnik_id": "4c6cd755-d164-4440-8537-b40dee50fd32", "dan": "cet", "grad": "BC", "vreme": "18:00", "new_status": "confirmed"},
  {"putnik_id": "4c6cd755-d164-4440-8537-b40dee50fd32", "dan": "pon", "grad": "BC", "vreme": "06:00", "new_status": "confirmed"},
  {"putnik_id": "4c6cd755-d164-4440-8537-b40dee50fd32", "dan": "sre", "grad": "BC", "vreme": "12:00", "new_status": "confirmed"},
  {"putnik_id": "4c6cd755-d164-4440-8537-b40dee50fd32", "dan": "uto", "grad": "VS", "vreme": "13:00", "new_status": "confirmed"},
  {"putnik_id": "4c6cd755-d164-4440-8537-b40dee50fd32", "dan": "pon", "grad": "VS", "vreme": "13:00", "new_status": "confirmed"},
  {"putnik_id": "4c6cd755-d164-4440-8537-b40dee50fd32", "dan": "sre", "grad": "VS", "vreme": "19:00", "new_status": "confirmed"},
  {"putnik_id": "4c6cd755-d164-4440-8537-b40dee50fd32", "dan": "pet", "grad": "VS", "vreme": "07:00", "new_status": "confirmed"},
  {"putnik_id": "f872c1a5-d8ec-4603-ad7e-638d14791899", "dan": "sre", "grad": "BC", "vreme": "13:00", "new_status": "confirmed"},
  {"putnik_id": "f872c1a5-d8ec-4603-ad7e-638d14791899", "dan": "pon", "grad": "BC", "vreme": "13:00", "new_status": "confirmed"},
  {"putnik_id": "f872c1a5-d8ec-4603-ad7e-638d14791899", "dan": "cet", "grad": "BC", "vreme": "11:00", "new_status": "confirmed"},
  {"putnik_id": "f872c1a5-d8ec-4603-ad7e-638d14791899", "dan": "pon", "grad": "VS", "vreme": "06:00", "new_status": "confirmed"},
  {"putnik_id": "f872c1a5-d8ec-4603-ad7e-638d14791899", "dan": "sre", "grad": "VS", "vreme": "06:00", "new_status": "confirmed"},
  {"putnik_id": "f872c1a5-d8ec-4603-ad7e-638d14791899", "dan": "cet", "grad": "VS", "vreme": "06:00", "new_status": "confirmed"},
  {"putnik_id": "6112e70e-abb4-4996-9ff6-8385c5bbe9f2", "dan": "pon", "grad": "BC", "vreme": "07:00", "new_status": "confirmed"},
  {"putnik_id": "b5298eb7-36ed-449f-8a29-618f5c5f7646", "dan": "cet", "grad": "BC", "vreme": "05:00", "new_status": "confirmed"},
  {"putnik_id": "b5298eb7-36ed-449f-8a29-618f5c5f7646", "dan": "uto", "grad": "BC", "vreme": "05:00", "new_status": "confirmed"},
  {"putnik_id": "b5298eb7-36ed-449f-8a29-618f5c5f7646", "dan": "pon", "grad": "BC", "vreme": "05:00", "new_status": "confirmed"},
  {"putnik_id": "b5298eb7-36ed-449f-8a29-618f5c5f7646", "dan": "sre", "grad": "BC", "vreme": "05:00", "new_status": "confirmed"},
  {"putnik_id": "b5298eb7-36ed-449f-8a29-618f5c5f7646", "dan": "pon", "grad": "VS", "vreme": "14:00", "new_status": "confirmed"},
  {"putnik_id": "b5298eb7-36ed-449f-8a29-618f5c5f7646", "dan": "cet", "grad": "VS", "vreme": "14:00", "new_status": "confirmed"},
  {"putnik_id": "b5298eb7-36ed-449f-8a29-618f5c5f7646", "dan": "uto", "grad": "VS", "vreme": "14:00", "new_status": "confirmed"},
  {"putnik_id": "b5298eb7-36ed-449f-8a29-618f5c5f7646", "dan": "sre", "grad": "VS", "vreme": "14:00", "new_status": "confirmed"},
  {"putnik_id": "8f9217c1-4f31-476c-b70e-0b6ce54904b6", "dan": "uto", "grad": "BC", "vreme": "07:00", "new_status": "confirmed"},
  {"putnik_id": "8f9217c1-4f31-476c-b70e-0b6ce54904b6", "dan": "pon", "grad": "BC", "vreme": "07:00", "new_status": "confirmed"},
  {"putnik_id": "8f9217c1-4f31-476c-b70e-0b6ce54904b6", "dan": "sre", "grad": "BC", "vreme": "07:00", "new_status": "confirmed"},
  {"putnik_id": "8f9217c1-4f31-476c-b70e-0b6ce54904b6", "dan": "cet", "grad": "BC", "vreme": "07:00", "new_status": "confirmed"},
  {"putnik_id": "8f9217c1-4f31-476c-b70e-0b6ce54904b6", "dan": "pet", "grad": "BC", "vreme": "07:00", "new_status": "confirmed"},
  {"putnik_id": "8f9217c1-4f31-476c-b70e-0b6ce54904b6", "dan": "pon", "grad": "VS", "vreme": "15:30", "new_status": "confirmed"},
  {"putnik_id": "8f9217c1-4f31-476c-b70e-0b6ce54904b6", "dan": "uto", "grad": "VS", "vreme": "15:30", "new_status": "confirmed"},
  {"putnik_id": "8f9217c1-4f31-476c-b70e-0b6ce54904b6", "dan": "sre", "grad": "VS", "vreme": "15:30", "new_status": "confirmed"},
  {"putnik_id": "8f9217c1-4f31-476c-b70e-0b6ce54904b6", "dan": "cet", "grad": "VS", "vreme": "15:30", "new_status": "confirmed"},
  {"putnik_id": "8f9217c1-4f31-476c-b70e-0b6ce54904b6", "dan": "pet", "grad": "VS", "vreme": "15:30", "new_status": "confirmed"},
  {"putnik_id": "ca36e58f-9e0c-4e80-be68-d9be98c17b27", "dan": "pon", "grad": "BC", "vreme": "7:00", "new_status": "confirmed"},
  {"putnik_id": "396eabc2-2ce3-4e8b-a1ab-1ba638f90e85", "dan": "pon", "grad": "BC", "vreme": "11:00", "new_status": "confirmed"},
  {"putnik_id": "c8377513-f032-4051-a9ce-d2a4e933ecf4", "dan": "pet", "grad": "BC", "vreme": "12:00", "new_status": "confirmed"},
  {"putnik_id": "c8377513-f032-4051-a9ce-d2a4e933ecf4", "dan": "cet", "grad": "BC", "vreme": "12:00", "new_status": "confirmed"},
  {"putnik_id": "c8377513-f032-4051-a9ce-d2a4e933ecf4", "dan": "sre", "grad": "BC", "vreme": "12:00", "new_status": "confirmed"},
  {"putnik_id": "c8377513-f032-4051-a9ce-d2a4e933ecf4", "dan": "uto", "grad": "BC", "vreme": "12:00", "new_status": "confirmed"},
  {"putnik_id": "c8377513-f032-4051-a9ce-d2a4e933ecf4", "dan": "pon", "grad": "BC", "vreme": "12:00", "new_status": "confirmed"},
  {"putnik_id": "100b8037-7fd5-4bf7-8f28-691b20afa9e0", "dan": "pon", "grad": "BC", "vreme": "07:00", "new_status": "confirmed"},
  {"putnik_id": "7bf57373-0dde-4779-8b47-c496c5e3c8fe", "dan": "sre", "grad": "BC", "vreme": "05:00", "new_status": "confirmed"},
  {"putnik_id": "7bf57373-0dde-4779-8b47-c496c5e3c8fe", "dan": "pon", "grad": "BC", "vreme": "05:00", "new_status": "confirmed"},
  {"putnik_id": "7bf57373-0dde-4779-8b47-c496c5e3c8fe", "dan": "cet", "grad": "BC", "vreme": "05:00", "new_status": "confirmed"},
  {"putnik_id": "7bf57373-0dde-4779-8b47-c496c5e3c8fe", "dan": "sre", "grad": "VS", "vreme": "14:00", "new_status": "confirmed"},
  {"putnik_id": "7bf57373-0dde-4779-8b47-c496c5e3c8fe", "dan": "uto", "grad": "VS", "vreme": "14:00", "new_status": "confirmed"},
  {"putnik_id": "7bf57373-0dde-4779-8b47-c496c5e3c8fe", "dan": "pet", "grad": "VS", "vreme": "14:00", "new_status": "confirmed"},
  {"putnik_id": "de30a48d-60b2-4aba-9271-751850e3b1fd", "dan": "pon", "grad": "BC", "vreme": "05:00", "new_status": "confirmed"},
  {"putnik_id": "de30a48d-60b2-4aba-9271-751850e3b1fd", "dan": "uto", "grad": "BC", "vreme": "05:00", "new_status": "confirmed"},
  {"putnik_id": "de30a48d-60b2-4aba-9271-751850e3b1fd", "dan": "pet", "grad": "BC", "vreme": "05:00", "new_status": "confirmed"},
  {"putnik_id": "de30a48d-60b2-4aba-9271-751850e3b1fd", "dan": "pon", "grad": "VS", "vreme": "13:00", "new_status": "confirmed"},
  {"putnik_id": "de30a48d-60b2-4aba-9271-751850e3b1fd", "dan": "uto", "grad": "VS", "vreme": "13:00", "new_status": "confirmed"},
  {"putnik_id": "de30a48d-60b2-4aba-9271-751850e3b1fd", "dan": "sre", "grad": "BC", "vreme": "05:00", "new_status": "confirmed"},
  {"putnik_id": "de30a48d-60b2-4aba-9271-751850e3b1fd", "dan": "cet", "grad": "BC", "vreme": "05:00", "new_status": "confirmed"},
  {"putnik_id": "933af247-7c7c-4154-a7e6-dc580ab86ad6", "dan": "pon", "grad": "BC", "vreme": "18:00", "new_status": "confirmed"},
  {"putnik_id": "de30a48d-60b2-4aba-9271-751850e3b1fd", "dan": "sre", "grad": "VS", "vreme": "13:00", "new_status": "confirmed"},
  {"putnik_id": "de30a48d-60b2-4aba-9271-751850e3b1fd", "dan": "cet", "grad": "VS", "vreme": "13:00", "new_status": "confirmed"},
  {"putnik_id": "de30a48d-60b2-4aba-9271-751850e3b1fd", "dan": "pet", "grad": "VS", "vreme": "13:00", "new_status": "confirmed"},
  {"putnik_id": "933af247-7c7c-4154-a7e6-dc580ab86ad6", "dan": "pon", "grad": "VS", "vreme": "07:00", "new_status": "confirmed"}
]

# We will group by putnik_id to do fewer updates
grouped = {}
for item in queue_data:
    pid = item["putnik_id"]
    if pid not in grouped:
        grouped[pid] = []
    grouped[pid].append(item)

# For each putnik, we need to generate a SQL update that patches their polasci_po_danu
for pid, changes in grouped.items():
    # Construct a nested jsonb update
    # In Postgres, we can use jsonb_set multiple times or build the whole object
    # But since we don't know the exact current state of other days, 
    # we should probably fetch it first or use jsonb_set
    print(f"-- RESTORING FOR {pid}")
    update_parts = []
    for c in changes:
        grad_key = c["grad"].lower()
        dan_key = c["dan"].lower()
        vreme = c["vreme"]
        status = c["new_status"]
        
        # We need to set both the time and the status marker
        # Marker is usually {grad}_status or just status if it's special
        # Looking at putnik_service logic: dayData['${place}_otkazano'] = true/null
        # For confirmed, it's usually just the presence of the time or a specific flag
        # Wait, let's check what 'confirmed' status looks like in polasci_po_danu
        pass # To be implemented in next step
