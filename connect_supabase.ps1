# Temporary script to connect to Supabase database
# Reads password from external file, sets env var, runs psql, cleans up

$pw = (Get-Content -Raw 'C:\Users\Bojan\Desktop\GAVRA013\supabase.txt').Trim()
$env:PGPASSWORD = $pw

# Connect to database interactively
psql "postgresql://postgres.gjtabtwudbrmfeyjiicu@aws-0-eu-central-1.pooler.supabase.com:6543/postgres?sslmode=require" -U postgres.gjtabtwudbrmfeyjiicu

# Clean up
Remove-Item Env:PGPASSWORD