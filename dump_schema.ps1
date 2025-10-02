# Script to dump Supabase database schema using psql queries
# Uses provided password

$pw = 'FlqfvHczUpSytgrV'
$env:PGPASSWORD = $pw

$conn = "postgresql://postgres.gjtabtwudbrmfeyjiicu@aws-0-eu-central-1.pooler.supabase.com:6543/postgres?sslmode=require"

# Dump tables
psql $conn -c "SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;" -t > tables.txt

# Dump columns
psql $conn -c "SELECT table_schema, table_name, column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema = 'public' ORDER BY table_name, ordinal_position;" -t > columns.txt

# Dump RLS policies
psql $conn -c "SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check FROM pg_policies ORDER BY schemaname, tablename, policyname;" -t > rls_policies.txt

# Clean up
Remove-Item Env:PGPASSWORD

Write-Host "Schema dumped to tables.txt, columns.txt, and rls_policies.txt"