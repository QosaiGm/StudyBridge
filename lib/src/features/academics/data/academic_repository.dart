import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final academicRepositoryProvider = Provider<AcademicRepository>((ref) => AcademicRepository(Supabase.instance.client));
final academicDataProvider = FutureProvider<AcademicData>((ref) => ref.watch(academicRepositoryProvider).load());
final homeAcademicDataProvider = FutureProvider<AcademicData>(
  (ref) => ref.watch(academicRepositoryProvider).loadForDashboard(),
);

class AcademicData {
  const AcademicData({required this.subjects, required this.lectures, required this.tasks, required this.sessions});
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> lectures;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> sessions;
}

class AcademicRepository {
  AcademicRepository(this._client);
  final SupabaseClient _client;
  String get _userId => _client.auth.currentUser!.id;

  Future<AcademicData> load() async {
    final results = await Future.wait([
      _client.from('subjects').select().order('name'),
      _client.from('lectures').select().order('lecture_date'),
      _client.from('tasks').select().order('due_at'),
      _client.from('planner_sessions').select().order('starts_at'),
    ]);
    return AcademicData(
      subjects: List<Map<String, dynamic>>.from(results[0]),
      lectures: List<Map<String, dynamic>>.from(results[1]),
      tasks: List<Map<String, dynamic>>.from(results[2]),
      sessions: List<Map<String, dynamic>>.from(results[3]),
    );
  }

  Future<AcademicData> loadForDashboard() async {
    final results = await Future.wait([
      _client
          .from('subjects')
          .select('id,name')
          .eq('user_id', _userId)
          .order('name'),
      _client
          .from('lectures')
          .select()
          .eq('user_id', _userId)
          .eq('is_completed', false)
          .order('lecture_date')
          .limit(3),
      _client
          .from('tasks')
          .select()
          .eq('user_id', _userId)
          .eq('is_completed', false)
          .order('due_at')
          .limit(3),
    ]);

    return AcademicData(
      subjects: List<Map<String, dynamic>>.from(results[0]),
      lectures: List<Map<String, dynamic>>.from(results[1]),
      tasks: List<Map<String, dynamic>>.from(results[2]),
      sessions: const [],
    );
  }

  Future<void> addSubject({required String name, String description = '', String semester = ''}) async {
    await _client.from('subjects').insert({'user_id': _userId, 'name': name.trim(), 'description': description.trim(), 'semester': semester.trim()});
  }

  Future<void> updateSubject(String id, {required String name, String description = '', String semester = ''}) async { await _client.from('subjects').update({'name': name.trim(), 'description': description.trim(), 'semester': semester.trim()}).eq('id', id); }
  Future<void> deleteSubject(String id) async { await _client.from('subjects').delete().eq('id', id); }
  Future<void> addLecture({required String subjectId, required String title, String description = '', DateTime? date, int? minutes}) async {
    await _client.from('lectures').insert({'user_id': _userId, 'subject_id': subjectId, 'title': title.trim(), 'description': description.trim(), 'lecture_date': date?.toIso8601String().substring(0, 10), 'estimated_minutes': minutes});
  }
  Future<void> updateLecture(String id, {required String subjectId, required String title, String description = '', DateTime? date, int? minutes}) async { await _client.from('lectures').update({'subject_id': subjectId, 'title': title.trim(), 'description': description.trim(), 'lecture_date': date?.toIso8601String().substring(0, 10), 'estimated_minutes': minutes}).eq('id', id); }
  Future<void> setLectureDone(String id, bool done) async { await _client.from('lectures').update({'is_completed': done}).eq('id', id); }
  Future<void> deleteLecture(String id) async { await _client.from('lectures').delete().eq('id', id); }

  Future<void> addTask({required String title, String description = '', String? subjectId, String priority = 'medium', DateTime? due}) async {
    await _client.from('tasks').insert({'user_id': _userId, 'title': title.trim(), 'description': description.trim(), 'subject_id': subjectId, 'priority': priority, 'due_at': due?.toIso8601String()});
  }
  Future<void> updateTask(String id, {required String title, String description = '', String? subjectId, String priority = 'medium', DateTime? due}) async { await _client.from('tasks').update({'title': title.trim(), 'description': description.trim(), 'subject_id': subjectId, 'priority': priority, 'due_at': due?.toIso8601String()}).eq('id', id); }
  Future<void> setTaskDone(String id, bool done) async { await _client.from('tasks').update({'is_completed': done}).eq('id', id); }
  Future<void> deleteTask(String id) async { await _client.from('tasks').delete().eq('id', id); }

  Future<void> addPlannerSession({required String title, required DateTime start, required DateTime end, String description = '', String? subjectId}) async {
    await _client.from('planner_sessions').insert({'user_id': _userId, 'title': title.trim(), 'description': description.trim(), 'subject_id': subjectId, 'starts_at': start.toUtc().toIso8601String(), 'ends_at': end.toUtc().toIso8601String()});
  }
  Future<void> updatePlannerSession(String id, {required String title, required DateTime start, required DateTime end, String description = '', String? subjectId}) async { await _client.from('planner_sessions').update({'title': title.trim(), 'description': description.trim(), 'subject_id': subjectId, 'starts_at': start.toUtc().toIso8601String(), 'ends_at': end.toUtc().toIso8601String()}).eq('id', id); }
  Future<void> setSessionDone(String id, bool done) async { await _client.from('planner_sessions').update({'is_completed': done}).eq('id', id); }
  Future<void> deleteSession(String id) async { await _client.from('planner_sessions').delete().eq('id', id); }
}

