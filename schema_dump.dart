import 'package:supabase/supabase.dart';

const String supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const String supabaseServiceRoleKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQzNjI5MiwiZXhwIjoyMDYzMDEyMjkyfQ.BrwnYQ6TWGB1BrmwaE0YnhMC5wMlBRdZUs1xv2dY5r4';

void main() async {
  final supabase = SupabaseClient(supabaseUrl, supabaseServiceRoleKey);

  // Get tables
  final tables = await supabase
      .from('information_schema.tables')
      .select('table_schema, table_name')
      .eq('table_schema', 'public');

  print('Tables:');
  for (var table in tables) {
    print('${table['table_schema']}.${table['table_name']}');
  }

  // Get columns
  final columns = await supabase
      .from('information_schema.columns')
      .select('table_schema, table_name, column_name, data_type, is_nullable')
      .eq('table_schema', 'public');

  print('\nColumns:');
  for (var col in columns) {
    print(
        '${col['table_schema']}.${col['table_name']}.${col['column_name']}: ${col['data_type']} ${col['is_nullable'] == 'YES' ? 'NULL' : 'NOT NULL'}');
  }

  // Get RLS policies
  final policies = await supabase.from('pg_policies').select(
      'schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check');

  print('\nRLS Policies:');
  for (var pol in policies) {
    print(
        'Policy: ${pol['policyname']} on ${pol['schemaname']}.${pol['tablename']}');
    print('  Permissive: ${pol['permissive']}');
    print('  Roles: ${pol['roles']}');
    print('  Command: ${pol['cmd']}');
    print('  Qual: ${pol['qual']}');
    print('  With Check: ${pol['with_check']}');
    print('');
  }
}
