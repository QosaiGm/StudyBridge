import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final studySpaceRepositoryProvider = Provider<StudySpaceRepository>((ref) => StudySpaceRepository(Supabase.instance.client));

class StudySpaceRepository {
  StudySpaceRepository(this._client);
  final SupabaseClient _client;
  String get _userId => _client.auth.currentUser!.id;

  Future<DateTime> serverTime(String spaceId) async {
    final value = await _client.rpc('get_shared_focus_server_time', params: {'p_space_id': spaceId});
    return DateTime.parse(value as String).toUtc();
  }

  Future<List<Map<String, dynamic>>> spaces() async {
    final rows = await _client.from('study_space_members').select('space_id, role, study_spaces(id,name,created_by,created_at)').eq('user_id', _userId).order('joined_at', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row['study_spaces'] as Map)..['my_role'] = row['role']).toList();
  }

  Future<List<Map<String, dynamic>>> members(String spaceId) async => List<Map<String, dynamic>>.from(await _client.from('study_space_members').select('user_id,display_name,role,joined_at').eq('space_id', spaceId).order('joined_at'));

  Future<String> createSpace(String name) async => await _client.rpc('create_private_study_space', params: {'p_name': name.trim()}) as String;
  Future<String> invite(String spaceId) async => await _client.rpc('create_study_space_invitation', params: {'p_space_id': spaceId}) as String;
  Future<String> acceptInvite(String code) async => await _client.rpc('accept_study_space_invitation', params: {'p_code': code.trim().toUpperCase()}) as String;

  Future<void> setMyPresence(String status) => _setPresence(status);

  Future<void> sendMessage(String spaceId, String body) async { await _client.from('chat_messages').insert({'space_id': spaceId, 'user_id': _userId, 'body': body.trim()}); }

  Future<void> _setPresence(String status) async { try { await _client.rpc('set_my_presence', params: {'p_status': status}); } catch (_) { /* Best-effort until the latest schema is applied. */ } }

  Future<void> startSharedSession(String spaceId, int durationSeconds) async {
    await _client.rpc('start_shared_focus_session', params: {'p_space_id': spaceId, 'p_duration_seconds': durationSeconds});
    await _setPresence('studying');
  }
  Future<void> joinSharedSession(String sessionId) async { await _client.rpc('join_shared_focus_session', params: {'p_session_id': sessionId}); await _setPresence('studying'); }
  Future<void> controlSharedSession(String sessionId, String action) async { await _client.rpc('control_shared_focus_session', params: {'p_session_id': sessionId, 'p_action': action}); await _setPresence(action == 'resume' ? 'studying' : 'online'); }
  Future<void> leaveSharedSession(String sessionId) async { await _client.rpc('leave_shared_focus_session', params: {'p_session_id': sessionId}); await _setPresence('online'); }
}

class SharedFocusClock {
  const SharedFocusClock();

  int elapsedAt({required int storedElapsedSeconds, required int durationSeconds, required bool running, required DateTime? segmentStartedAt, required DateTime serverNow}) {
    final segmentElapsed = running && segmentStartedAt != null ? serverNow.toUtc().difference(segmentStartedAt.toUtc()).inSeconds : 0;
    return (storedElapsedSeconds + segmentElapsed).clamp(0, durationSeconds);
  }

  int remainingAt({required int storedElapsedSeconds, required int durationSeconds, required bool running, required DateTime? segmentStartedAt, required DateTime serverNow}) => durationSeconds - elapsedAt(storedElapsedSeconds: storedElapsedSeconds, durationSeconds: durationSeconds, running: running, segmentStartedAt: segmentStartedAt, serverNow: serverNow);
}




