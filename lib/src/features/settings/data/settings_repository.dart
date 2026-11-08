import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(Supabase.instance.client),
);

class PersonalSettings {
  const PersonalSettings({
    required this.displayName,
    required this.avatarUrl,
    required this.weekStartsOn,
    required this.taskReminders,
    required this.overdueReminders,
    required this.plannerReminders,
    required this.sharedActivityReminders,
    required this.encouragement,
    required this.reminderLeadMinutes,
    required this.quietHours,
    required this.quietStart,
    required this.quietEnd,
  });

  final String displayName;
  final String avatarUrl;
  final int weekStartsOn;
  final bool taskReminders;
  final bool overdueReminders;
  final bool plannerReminders;
  final bool sharedActivityReminders;
  final bool encouragement;
  final int reminderLeadMinutes;
  final bool quietHours;
  final String quietStart;
  final String quietEnd;
}

class SettingsRepository {
  SettingsRepository(this._client);
  final SupabaseClient _client;
  String get _userId => _client.auth.currentUser!.id;
  get currentUser => _client.auth.currentUser;

  Future<PersonalSettings> load() async {
    final results = await Future.wait([
      _client
          .from('profiles')
          .select('display_name,avatar_url')
          .eq('id', _userId)
          .maybeSingle(),
      _client
          .from('user_settings')
          .select('week_starts_on')
          .eq('user_id', _userId)
          .maybeSingle(),
      _client
          .from('notification_preferences')
          .select()
          .eq('user_id', _userId)
          .maybeSingle(),
    ]);
    final user = _client.auth.currentUser;
    final profile = results[0] as Map<String, dynamic>?;
    final settings = results[1] as Map<String, dynamic>?;
    final notifications = results[2] as Map<String, dynamic>?;
    return PersonalSettings(
      displayName:
          (profile?['display_name'] as String?) ??
          (user?.userMetadata?['display_name'] as String? ?? ''),
      avatarUrl: profile?['avatar_url'] as String? ?? '',
      weekStartsOn: settings?['week_starts_on'] as int? ?? 1,
      taskReminders: notifications?['task_reminders_enabled'] as bool? ?? true,
      overdueReminders:
          notifications?['overdue_task_reminders_enabled'] as bool? ?? true,
      plannerReminders:
          notifications?['planner_reminders_enabled'] as bool? ?? true,
      sharedActivityReminders:
          notifications?['shared_activity_reminders_enabled'] as bool? ?? true,
      encouragement: notifications?['encouragement_enabled'] as bool? ?? true,
      reminderLeadMinutes:
          notifications?['reminder_lead_minutes'] as int? ?? 15,
      quietHours: notifications?['quiet_hours_enabled'] as bool? ?? false,
      quietStart: notifications?['quiet_hours_start'] as String? ?? '22:00:00',
      quietEnd: notifications?['quiet_hours_end'] as String? ?? '07:00:00',
    );
  }

  Future<void> save(PersonalSettings settings) async {
    final name = settings.displayName.trim();
    final avatar = settings.avatarUrl.trim();
    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'display_name': name,
          'avatar_url': avatar.isEmpty ? null : avatar,
        },
      ),
    );
    await _client.rpc(
      'update_my_display_name',
      params: {'p_display_name': name},
    );
    await _client
        .from('profiles')
        .update({'avatar_url': avatar.isEmpty ? null : avatar})
        .eq('id', _userId);

    await _client.from('user_settings').upsert({
      'user_id': _userId,
      'week_starts_on': settings.weekStartsOn,
    }, onConflict: 'user_id');
    await _client.from('notification_preferences').upsert({
      'user_id': _userId,
      'task_reminders_enabled': settings.taskReminders,
      'overdue_task_reminders_enabled': settings.overdueReminders,
      'planner_reminders_enabled': settings.plannerReminders,
      'shared_activity_reminders_enabled': settings.sharedActivityReminders,
      'encouragement_enabled': settings.encouragement,
      'reminder_lead_minutes': settings.reminderLeadMinutes,
      'quiet_hours_enabled': settings.quietHours,
      'quiet_hours_start': settings.quietStart,
      'quiet_hours_end': settings.quietEnd,
    }, onConflict: 'user_id');
  }
}
