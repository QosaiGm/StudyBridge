import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../academics/data/academic_repository.dart';
import '../data/focus_repository.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});
  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;
  FocusSession? _active;
  List<FocusSession> _history = const [];
  List<Map<String, dynamic>> _subjects = const [];
  String? _subjectId;
  int _durationMinutes = 25;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _active?.status != 'running') return;
      final session = _active!;
      setState(() {});
      if (session.remainingAt(DateTime.now()) == 0 && !_working) {
        _act(() => ref.read(focusRepositoryProvider).finish(session));
      }
    });
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final repository = ref.read(focusRepositoryProvider);
      final results = await Future.wait([
        repository.loadActive(),
        repository.history(),
        ref.read(academicRepositoryProvider).load(),
      ]);
      if (!mounted) return;
      setState(() {
        _active = results[0] as FocusSession?;
        _history = results[1] as List<FocusSession>;
        _subjects = (results[2] as AcademicData).subjects;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = '$e';
        });
    }
  }

  Future<void> _act(
    Future<FocusSession> Function() action, {
    bool clear = false,
  }) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _active =
            clear ||
                updated.status == 'completed' ||
                updated.status == 'cancelled'
            ? null
            : updated;
        _working = false;
      });
      if (_active == null) {
        final history = await ref.read(focusRepositoryProvider).history();
        if (mounted) setState(() => _history = history);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _working = false;
          _error = '$e';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _active;
    final remaining =
        session?.remainingAt(DateTime.now()) ?? _durationMinutes * 60;
    final fraction = session == null
        ? 1.0
        : (remaining / session.durationSeconds).clamp(0.0, 1.0);
    final subjectName = _subjects
        .where((s) => s['id'] == session?.subjectId)
        .firstOrNull?['name'];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'وقت التركيز',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'المساحة المشتركة',
            onPressed: () => context.go('/study-space'),
            icon: const Icon(Icons.groups_outlined),
          ),
        ],
        leading: IconButton(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        onDestinationSelected: (i) {
          if (i == 0) {
            context.go('/home');
          } else if (i == 1 || i == 2) {
            context.go('/academics');
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
            label: 'موادي',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'المخطط',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer_rounded),
            label: 'الدراسة',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'حسابي',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      if (_error != null)
                        Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'حدث خطأ: $_error',
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: StudyBridgeColors.gold.withValues(
                              alpha: .22,
                            ),
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [Color(0xFF241B30), Color(0xFF15111D)],
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              session == null
                                  ? 'مساحة هادئة لإنجازك'
                                  : session.status == 'paused'
                                  ? 'توقف قصير، خذ وقتك'
                                  : 'أنت في جلسة تركيز',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: 232,
                              height: 232,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox.expand(
                                    child: CircularProgressIndicator(
                                      value: fraction,
                                      strokeWidth: 12,
                                      strokeCap: StrokeCap.round,
                                      backgroundColor: StudyBridgeColors.border,
                                      color: StudyBridgeColors.gold,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _format(remaining),
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: StudyBridgeColors.ink,
                                            ),
                                      ),
                                      Text(
                                        session == null
                                            ? 'دقيقة تركيز'
                                            : (subjectName ?? 'جلسة شخصية'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (session == null) ...[
                              DropdownButtonFormField<int>(
                                initialValue: _durationMinutes,
                                decoration: const InputDecoration(
                                  labelText: 'مدة الجلسة',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 25,
                                    child: Text('25 دقيقة'),
                                  ),
                                  DropdownMenuItem(
                                    value: 50,
                                    child: Text('50 دقيقة'),
                                  ),
                                  DropdownMenuItem(
                                    value: 90,
                                    child: Text('90 دقيقة'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _durationMinutes = v ?? 25),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String?>(
                                initialValue: _subjectId,
                                decoration: const InputDecoration(
                                  labelText: 'المادة (اختياري)',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('بدون مادة'),
                                  ),
                                  ..._subjects.map(
                                    (s) => DropdownMenuItem(
                                      value: s['id'] as String,
                                      child: Text(s['name'] as String),
                                    ),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _subjectId = v),
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: _working
                                    ? null
                                    : () => _act(
                                        () => ref
                                            .read(focusRepositoryProvider)
                                            .start(
                                              durationSeconds:
                                                  _durationMinutes * 60,
                                              subjectId: _subjectId,
                                            ),
                                      ),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('ابدأ جلسة التركيز'),
                              ),
                            ] else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (session.status == 'running')
                                    FilledButton.tonalIcon(
                                      onPressed: _working
                                          ? null
                                          : () => _act(
                                              () => ref
                                                  .read(focusRepositoryProvider)
                                                  .pause(session),
                                            ),
                                      icon: const Icon(Icons.pause_rounded),
                                      label: const Text('إيقاف مؤقت'),
                                    )
                                  else
                                    FilledButton.icon(
                                      onPressed: _working
                                          ? null
                                          : () => _act(
                                              () => ref
                                                  .read(focusRepositoryProvider)
                                                  .resume(session),
                                            ),
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                      ),
                                      label: const Text('استئناف'),
                                    ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    onPressed: _working
                                        ? null
                                        : () => _confirmFinish(session),
                                    icon: const Icon(Icons.stop_rounded),
                                    label: const Text('إنهاء'),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    tooltip: 'إلغاء الجلسة',
                                    onPressed: _working
                                        ? null
                                        : () => _confirmCancel(session),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'جلساتك السابقة',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      if (_history.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              'ستجد هنا جلسات التركيز المكتملة.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      else
                        ..._history.map(
                          (entry) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                entry.status == 'completed'
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.cancel_outlined,
                                color: StudyBridgeColors.purple,
                              ),
                              title: Text(
                                entry.status == 'completed'
                                    ? 'جلسة مكتملة • ${_format(entry.elapsedSeconds)}'
                                    : 'جلسة ملغاة • ${_format(entry.elapsedSeconds)}',
                              ),
                              subtitle: Text(
                                '${_date(entry.startedAt.toLocal())} • من أصل ${_format(entry.durationSeconds)}',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmFinish(FocusSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('إنهاء جلسة التركيز؟'),
        content: const Text('سيتم حفظ الوقت الذي قضيته في هذه الجلسة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('متابعة'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('إنهاء'),
          ),
        ],
      ),
    );
    if (confirmed == true)
      await _act(() => ref.read(focusRepositoryProvider).finish(session));
  }

  Future<void> _confirmCancel(FocusSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('إلغاء الجلسة؟'),
        content: const Text('ستظهر الجلسة كملغاة في السجل.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('إلغاء الجلسة'),
          ),
        ],
      ),
    );
    if (confirmed == true)
      await _act(() => ref.read(focusRepositoryProvider).cancel(session));
  }

  String _format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final h = m ~/ 60;
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
