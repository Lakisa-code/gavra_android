# Fix empty string vozac_id values in database

# Connect to Supabase and fix empty string vozac_id values
write-host "🔧 Fixing empty string vozac_id values in mesecni_putnici table..."

# This would require direct SQL:
# UPDATE mesecni_putnici SET vozac_id = NULL WHERE vozac_id = '';

write-host "⚠️  Manual SQL needed:"
write-host "UPDATE mesecni_putnici SET vozac_id = NULL WHERE vozac_id = '';"
write-host ""
write-host "Run this in Supabase SQL editor to fix existing empty strings."