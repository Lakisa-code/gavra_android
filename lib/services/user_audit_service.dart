import 'package:supabase_flutter/supabase_flutter.dart';

class UserAuditService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Logs a user change to the user_daily_changes table
  Future<void> logUserChange(String putnikId, String changeType) async {
    try {
      final putnikIdInt = int.tryParse(putnikId);
      if (putnikIdInt == null) {
        print('Invalid putnik ID: $putnikId');
        return;
      }

      final today = DateTime.now();
      final dateKey = today.toIso8601String().split('T')[0]; // YYYY-MM-DD format

      // Check if record exists for today
      final existingRecord = await _supabase
          .from('user_daily_changes')
          .select()
          .eq('putnik_id', putnikIdInt)
          .eq('datum', dateKey)
          .maybeSingle();

      if (existingRecord != null) {
        // Update existing record
        await _supabase.from('user_daily_changes').update({
          'changes_count': existingRecord['changes_count'] + 1,
          'last_change_at': today.toIso8601String(),
        }).eq('id', existingRecord['id']);
      } else {
        // Create new record
        await _supabase.from('user_daily_changes').insert({
          'putnik_id': putnikIdInt,
          'datum': dateKey,
          'changes_count': 1,
          'last_change_at': today.toIso8601String(),
        });
      }
    } catch (e) {
      print('Error logging user change: $e');
      // Don't throw error to avoid breaking user operations
    }
  }

  /// Gets today's statistics for all users
  Future<List<Map<String, dynamic>>> getTodayStats() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('user_daily_changes')
          .select('putnik_id, changes_count, last_change_at')
          .eq('datum', today)
          .order('changes_count', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting today stats: $e');
      return [];
    }
  }

  /// Gets change history for a specific user
  Future<List<Map<String, dynamic>>> getUserChangeHistory(String putnikId) async {
    try {
      final putnikIdInt = int.tryParse(putnikId);
      if (putnikIdInt == null) {
        print('Invalid putnik ID: $putnikId');
        return [];
      }

      final response = await _supabase
          .from('user_daily_changes')
          .select('datum, changes_count, last_change_at')
          .eq('putnik_id', putnikIdInt)
          .order('datum', ascending: false)
          .limit(30); // Last 30 days

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting user change history: $e');
      return [];
    }
  }

  /// Cleans up old audit records (older than 90 days)
  Future<void> cleanupOldRecords() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
      final cutoffString = cutoffDate.toIso8601String().split('T')[0];

      await _supabase.from('user_daily_changes').delete().lt('datum', cutoffString);

      print('Cleaned up user audit records older than $cutoffString');
    } catch (e) {
      print('Error cleaning up old audit records: $e');
    }
  }
}
