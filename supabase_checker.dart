import 'dart:convert';
import 'package:http/http.dart' as http;

class SupabaseChecker {
  final String url = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
  final String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

  Future<List<dynamic>> getTableData(String tableName, {int limit = 10}) async {
    final response = await http.get(
      Uri.parse('$url/rest/v1/$tableName?limit=$limit'),
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<List<dynamic>> getColumnData(String tableName, String columnName, {int limit = 10}) async {
    final response = await http.get(
      Uri.parse('$url/rest/v1/$tableName?select=$columnName&limit=$limit'),
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<List<dynamic>> queryTable(String tableName, String select, {String? filter, int limit = 10}) async {
    String urlPath = '$url/rest/v1/$tableName?select=$select&limit=$limit';
    if (filter != null) {
      urlPath += '&$filter';
    }

    final response = await http.get(
      Uri.parse(urlPath),
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getTableSchema(String tableName) async {
    final response = await http.get(
      Uri.parse('$url/rest/v1/$tableName?limit=1'),
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.isNotEmpty) {
        return data[0] as Map<String, dynamic>;
      }
      return {};
    } else {
      throw Exception('Error: ${response.statusCode} - ${response.body}');
    }
  }
}

void main() async {
  final checker = SupabaseChecker();
  
  // Primer upita - možeš da menjaš ovo
  try {
    print('Provera Supabase baze...\n');
    
    // Dobavi sve tabele (potreban je service role key za ovu operaciju)
    // Umesto toga, probaj sa konkretnom tabelom
    print('Unesi ime tabele za proveru:');
    final tableName = 'users'; // Promeni ovo
    
    print('\nPodaci iz tabele $tableName:');
    final data = await checker.getTableData(tableName);
    print(data);
    
  } catch (e) {
    print('Greška: $e');
  }
}
