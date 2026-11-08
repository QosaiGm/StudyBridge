import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final experienceRepositoryProvider = Provider<ExperienceRepository>(
  (ref) => ExperienceRepository(Supabase.instance.client),
);

final experienceDataProvider = FutureProvider<ExperienceData>(
  (ref) => ref.watch(experienceRepositoryProvider).load(),
);

class ExperienceData {
  const ExperienceData({
    required this.focusSessions,
    required this.sharedSessions,
    required this.tasks,
    required this.lectures,
    required this.subjects,
    required this.spaces,
    required this.moments,
    required this.weekStartsOn,
  });

  final List<Map<String, dynamic>> focusSessions;
  final List<Map<String, dynamic>> sharedSessions;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> lectures;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> spaces;
  final List<Map<String, dynamic>> moments;
  final int weekStartsOn;
}

class ExperienceRepository {
  ExperienceRepository(this._client);
  final SupabaseClient _client;
  String get _userId => _client.auth.currentUser!.id;

  Future<ExperienceData> load() async {
    final focus = await _client
        .from('focus_sessions')
        .select(
          'id,status,started_at,segment_started_at,elapsed_seconds,duration_seconds,subject_id',
        )
        .eq('user_id', _userId)
        .order('started_at', ascending: false);
    final academic = await Future.wait<dynamic>([
      _client.from('tasks').select('id,is_completed,due_at'),
      _client.from('lectures').select('id,is_completed,subject_id'),
      _client.from('subjects').select('id,name'),
      _client
          .from('study_space_members')
          .select('space_id')
          .eq('user_id', _userId),
      _client
          .from('user_settings')
          .select('week_starts_on')
          .eq('user_id', _userId)
          .maybeSingle(),
    ]);

    final spaceIds = academic[3]
        .map((row) => row['space_id'] as String)
        .toSet()
        .toList();
    List<Map<String, dynamic>> shared = const [];
    List<Map<String, dynamic>> spaces = const [];
    List<Map<String, dynamic>> moments = const [];
    if (spaceIds.isNotEmpty) {
      final results = await Future.wait([
        _client
            .from('shared_focus_sessions')
            .select(
              'id,space_id,status,started_at,segment_started_at,elapsed_seconds,duration_seconds',
            )
            .inFilter('space_id', spaceIds)
            .order('started_at', ascending: false),
        _client.from('study_spaces').select('id,name').inFilter('id', spaceIds),
        _client
            .from('study_milestones')
            .select(
              'id,space_id,created_by,title,description,icon_key,created_at',
            )
            .inFilter('space_id', spaceIds)
            .order('created_at', ascending: false)
            .limit(60),
      ]);
      shared = List<Map<String, dynamic>>.from(results[0]);
      spaces = List<Map<String, dynamic>>.from(results[1]);
      moments = List<Map<String, dynamic>>.from(results[2]);
    }

    return ExperienceData(
      focusSessions: List<Map<String, dynamic>>.from(focus),
      tasks: List<Map<String, dynamic>>.from(academic[0]),
      lectures: List<Map<String, dynamic>>.from(academic[1]),
      subjects: List<Map<String, dynamic>>.from(academic[2]),
      sharedSessions: shared,
      spaces: spaces,
      moments: moments,
      weekStartsOn:
          (academic[4] as Map<String, dynamic>?)?['week_starts_on'] as int? ??
          1,
    );
  }

  Future<void> addMoment({
    required String spaceId,
    required String title,
    required String description,
    required String iconKey,
  }) async {
    await _client.from('study_milestones').insert({
      'space_id': spaceId,
      'created_by': _userId,
      'title': title.trim(),
      'description': description.trim(),
      'icon_key': iconKey,
    });
  }

  Future<void> deleteMoment(String id) async {
    await _client.from('study_milestones').delete().eq('id', id);
  }
}
