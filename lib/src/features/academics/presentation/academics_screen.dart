import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/academic_repository.dart';

class AcademicsScreen extends ConsumerStatefulWidget {
  const AcademicsScreen({super.key});
  @override
  ConsumerState<AcademicsScreen> createState() => _AcademicsScreenState();
}

class _AcademicsScreenState extends ConsumerState<AcademicsScreen> {
  int _section = 0;
  String? _subjectFilter;
  static const _labels = ['موادي', 'مهامي', 'المخطط', 'محاضراتي'];
  static const _icons = [
    Icons.menu_book_rounded,
    Icons.task_alt_rounded,
    Icons.calendar_month_rounded,
    Icons.play_lesson_rounded,
  ];

  Future<void> _refresh() async {
    ref.invalidate(academicDataProvider);
    await ref.read(academicDataProvider.future);
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _refresh();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر حفظ التغيير: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(academicDataProvider);
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (i) {
          if (i == 0) {
            context.go('/home');
          } else if (i == 1) {
            setState(() {
              _section = 0;
              _subjectFilter = null;
            });
          } else if (i == 2) {
            setState(() {
              _section = 2;
              _subjectFilter = null;
            });
          } else if (i == 3) {
            context.go('/study-space');
          } else if (i == 4) {
            context.go('/insights');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
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
            label: 'حسابي',
          ),
        ],
      ),
      appBar: AppBar(
        title: Text(
          _subjectFilter == null ? 'مساحتي الدراسية' : 'محاضرات المادة',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: _subjectFilter == null
            ? null
            : IconButton(
                onPressed: () => setState(() => _subjectFilter = null),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(message: '$e', retry: _refresh),
              data: (data) => Column(
                children: [
                  if (_subjectFilter == null) _sectionBar(),
                  Expanded(
                    child: _subjectFilter != null
                        ? _lectures(data, _subjectFilter!)
                        : switch (_section) {
                            0 => _subjects(data),
                            1 => _tasks(data),
                            2 => _planner(data),
                            _ => _lectures(data, null),
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAdd(data: async.value),
        icon: const Icon(Icons.add_rounded),
        label: Text(_addLabel),
      ),
    );
  }

  String get _addLabel => switch (_section) {
    0 => 'مادة جديدة',
    1 => 'مهمة جديدة',
    2 => 'جلسة جديدة',
    _ => 'محاضرة جديدة',
  };

  Widget _sectionBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(
          _labels.length,
          (i) => Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(_labels[i]),
              avatar: Icon(_icons[i], size: 18),
              selected: _section == i,
              onSelected: (_) => setState(() => _section = i),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _subjects(AcademicData data) => data.subjects.isEmpty
      ? _empty(
          Icons.library_books_outlined,
          'موادك تبدأ من هنا',
          'أضف موادك، ثم نظّم محاضراتك ومهامك لكل مادة.',
        )
      : ListView(
          padding: const EdgeInsets.all(16),
          children: data.subjects.map((s) {
            final lectures = data.lectures
                .where((l) => l['subject_id'] == s['id'])
                .toList();
            final done = lectures
                .where((l) => l['is_completed'] == true)
                .length;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => setState(() {
                  _subjectFilter = s['id'] as String;
                  _section = 3;
                }),
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: StudyBridgeColors.lilacWash,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: StudyBridgeColors.purple,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s['name']}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if ((s['semester'] as String? ?? '').isNotEmpty)
                              Text(
                                '${s['semester']}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            const SizedBox(height: 7),
                            LinearProgressIndicator(
                              value: lectures.isEmpty
                                  ? 0
                                  : done / lectures.length,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            Text(
                              '$done من ${lectures.length} محاضرة مكتملة',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') {
                            _editSubject(s);
                          } else if (v == 'delete') {
                            _confirmDelete(
                              'حذف المادة؟',
                              () => ref
                                  .read(academicRepositoryProvider)
                                  .deleteSubject(s['id']),
                            );
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('تعديل المادة'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('حذف المادة'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );

  Widget _tasks(AcademicData data) {
    final tasks = [...data.tasks]
      ..sort((a, b) {
        if (a['is_completed'] == b['is_completed'])
          return (a['due_at'] ?? '9999').toString().compareTo(
            (b['due_at'] ?? '9999').toString(),
          );
        return a['is_completed'] == true ? 1 : -1;
      });
    if (tasks.isEmpty)
      return _empty(
        Icons.task_alt_rounded,
        'يومك أخف بلا مهام معلّقة',
        'أضف أول مهمة وحدد موعدها وأولويتها.',
      );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: tasks.map((t) {
        final overdue =
            t['due_at'] != null &&
            DateTime.parse(t['due_at']).isBefore(DateTime.now()) &&
            t['is_completed'] != true;
        final subject = data.subjects
            .where((s) => s['id'] == t['subject_id'])
            .firstOrNull?['name'];
        return Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: Checkbox(
              value: t['is_completed'] == true,
              onChanged: (v) => _run(
                () => ref
                    .read(academicRepositoryProvider)
                    .setTaskDone(t['id'], v ?? false),
              ),
            ),
            title: Text(
              '${t['title']}',
              style: TextStyle(
                decoration: t['is_completed'] == true
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: Text(
              [
                if (subject != null) '$subject',
                if (t['due_at'] != null) _date(t['due_at']),
                _priority(t['priority']),
                if (overdue) 'متأخرة',
              ].join(' • '),
              style: TextStyle(color: overdue ? Colors.redAccent : null),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _editTask(t, data),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: () => _confirmDelete(
                    'حذف المهمة؟',
                    () => ref
                        .read(academicRepositoryProvider)
                        .deleteTask(t['id']),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _planner(AcademicData data) {
    final sessions = [...data.sessions]
      ..sort(
        (a, b) =>
            a['starts_at'].toString().compareTo(b['starts_at'].toString()),
      );
    if (sessions.isEmpty)
      return _empty(
        Icons.calendar_month_rounded,
        'أسبوعك ينتظر خطتك',
        'أضف جلسة مذاكرة وحدد وقتها ومادتها.',
      );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final day in _groupSessions(sessions).entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Text(day.key, style: Theme.of(context).textTheme.titleLarge),
          ),
          for (final s in day.value)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Checkbox(
                  value: s['is_completed'] == true,
                  onChanged: (v) => _run(
                    () => ref
                        .read(academicRepositoryProvider)
                        .setSessionDone(s['id'], v ?? false),
                  ),
                ),
                title: Text('${s['title']}'),
                subtitle: Text(
                  '${_time(s['starts_at'])} – ${_time(s['ends_at'])}${s['subject_id'] == null ? '' : ' • ${data.subjects.where((x) => x['id'] == s['subject_id']).firstOrNull?['name'] ?? ''}'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _editSession(s, data),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () => _confirmDelete(
                        'حذف الجلسة؟',
                        () => ref
                            .read(academicRepositoryProvider)
                            .deleteSession(s['id']),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupSessions(
    List<Map<String, dynamic>> rows,
  ) {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final s in rows) {
      final d = DateTime.parse(s['starts_at']).toLocal();
      final key = '${_weekdays[d.weekday - 1]} • ${d.day}/${d.month}';
      result.putIfAbsent(key, () => []).add(s);
    }
    return result;
  }

  Widget _lectures(AcademicData data, String? subjectId) {
    final rows = data.lectures
        .where((l) => subjectId == null || l['subject_id'] == subjectId)
        .toList();
    if (rows.isEmpty)
      return _empty(
        Icons.play_lesson_outlined,
        'لا توجد محاضرات بعد',
        'أضف محاضراتك وسجّل ملاحظاتك ومدة المذاكرة.',
      );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: rows.map((l) {
        final sub = data.subjects
            .where((s) => s['id'] == l['subject_id'])
            .firstOrNull?['name'];
        return Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: Checkbox(
              value: l['is_completed'] == true,
              onChanged: (v) => _run(
                () => ref
                    .read(academicRepositoryProvider)
                    .setLectureDone(l['id'], v ?? false),
              ),
            ),
            title: Text('${l['title']}'),
            subtitle: Text(
              [
                if (sub != null) '$sub',
                if (l['lecture_date'] != null) _date(l['lecture_date']),
                if (l['estimated_minutes'] != null)
                  '${l['estimated_minutes']} دقيقة',
              ].join(' • '),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _editLecture(l, data),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: () => _confirmDelete(
                    'حذف المحاضرة؟',
                    () => ref
                        .read(academicRepositoryProvider)
                        .deleteLecture(l['id']),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _openAdd({AcademicData? data}) async {
    final repository = ref.read(academicRepositoryProvider);
    final subjects = data?.subjects ?? [];
    if (_section == 0) {
      final values = await _form(
        title: 'إضافة مادة',
        fields: const [
          ('اسم المادة', 'name'),
          ('الفصل الدراسي (اختياري)', 'semester'),
          ('وصف مختصر (اختياري)', 'description'),
        ],
      );
      if (values != null && values['name']!.trim().isNotEmpty)
        await _run(
          () => repository.addSubject(
            name: values['name']!,
            semester: values['semester']!,
            description: values['description']!,
          ),
        );
    } else if (_section == 1) {
      final values = await _form(
        title: 'إضافة مهمة',
        fields: const [
          ('عنوان المهمة', 'title'),
          ('وصف (اختياري)', 'description'),
        ],
        subjects: subjects,
        includePriority: true,
        includeDate: true,
      );
      if (values != null && values['title']!.trim().isNotEmpty)
        await _run(
          () => repository.addTask(
            title: values['title']!,
            description: values['description']!,
            subjectId: values['subject'],
            priority: values['priority'] ?? 'medium',
            due: values['date'],
          ),
        );
    } else if (_section == 2) {
      final values = await _form(
        title: 'جلسة مذاكرة',
        fields: const [
          ('عنوان الجلسة', 'title'),
          ('وصف (اختياري)', 'description'),
        ],
        subjects: subjects,
        includeDate: true,
        includeTime: true,
      );
      if (values != null &&
          values['title']!.trim().isNotEmpty &&
          values['date'] != null) {
        final start = values['date'] as DateTime;
        final time =
            values['time'] as TimeOfDay? ??
            TimeOfDay.fromDateTime(DateTime.now());
        final from = DateTime(
          start.year,
          start.month,
          start.day,
          time.hour,
          time.minute,
        );
        await _run(
          () => repository.addPlannerSession(
            title: values['title']!,
            description: values['description']!,
            subjectId: values['subject'],
            start: from,
            end: from.add(const Duration(hours: 1)),
          ),
        );
      }
    } else {
      if (subjects.isEmpty) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('أضف مادة أولاً.')));
        return;
      }
      final values = await _form(
        title: 'إضافة محاضرة',
        fields: const [
          ('عنوان المحاضرة', 'title'),
          ('وصف (اختياري)', 'description'),
          ('المدة بالدقائق (اختياري)', 'minutes'),
        ],
        subjects: subjects,
        includeDate: true,
      );
      if (values != null &&
          values['title']!.trim().isNotEmpty &&
          values['subject'] != null)
        await _run(
          () => repository.addLecture(
            subjectId: values['subject']!,
            title: values['title']!,
            description: values['description']!,
            date: values['date'],
            minutes: int.tryParse(values['minutes'] ?? ''),
          ),
        );
    }
  }

  Future<Map<String, dynamic>?> _form({
    required String title,
    required List<(String, String)> fields,
    List<Map<String, dynamic>> subjects = const [],
    bool includePriority = false,
    bool includeDate = false,
    bool includeTime = false,
    Map<String, dynamic>? initial,
  }) async {
    final controllers = {
      for (final f in fields)
        f.$2: TextEditingController(text: initial?[f.$2]?.toString() ?? ''),
    };
    String? subject = initial?['subject'] as String?;
    String priority = initial?['priority'] as String? ?? 'medium';
    DateTime? date = initial?['date'] == null
        ? null
        : DateTime.tryParse(initial!['date'].toString());
    TimeOfDay? time = initial?['time'] as TimeOfDay?;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final f in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[f.$2],
                      keyboardType: f.$2 == 'minutes'
                          ? TextInputType.number
                          : TextInputType.text,
                      decoration: InputDecoration(labelText: f.$1),
                    ),
                  ),
                if (subjects.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    initialValue: subject,
                    decoration: const InputDecoration(
                      labelText: 'المادة (اختياري)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('بدون مادة'),
                      ),
                      ...subjects.map(
                        (s) => DropdownMenuItem(
                          value: s['id'] as String,
                          child: Text(s['name'] as String),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => subject = v),
                  ),
                if (includePriority)
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'الأولوية'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('منخفضة')),
                      DropdownMenuItem(value: 'medium', child: Text('متوسطة')),
                      DropdownMenuItem(value: 'high', child: Text('عالية')),
                    ],
                    onChanged: (v) => setState(() => priority = v ?? 'medium'),
                  ),
                if (includeDate)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      date == null
                          ? 'اختر التاريخ'
                          : 'التاريخ: ${_date(date!.toIso8601String())}',
                    ),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: date ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        locale: const Locale('ar'),
                      );
                      if (d != null) setState(() => date = d);
                    },
                  ),
                if (includeTime)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      time == null
                          ? 'اختر وقت البداية'
                          : 'وقت البداية: ${time!.format(context)}',
                    ),
                    trailing: const Icon(Icons.access_time_rounded),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (t != null) setState(() => time = t);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                for (final e in controllers.entries) e.key: e.value.text,
                'subject': subject,
                'priority': priority,
                'date': date,
                'time': time,
              }),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    for (final c in controllers.values) {
      c.dispose();
    }
    return result;
  }

  Future<void> _editSubject(Map<String, dynamic> s) async {
    final v = await _form(
      title: 'تعديل المادة',
      fields: const [
        ('اسم المادة', 'name'),
        ('الفصل الدراسي (اختياري)', 'semester'),
        ('وصف مختصر (اختياري)', 'description'),
      ],
      initial: {
        'name': s['name'],
        'semester': s['semester'],
        'description': s['description'],
      },
    );
    if (v != null && v['name']!.trim().isNotEmpty)
      await _run(
        () => ref
            .read(academicRepositoryProvider)
            .updateSubject(
              s['id'],
              name: v['name']!,
              semester: v['semester']!,
              description: v['description']!,
            ),
      );
  }

  Future<void> _editTask(Map<String, dynamic> t, AcademicData data) async {
    final v = await _form(
      title: 'تعديل المهمة',
      fields: const [
        ('عنوان المهمة', 'title'),
        ('وصف (اختياري)', 'description'),
      ],
      subjects: data.subjects,
      includePriority: true,
      includeDate: true,
      initial: {
        'title': t['title'],
        'description': t['description'],
        'subject': t['subject_id'],
        'priority': t['priority'],
        'date': t['due_at'],
      },
    );
    if (v != null && v['title']!.trim().isNotEmpty)
      await _run(
        () => ref
            .read(academicRepositoryProvider)
            .updateTask(
              t['id'],
              title: v['title']!,
              description: v['description']!,
              subjectId: v['subject'],
              priority: v['priority'] ?? 'medium',
              due: v['date'],
            ),
      );
  }

  Future<void> _editLecture(Map<String, dynamic> l, AcademicData data) async {
    final v = await _form(
      title: 'تعديل المحاضرة',
      fields: const [
        ('عنوان المحاضرة', 'title'),
        ('وصف (اختياري)', 'description'),
        ('المدة بالدقائق (اختياري)', 'minutes'),
      ],
      subjects: data.subjects,
      includeDate: true,
      initial: {
        'title': l['title'],
        'description': l['description'],
        'subject': l['subject_id'],
        'date': l['lecture_date'],
        'minutes': l['estimated_minutes'],
      },
    );
    if (v != null && v['title']!.trim().isNotEmpty && v['subject'] != null)
      await _run(
        () => ref
            .read(academicRepositoryProvider)
            .updateLecture(
              l['id'],
              subjectId: v['subject']!,
              title: v['title']!,
              description: v['description']!,
              date: v['date'],
              minutes: int.tryParse(v['minutes'] ?? ''),
            ),
      );
  }

  Future<void> _editSession(Map<String, dynamic> s, AcademicData data) async {
    final start = DateTime.parse(s['starts_at']).toLocal();
    final v = await _form(
      title: 'تعديل الجلسة',
      fields: const [
        ('عنوان الجلسة', 'title'),
        ('وصف (اختياري)', 'description'),
      ],
      subjects: data.subjects,
      includeDate: true,
      includeTime: true,
      initial: {
        'title': s['title'],
        'description': s['description'],
        'subject': s['subject_id'],
        'date': start,
        'time': TimeOfDay.fromDateTime(start),
      },
    );
    if (v != null && v['title']!.trim().isNotEmpty && v['date'] != null) {
      final d = v['date'] as DateTime;
      final t = v['time'] as TimeOfDay? ?? TimeOfDay.fromDateTime(start);
      final from = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      await _run(
        () => ref
            .read(academicRepositoryProvider)
            .updatePlannerSession(
              s['id'],
              title: v['title']!,
              description: v['description']!,
              subjectId: v['subject'],
              start: from,
              end: from.add(const Duration(hours: 1)),
            ),
      );
    }
  }

  Future<void> _confirmDelete(
    String title,
    Future<void> Function() delete,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: const Text('لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (yes == true) await _run(delete);
  }

  Widget _empty(IconData icon, String title, String body) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 58,
            color: StudyBridgeColors.purple.withValues(alpha: .65),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
  String _date(String raw) {
    final d = DateTime.parse(raw).toLocal();
    return '${d.day}/${d.month}/${d.year}';
  }

  String _time(String raw) {
    final d = DateTime.parse(raw).toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _priority(String? p) => switch (p) {
    'high' => 'أولوية عالية',
    'low' => 'أولوية منخفضة',
    _ => 'أولوية متوسطة',
  };
  static const _weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.retry});
  final String message;
  final Future<void> Function() retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48),
          const SizedBox(height: 12),
          const Text('تعذر تحميل بياناتك'),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('إعادة المحاولة')),
        ],
      ),
    ),
  );
}
