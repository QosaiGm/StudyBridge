import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final focusRepositoryProvider = Provider<FocusRepository>((ref) => FocusRepository(Supabase.instance.client));

class FocusSession {
  const FocusSession({required this.id, required this.durationSeconds, required this.elapsedSeconds, required this.status, required this.startedAt, this.segmentStartedAt, this.endedAt, this.subjectId});
  final String id;
  final int durationSeconds;
  final int elapsedSeconds;
  final String status;
  final DateTime startedAt;
  final DateTime? segmentStartedAt;
  final DateTime? endedAt;
  final String? subjectId;

  factory FocusSession.fromMap(Map<String, dynamic> row) => FocusSession(
    id: row['id'] as String,
    durationSeconds: row['duration_seconds'] as int,
    elapsedSeconds: row['elapsed_seconds'] as int,
    status: row['status'] as String,
    startedAt: DateTime.parse(row['started_at'] as String),
    segmentStartedAt: row['segment_started_at'] == null ? null : DateTime.parse(row['segment_started_at'] as String),
    endedAt: row['ended_at'] == null ? null : DateTime.parse(row['ended_at'] as String),
    subjectId: row['subject_id'] as String?,
  );

  int elapsedAt(DateTime now) {
    final active = status == 'running' && segmentStartedAt != null ? now.toUtc().difference(segmentStartedAt!).inSeconds : 0;
    return (elapsedSeconds + active).clamp(0, durationSeconds);
  }
  int remainingAt(DateTime now) => (durationSeconds - elapsedAt(now)).clamp(0, durationSeconds);
}

class FocusRepository {
  FocusRepository(this._client);
  final SupabaseClient _client;
  String get _userId => _client.auth.currentUser!.id;

  Future<FocusSession?> loadActive() async {
    final rows = await _client.from('focus_sessions').select().eq('user_id', _userId).inFilter('status', ['running','paused']).order('started_at', ascending: false).limit(1);
    if (rows.isEmpty) return null;
    final session = FocusSession.fromMap(rows.first);
    if (session.remainingAt(DateTime.now()) == 0) { await _finish(session, 'completed'); return null; }
    await _setPresence(session.status == 'running' ? 'studying' : 'online');
    return session;
  }

  Future<List<FocusSession>> history() async {
    final rows = await _client.from('focus_sessions').select().eq('user_id', _userId).inFilter('status', ['completed','cancelled']).order('started_at', ascending: false).limit(30);
    return rows.map((row) => FocusSession.fromMap(row)).toList();
  }

  Future<FocusSession> start({required int durationSeconds, String? subjectId}) async {
    final now = DateTime.now().toUtc();
    final row = await _client.from('focus_sessions').insert({
      'user_id': _userId,
      'subject_id': subjectId,
      'duration_seconds': durationSeconds,
      'elapsed_seconds': 0,
      'status': 'running',
      'started_at': now.toIso8601String(),
      'segment_started_at': now.toIso8601String(),
    }).select().single();
    final session = FocusSession.fromMap(row);
    await _setPresence('studying');
    return session;
  }

  Future<FocusSession> pause(FocusSession session) async {
    final now = DateTime.now().toUtc();
    final elapsed = session.elapsedAt(now);
    final updated = await _save(session, {'elapsed_seconds': elapsed, 'status': elapsed >= session.durationSeconds ? 'completed' : 'paused', 'segment_started_at': null, 'ended_at': elapsed >= session.durationSeconds ? now.toIso8601String() : null});
    await _setPresence('online');
    return updated;
  }

  Future<FocusSession> resume(FocusSession session) async {
    final now = DateTime.now().toUtc();
    final updated = await _save(session, {'status': 'running', 'segment_started_at': now.toIso8601String()});
    await _setPresence('studying');
    return updated;
  }

  Future<FocusSession> finish(FocusSession session) async => _finish(session, 'completed');
  Future<FocusSession> cancel(FocusSession session) async => _finish(session, 'cancelled');

  Future<FocusSession> _finish(FocusSession session, String status) async {
    final now = DateTime.now().toUtc();
    final elapsed = session.elapsedAt(now);
    final updated = await _save(session, {'elapsed_seconds': elapsed, 'status': status, 'segment_started_at': null, 'ended_at': now.toIso8601String()});
    await _setPresence('online');
    return updated;
  }

  Future<void> _setPresence(String status) async { try { await _client.rpc('set_my_presence', params: {'p_status': status}); } catch (_) { /* Presence is best-effort until the latest schema is applied. */ } }

  Future<FocusSession> _save(FocusSession session, Map<String, dynamic> changes) async {
    final row = await _client.from('focus_sessions').update(changes).eq('id', session.id).eq('user_id', _userId).select().single();
    return FocusSession.fromMap(row);
  }
}






