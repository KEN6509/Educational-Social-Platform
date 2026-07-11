import 'package:supabase_flutter/supabase_flutter.dart';

class ParentChildRepository {
  ParentChildRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchLinks() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('parent_child_links')
        .select('*, parent:profiles!parent_child_links_parent_id_fkey(name, email, avatar_url), child:profiles!parent_child_links_child_id_fkey(name, email, avatar_url)')
        .or('parent_id.eq.$userId,child_id.eq.$userId');

    return response.cast<Map<String, dynamic>>();
  }

  Future<void> createInvite(String childId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('parent_child_links').insert({
      'parent_id': userId,
      'child_id': childId,
      'status': 'pending',
      'requested_by': userId,
    });
  }

  Future<void> updateLinkStatus(String linkId, String status) async {
    await _client
        .from('parent_child_links')
        .update({'status': status, 'linked_at': status == 'active' ? DateTime.now().toIso8601String() : null})
        .eq('id', linkId);
  }

  Future<List<Map<String, dynamic>>> fetchScreenTime(String childId) async {
    final response = await _client
        .from('screen_time_logs')
        .select()
        .eq('child_id', childId)
        .order('log_date', ascending: false);

    return response.cast<Map<String, dynamic>>();
  }

  Future<void> createSOS(String message) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('sos_alerts').insert({
      'child_id': userId,
      'message': message,
      'status': 'open',
    });
  }
}
