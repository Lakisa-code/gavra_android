// Test script for canceling passengers using pure Dart + Supabase REST API
// Usage:
//  dart run test_cancel_passenger_dart.dart
// You can override credentials with environment variables:
//  TEST_DRIVER_EMAIL and TEST_DRIVER_PASSWORD

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const String supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

Future<void> main() async {
  final email = Platform.environment['TEST_DRIVER_EMAIL'] ?? 'test@example.com';
  final password = Platform.environment['TEST_DRIVER_PASSWORD'] ?? 'testpassword';

  print('🚀 Starting passenger cancel test...');
  print('📧 Using email: $email');

  try {
    // Optionally use the service-role key for authorization (local-only):
    final useServiceRole = Platform.environment['USE_SUPABASE_SERVICE_ROLE'] == 'true';
    final serviceRoleKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
    final token = (useServiceRole && serviceRoleKey != null && serviceRoleKey.isNotEmpty)
        ? serviceRoleKey
        : await signIn(email, password);
    if (token == null) {
      print('❌ Auth failed');
      return;
    }
    print('✅ Signed in successfully');

    const testPassengerId = '37219393-d1ab-4787-b35f-bf1a4314da33'; // Djordje (putovanja_istorija row)
    print('🎯 Canceling passenger with ID: $testPassengerId');

    final passenger = await fetchPassenger(testPassengerId, token);
    if (passenger == null) {
      print('❌ Passenger not found');
      return;
    }
    print('📋 Passenger data: $passenger');

    // Insert cancelled action into action_log and set cancelled_by
    Map<String, dynamic> actionLog = passenger['action_log'] is Map
        ? Map<String, dynamic>.from(passenger['action_log'])
        : (passenger['action_log'] != null
            ? Map<String, dynamic>.from(passenger['action_log'] as Map)
            : {'actions': []});
    actionLog['actions'] = actionLog['actions'] ?? [];
    final nowIso = DateTime.now().toIso8601String();
    final driverUuid = await getUserIdFromToken(token);
    actionLog['actions'].add({
      'type': 'cancelled',
      'vozac_id': driverUuid,
      'timestamp': nowIso,
      'note': 'Otkazano',
    });
    actionLog['cancelled_by'] = driverUuid;

    final success = await updatePassengerStatusWithActionLog(testPassengerId, 'otkazan', actionLog, token);
    if (success) {
      print('✅ Passenger canceled successfully!');
    } else {
      print('❌ Failed to cancel passenger');
    }
  } catch (e) {
    print('❌ Test failed: $e');
  }
}

Future<String?> signIn(String email, String password) async {
  final uri = Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password');
  final headers = {
    'apikey': supabaseAnonKey,
    'Content-Type': 'application/json',
  };
  final body = jsonEncode({'email': email, 'password': password});
  final r = await http.post(uri, headers: headers, body: body);
  if (r.statusCode != 200) {
    print('Auth failed: ${r.statusCode} ${r.body}');
    return null;
  }
  final map = jsonDecode(r.body) as Map<String, dynamic>;
  final token = map['access_token'] as String?;
  return token;
}

Future<String?> getUserIdFromToken(String token) async {
  try {
    final uri = Uri.parse('$supabaseUrl/auth/v1/user');
    final headers = {
      'apikey': supabaseAnonKey,
      'Authorization': 'Bearer $token',
    };
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      return map['id'] as String?;
    }
  } catch (e) {
    // Ignore errors - return null if passenger not found
  }
  return null;
}

Future<bool> updatePassengerStatusWithActionLog(
    String id, String status, Map<String, dynamic> actionLog, String token) async {
  final uri = Uri.parse('$supabaseUrl/rest/v1/putovanja_istorija?id=eq.$id');
  final headers = {
    'apikey': supabaseAnonKey,
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };
  final body = jsonEncode({'status': status, 'updated_at': DateTime.now().toIso8601String(), 'action_log': actionLog});
  final r = await http.patch(uri, headers: headers, body: body);
  if (r.statusCode == 200 || r.statusCode == 204) return true;
  print('Update failed: ${r.statusCode} ${r.body}');
  return false;
}

Future<Map<String, dynamic>?> fetchPassenger(String id, String token) async {
  final uri = Uri.parse('$supabaseUrl/rest/v1/putovanja_istorija?select=*&id=eq.$id');
  final headers = {
    'apikey': supabaseAnonKey,
    'Authorization': 'Bearer $token',
  };
  final r = await http.get(uri, headers: headers);
  if (r.statusCode != 200) {
    print('Fetch failed: ${r.statusCode} ${r.body}');
    return null;
  }
  final list = jsonDecode(r.body) as List<dynamic>?;
  if (list == null || list.isEmpty) return null;
  return Map<String, dynamic>.from(list.first as Map);
}

Future<bool> updatePassengerStatus(String id, String status, String token) async {
  final uri = Uri.parse('$supabaseUrl/rest/v1/putovanja_istorija?id=eq.$id');
  final headers = {
    'apikey': supabaseAnonKey,
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };
  final body = jsonEncode({'status': status, 'updated_at': DateTime.now().toIso8601String()});
  final r = await http.patch(uri, headers: headers, body: body);
  if (r.statusCode == 200 || r.statusCode == 204) return true;
  print('Update failed: ${r.statusCode} ${r.body}');
  return false;
}
