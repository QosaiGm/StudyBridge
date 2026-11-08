import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../data/experience_repository.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(experienceDataProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final name = (user?.userMetadata?['display_name'] as String?)?.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنجازاتي'),
        actions: [
          IconButton(
            tooltip: 'الإعدادات الشخصية',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 4,
        onDestinationSelected: (i) => _navigate(context, i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'موادي',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'المخطط',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            label: 'الدراسة',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'حسابي',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorView(
                message: '$error',
                retry: () => ref.invalidate(experienceDataProvider),
              ),
              data: (data) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(experienceDataProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  children: [
                    Text(
                      name?.isNotEmpty == true
                          ? 'أهلاً، $name'
                          : 'مساحة إنجازك',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      user?.email ?? 'تقدمك الدراسي الخاص',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    _StatsOverview(data: data),
                    const SizedBox(height: 22),
                    _SectionTitle(
                      title: 'هذا الأسبوع',
                      subtitle: 'وقت التركيز الشخصي لكل يوم',
                    ),
                    const SizedBox(height: 12),
                    _WeekChart(
                      rows: data.focusSessions,
                      weekStartsOn: data.weekStartsOn,
                    ),
                    const SizedBox(height: 22),
                    _SectionTitle(
                      title: 'تقدم المواد',
                      subtitle: 'محاضراتك المكتملة من إجمالي المحاضرات',
                    ),
                    const SizedBox(height: 10),
                    _SubjectProgress(data: data),
                    const SizedBox(height: 22),
                    _SharedSummary(data: data),
                    const SizedBox(height: 24),
                    _LittleMoments(
                      data: data,
                      onAdd: () => _createMoment(context, ref, data),
                      onDelete: (id) async {
                        await ref
                            .read(experienceRepositoryProvider)
                            .deleteMoment(id);
                        ref.invalidate(experienceDataProvider);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _navigate(BuildContext context, int i) {
    if (i == 0) {
      context.go('/home');
    } else if (i == 1 || i == 2) {
      context.go('/academics');
    } else if (i == 3) {
      context.go('/study-space');
    } else if (i == 4) {
      context.go('/insights');
    }
  }

  Future<void> _createMoment(
    BuildContext context,
    WidgetRef ref,
    ExperienceData data,
  ) async {
    if (data.spaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'أنشئ مساحة دراسة أو انضم إلى مساحة قبل إضافة لحظة مشتركة.',
          ),
        ),
      );
      return;
    }
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var spaceId = data.spaces.first['id'] as String;
    var iconKey = 'sparkle';
    var busy = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('لحظة صغيرة، ذكرى جميلة'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'عنوان اللحظة',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'اكتب ذكرى أو كلمة تشجيع',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: spaceId,
                    decoration: const InputDecoration(
                      labelText: 'المساحة الخاصة',
                    ),
                    items: data.spaces
                        .map(
                          (space) => DropdownMenuItem(
                            value: space['id'] as String,
                            child: Text('${space['name']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => spaceId = value ?? spaceId),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: iconKey,
                    decoration: const InputDecoration(labelText: 'رمز اللحظة'),
                    items: const [
                      DropdownMenuItem(
                        value: 'sparkle',
                        child: Text('نجمة صغيرة'),
                      ),
                      DropdownMenuItem(value: 'flag', child: Text('إنجاز')),
                      DropdownMenuItem(
                        value: 'favorite',
                        child: Text('كلمة محبة'),
                      ),
                      DropdownMenuItem(
                        value: 'school',
                        child: Text('نجاح دراسي'),
                      ),
                      DropdownMenuItem(
                        value: 'celebration',
                        child: Text('احتفال'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => iconKey = value ?? iconKey),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(dialogContext);
                      if (titleController.text.trim().isEmpty) return;
                      setDialogState(() => busy = true);
                      try {
                        await ref
                            .read(experienceRepositoryProvider)
                            .addMoment(
                              spaceId: spaceId,
                              title: titleController.text,
                              description: descriptionController.text,
                              iconKey: iconKey,
                            );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => busy = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text('تعذر حفظ اللحظة: $error')),
                        );
                      }
                    },
              child: Text(busy ? 'جارٍ الحفظ...' : 'احفظ اللحظة'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    descriptionController.dispose();
    if (saved == true) ref.invalidate(experienceDataProvider);
  }
}

class _StatsOverview extends StatelessWidget {
  const _StatsOverview({required this.data});
  final ExperienceData data;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(
      Duration(days: (todayStart.weekday - data.weekStartsOn + 7) % 7),
    );
    final personalToday = _sumElapsed(
      data.focusSessions.where((row) => _date(row) == todayStart),
      now,
    );
    final personalWeek = _sumElapsed(
      data.focusSessions.where((row) => !_date(row).isBefore(weekStart)),
      now,
    );
    final allTime = _sumElapsed(data.focusSessions, now);
    final completedSessions = data.focusSessions
        .where((row) => row['status'] == 'completed')
        .length;
    final completedTasks = data.tasks
        .where((row) => row['is_completed'] == true)
        .length;
    final completedLectures = data.lectures
        .where((row) => row['is_completed'] == true)
        .length;
    final streak = _streak(data.focusSessions, todayStart, now);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.today_rounded,
                label: 'اليوم',
                value: _duration(personalToday),
                accent: StudyBridgeColors.gold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.date_range_rounded,
                label: 'هذا الأسبوع',
                value: _duration(personalWeek),
                accent: StudyBridgeColors.lavender,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.hourglass_bottom_rounded,
                label: 'وقت التركيز',
                value: _duration(allTime),
                accent: StudyBridgeColors.pink,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department_rounded,
                label: 'أيام متتالية',
                value: '$streak',
                accent: StudyBridgeColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                Expanded(
                  child: _CountMetric(
                    label: 'جلسات مكتملة',
                    count: completedSessions,
                  ),
                ),
                _verticalDivider(),
                Expanded(
                  child: _CountMetric(
                    label: 'مهام مكتملة',
                    count: completedTasks,
                  ),
                ),
                _verticalDivider(),
                Expanded(
                  child: _CountMetric(
                    label: 'محاضرات مكتملة',
                    count: completedLectures,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _verticalDivider() =>
      Container(width: 1, height: 35, color: StudyBridgeColors.border);
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 21),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 21),
          ),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    ),
  );
}

class _CountMetric extends StatelessWidget {
  const _CountMetric({required this.label, required this.count});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        '$count',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(color: StudyBridgeColors.gold),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    ],
  );
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.rows, required this.weekStartsOn});
  final List<Map<String, dynamic>> rows;
  final int weekStartsOn;
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final start = todayStart.subtract(
      Duration(days: (todayStart.weekday - weekStartsOn + 7) % 7),
    );
    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    final values = days
        .map(
          (day) => _sumElapsed(rows.where((row) => _date(row) == day), today),
        )
        .toList();
    final maxValue = values.fold<int>(
      3600,
      (max, value) => value > max ? value : max,
    );
    const labels = ['إث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
        child: SizedBox(
          height: 142,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final date = days[index];
              final normalized = values[index] / maxValue;
              final barHeight = 18 + normalized * 78;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      values[index] == 0
                          ? '—'
                          : '${(values[index] / 60).round()}د',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: StudyBridgeColors.muted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 7),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: barHeight,
                      width: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors:
                              date ==
                                  DateTime(today.year, today.month, today.day)
                              ? [
                                  StudyBridgeColors.gold,
                                  const Color(0xFF8E7040),
                                ]
                              : [
                                  StudyBridgeColors.lavender,
                                  const Color(0xFF684C8B),
                                ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      labels[date.weekday - 1],
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _SubjectProgress extends StatelessWidget {
  const _SubjectProgress({required this.data});
  final ExperienceData data;
  @override
  Widget build(BuildContext context) {
    if (data.subjects.isEmpty) {
      return const _EmptyCard(text: 'أضف مادة لتظهر نسبة تقدم محاضراتها هنا.');
    }
    return Column(
      children: data.subjects.map((subject) {
        final lectures = data.lectures
            .where((row) => row['subject_id'] == subject['id'])
            .toList();
        final completed = lectures
            .where((row) => row['is_completed'] == true)
            .length;
        final progress = lectures.isEmpty ? 0.0 : completed / lectures.length;
        return Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${subject['name']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '$completed / ${lectures.length}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    color: StudyBridgeColors.lavender,
                    backgroundColor: StudyBridgeColors.border,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SharedSummary extends StatelessWidget {
  const _SharedSummary({required this.data});
  final ExperienceData data;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sharedElapsed = _sumElapsed(data.sharedSessions, now);
    final count = data.sharedSessions
        .where((row) => row['status'] == 'completed')
        .length;
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: StudyBridgeColors.elevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: StudyBridgeColors.gold.withValues(alpha: .25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.groups_rounded,
            color: StudyBridgeColors.gold,
            size: 28,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إنجازكم معاً',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 3),
                Text(
                  '${_duration(sharedElapsed)} تركيز مشترك • $count جلسة مكتملة',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (data.spaces.isEmpty)
                  Text(
                    'أنشئ مساحة خاصة لبدء جلسات مشتركة.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LittleMoments extends StatelessWidget {
  const _LittleMoments({
    required this.data,
    required this.onAdd,
    required this.onDelete,
  });
  final ExperienceData data;
  final VoidCallback onAdd;
  final Future<void> Function(String) onDelete;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: _SectionTitle(
              title: 'لحظات صغيرة',
              subtitle: 'ذكريات وكلمات تبقى بينكم',
            ),
          ),
          IconButton.filledTonal(
            onPressed: onAdd,
            tooltip: 'إضافة لحظة',
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (data.moments.isEmpty)
        const _EmptyCard(
          text: 'احفظوا هنا إنجازاً جميلاً أو كلمة تشجيع بين أعضاء المساحة.',
        ),
      ...data.moments.map((moment) {
        final space = data.spaces
            .where((item) => item['id'] == moment['space_id'])
            .firstOrNull;
        final isMine =
            moment['created_by'] ==
            Supabase.instance.client.auth.currentUser?.id;
        return Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: StudyBridgeColors.lilacWash,
              child: Icon(
                _momentIcon(moment['icon_key'] as String),
                color: StudyBridgeColors.gold,
              ),
            ),
            title: Text('${moment['title']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((moment['description'] as String).isNotEmpty)
                  Text('${moment['description']}'),
                const SizedBox(height: 3),
                Text(
                  '${space?['name'] ?? 'مساحة خاصة'} • ${_dateLabel(moment['created_at'] as String)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            isThreeLine: (moment['description'] as String).isNotEmpty,
            trailing: isMine
                ? IconButton(
                    tooltip: 'حذف اللحظة',
                    onPressed: () => onDelete(moment['id'] as String),
                    icon: const Icon(Icons.delete_outline_rounded),
                  )
                : null,
          ),
        );
      }),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 46,
            color: StudyBridgeColors.gold,
          ),
          const SizedBox(height: 12),
          Text(
            'تعذر تحميل الإحصاءات',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('إعادة المحاولة')),
        ],
      ),
    ),
  );
}

DateTime _date(Map<String, dynamic> row) {
  final date = DateTime.parse(row['started_at'] as String).toLocal();
  return DateTime(date.year, date.month, date.day);
}

int _rowElapsed(Map<String, dynamic> row, DateTime now) {
  final stored = row['elapsed_seconds'] as int? ?? 0;
  final running =
      row['status'] == 'running' && row['segment_started_at'] != null;
  final extra = running
      ? now
            .toUtc()
            .difference(
              DateTime.parse(row['segment_started_at'] as String).toUtc(),
            )
            .inSeconds
      : 0;
  final duration = row['duration_seconds'] as int? ?? 0;
  return (stored + extra).clamp(0, duration);
}

int _sumElapsed(Iterable<Map<String, dynamic>> rows, DateTime now) =>
    rows.fold(0, (sum, row) => sum + _rowElapsed(row, now));

int _streak(List<Map<String, dynamic>> rows, DateTime today, DateTime now) {
  final studied = rows
      .where((row) => _rowElapsed(row, now) > 0)
      .map((row) => _date(row))
      .toSet();
  var cursor = studied.contains(today)
      ? today
      : today.subtract(const Duration(days: 1));
  var count = 0;
  while (studied.contains(cursor)) {
    count++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return count;
}

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) return '$minutes د';
  return minutes == 0 ? '$hours س' : '$hours س $minutes د';
}

String _dateLabel(String raw) {
  final date = DateTime.parse(raw).toLocal();
  return '${date.day}/${date.month}/${date.year}';
}

IconData _momentIcon(String key) => switch (key) {
  'flag' => Icons.flag_rounded,
  'favorite' => Icons.favorite_rounded,
  'school' => Icons.school_rounded,
  'celebration' => Icons.celebration_rounded,
  _ => Icons.auto_awesome_rounded,
};
