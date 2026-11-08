import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../data/study_space_repository.dart';
import 'voice_room_screen.dart';

class StudySpaceScreen extends ConsumerStatefulWidget {
  const StudySpaceScreen({super.key});
  @override
  ConsumerState<StudySpaceScreen> createState() => _StudySpaceScreenState();
}

class _StudySpaceScreenState extends ConsumerState<StudySpaceScreen> {
  Timer? _ticker;
  String? _streamSpaceId;
  Stream<List<Map<String, dynamic>>>? _sessionsStream;
  Future<List<Map<String, dynamic>>>? _membersFuture;
  final Map<String, Stream<List<Map<String, dynamic>>>> _participantStreams =
      {};
  String? _finishingSessionId;
  String? _clockKey;
  int _sharedElapsedAtSync = 0;
  DateTime? _sharedLocalAnchor;
  bool _clockLoading = false;
  List<Map<String, dynamic>> _spaces = const [];
  Map<String, dynamic>? _selected;
  bool _showChat = false;
  final TextEditingController _chatController = TextEditingController();
  final Map<String, Stream<List<Map<String, dynamic>>>> _chatStreams = {};
  final Map<String, Stream<List<Map<String, dynamic>>>> _presenceStreams = {};
  int _durationMinutes = 25;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadSpaces();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _loadSpaces() async {
    try {
      final rows = await ref.read(studySpaceRepositoryProvider).spaces();
      if (mounted)
        setState(() {
          _spaces = rows;
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

  Future<void> _createSpace() async {
    final name = await _textDialog(
      title: 'مساحة دراسة جديدة',
      label: 'اسم المساحة',
    );
    if (name == null || name.trim().isEmpty) return;
    await _run(() async {
      final id = await ref.read(studySpaceRepositoryProvider).createSpace(name);
      await _loadSpaces();
      if (mounted)
        setState(() => _selected = _spaces.firstWhere((s) => s['id'] == id));
    });
  }

  Future<void> _acceptInvite() async {
    final code = await _textDialog(
      title: 'الانضمام إلى مساحة',
      label: 'رمز الدعوة',
    );
    if (code == null || code.trim().isEmpty) return;
    await _run(() async {
      final id = await ref
          .read(studySpaceRepositoryProvider)
          .acceptInvite(code);
      await _loadSpaces();
      if (mounted)
        setState(() => _selected = _spaces.firstWhere((s) => s['id'] == id));
    });
  }

  Future<String?> _textDialog({
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (mounted)
      setState(() {
        _working = true;
        _error = null;
      });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _invite() async {
    final space = _selected;
    if (space == null) return;
    await _run(() async {
      final code = await ref
          .read(studySpaceRepositoryProvider)
          .invite(space['id']);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('رمز دعوة خاص'),
          content: SelectableText(
            code,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(letterSpacing: 4, color: StudyBridgeColors.purple),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('تم'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          selected == null
              ? 'مساحات الدراسة'
              : _showChat
              ? 'المحادثة • ${selected['name']}'
              : '${selected['name']}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: selected == null
            ? null
            : IconButton(
                onPressed: () => setState(() {
                  if (_showChat) {
                    _showChat = false;
                  } else {
                    _selected = null;
                  }
                }),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
        actions: [
          if (selected != null)
            IconButton(
              tooltip: _showChat ? 'العودة إلى الجلسة' : 'المحادثة',
              onPressed: () => setState(() => _showChat = !_showChat),
              icon: Icon(
                _showChat
                    ? Icons.timer_outlined
                    : Icons.chat_bubble_outline_rounded,
              ),
            ),
          if (selected != null)
            IconButton(
              tooltip: 'إنشاء رمز دعوة',
              onPressed: _working ? null : _invite,
              icon: const Icon(Icons.person_add_alt_1_rounded),
            ),
        ],
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
            constraints: const BoxConstraints(maxWidth: 850),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : selected == null
                ? _spaceList()
                : _spaceDetail(selected),
          ),
        ),
      ),
      floatingActionButton: selected == null
          ? FloatingActionButton.extended(
              onPressed: _working ? null : _createSpace,
              icon: const Icon(Icons.add_rounded),
              label: const Text('مساحة جديدة'),
            )
          : null,
    );
  }

  Widget _spaceList() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
    children: [
      if (_error != null) _errorCard(),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: StudyBridgeColors.lilacWash,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Text(
          'مساحات خاصة تجمعك بمن تختار للدراسة والإنجاز بهدوء.',
          style: TextStyle(height: 1.6),
        ),
      ),
      const SizedBox(height: 18),
      if (_spaces.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.groups_2_outlined,
                  size: 48,
                  color: StudyBridgeColors.purple,
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد مساحة بعد',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  'أنشئ مساحة خاصة أو أدخل رمز دعوة للانضمام إلى صديق.',
                ),
              ],
            ),
          ),
        ),
      ..._spaces.map(
        (space) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: StudyBridgeColors.lilacWash,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: StudyBridgeColors.purple,
              ),
            ),
            title: Text('${space['name']}'),
            subtitle: Text(
              space['my_role'] == 'owner' ? 'مساحتك الخاصة' : 'مساحة مشتركة',
            ),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => setState(() => _selected = space),
          ),
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _working ? null : _acceptInvite,
        icon: const Icon(Icons.key_rounded),
        label: const Text('لديك رمز دعوة؟ انضم'),
      ),
    ],
  );

  Widget _spaceDetail(Map<String, dynamic> space) {
    if (_showChat) return _chatView(space);
    final repo = ref.read(studySpaceRepositoryProvider);
    final client = Supabase.instance.client;
    if (_streamSpaceId != space['id']) {
      _streamSpaceId = space['id'] as String;
      _sessionsStream = client
          .from('shared_focus_sessions')
          .stream(primaryKey: ['id'])
          .eq('space_id', space['id'])
          .order('created_at', ascending: false);
      _membersFuture = repo.members(space['id']);
    }
    final stream = _sessionsStream!;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [_errorCard(message: '${snapshot.error}')],
          );
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        final active = rows
            .where((r) => r['status'] == 'running' || r['status'] == 'paused')
            .firstOrNull;
        final memberFuture = _membersFuture!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            if (_error != null) _errorCard(),
            Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: StudyBridgeColors.purple,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'مساحة خاصة • ${space['my_role'] == 'owner' ? 'أنت المضيف' : 'عضو'}',
                  ),
                ),
                IconButton(
                  tooltip: 'رمز دعوة',
                  onPressed: _working ? null : _invite,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _membersCard(space['id'], memberFuture),

            const SizedBox(height: 12),
            Card(
              color: StudyBridgeColors.surface,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: StudyBridgeColors.lilacWash,
                  child: Icon(
                    Icons.headphones_rounded,
                    color: StudyBridgeColors.purple,
                  ),
                ),
                title: const Text('غرفة الدراسة الصوتية'),
                subtitle: const Text('تحدثوا معاً بالصوت فقط، بدون كاميرا.'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VoiceRoomScreen(
                      spaceId: space['id'] as String,
                      spaceName: space['name'] as String,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),
            Text(
              'جلسة التركيز المشتركة',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (active == null)
              _startCard(space)
            else
              _activeSessionCard(active),
            const SizedBox(height: 18),
            Text('آخر الجلسات', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            ...rows
                .where(
                  (r) =>
                      r['status'] == 'completed' || r['status'] == 'cancelled',
                )
                .take(6)
                .map(
                  (r) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.history_rounded,
                        color: StudyBridgeColors.purple,
                      ),
                      title: Text(
                        r['status'] == 'completed'
                            ? 'جلسة مكتملة • ${_format(r['elapsed_seconds'] as int)}'
                            : 'جلسة ملغاة',
                      ),
                      subtitle: Text(
                        'شارك الوقت مرة واحدة للمساحة • ${_format(r['duration_seconds'] as int)} مخطط',
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _membersCard(
    String spaceId,
    Future<List<Map<String, dynamic>>> future,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _errorCard(message: '${snapshot.error}');
      if (!snapshot.hasData)
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: LinearProgressIndicator(),
          ),
        );
      final members = snapshot.data!;
      final ids = members.map((m) => m['user_id'] as String).toList();
      final presence = _presenceStreams.putIfAbsent(
        spaceId,
        () => Supabase.instance.client
            .from('user_presence')
            .stream(primaryKey: ['user_id'])
            .inFilter('user_id', ids),
      );
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'الأعضاء وحالتهم',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'تغيير حالتي',
                    onSelected: (v) => _run(
                      () => ref
                          .read(studySpaceRepositoryProvider)
                          .setMyPresence(v),
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'online', child: Text('متاح')),
                      PopupMenuItem(
                        value: 'on_break',
                        child: Text('في استراحة'),
                      ),
                      PopupMenuItem(value: 'away', child: Text('بعيد')),
                    ],
                    child: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: presence,
                builder: (context, state) {
                  final rows = state.data ?? const <Map<String, dynamic>>[];
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: members.map((member) {
                      final row = rows
                          .where((p) => p['user_id'] == member['user_id'])
                          .firstOrNull;
                      var status = row?['status'] as String? ?? 'offline';
                      if (row != null) {
                        final seen = DateTime.parse(
                          row['last_seen_at'] as String,
                        ).toLocal();
                        if (DateTime.now().difference(seen) >
                            const Duration(seconds: 90))
                          status = 'offline';
                      }
                      final (label, color) = switch (status) {
                        'studying' => ('يدرس الآن', const Color(0xFF50856B)),
                        'online' => ('متاح', StudyBridgeColors.purple),
                        'on_break' => ('في استراحة', const Color(0xFFC28D43)),
                        'away' => ('بعيد', StudyBridgeColors.muted),
                        _ => ('غير متصل', StudyBridgeColors.muted),
                      };
                      return Chip(
                        avatar: Icon(Icons.circle, size: 11, color: color),
                        label: Text(
                          '${member['display_name']} • $label${member['role'] == 'owner' ? ' • مضيف' : ''}',
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _chatView(Map<String, dynamic> space) {
    final client = Supabase.instance.client;
    final stream = _chatStreams.putIfAbsent(
      space['id'] as String,
      () => client
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('space_id', space['id'])
          .order('created_at', ascending: false)
          .limit(100),
    );
    final me = client.auth.currentUser?.id;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'تعذر تحميل المحادثة: ${snapshot.error}',
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                );
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final messages = snapshot.data!;
              if (messages.isEmpty)
                return const Center(
                  child: Text('ابدأوا المحادثة برسالة لطيفة.'),
                );
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final mine = message['user_id'] == me;
                  return Align(
                    alignment: mine
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      constraints: const BoxConstraints(maxWidth: 520),
                      decoration: BoxDecoration(
                        color: mine
                            ? StudyBridgeColors.lilacWash
                            : StudyBridgeColors.surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!mine)
                            Text(
                              '${message['sender_name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: StudyBridgeColors.purple,
                              ),
                            ),
                          Text('${message['body']}'),
                          const SizedBox(height: 4),
                          Text(
                            _messageTime(message['created_at'] as String),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _working ? null : () => _sendMessage(space),
                  tooltip: 'إرسال',
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendMessage(Map<String, dynamic> space) async {
    final body = _chatController.text.trim();
    if (body.isEmpty) return;
    await _run(() async {
      await ref
          .read(studySpaceRepositoryProvider)
          .sendMessage(space['id'], body);
      _chatController.clear();
    });
  }

  String _messageTime(String raw) {
    final time = DateTime.parse(raw).toLocal();
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _startCard(Map<String, dynamic> space) => Card(
    color: StudyBridgeColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ابدأ مؤقتاً واحداً يراه كل أعضاء المساحة.'),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: _durationMinutes,
            decoration: const InputDecoration(labelText: 'مدة الجلسة'),
            items: const [
              DropdownMenuItem(value: 25, child: Text('25 دقيقة')),
              DropdownMenuItem(value: 50, child: Text('50 دقيقة')),
              DropdownMenuItem(value: 90, child: Text('90 دقيقة')),
            ],
            onChanged: (v) => setState(() => _durationMinutes = v ?? 25),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _working
                ? null
                : () => _run(
                    () => ref
                        .read(studySpaceRepositoryProvider)
                        .startSharedSession(space['id'], _durationMinutes * 60),
                  ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('ابدأ جلسة مشتركة'),
          ),
        ],
      ),
    ),
  );

  Widget _activeSessionCard(Map<String, dynamic> session) {
    final repo = ref.read(studySpaceRepositoryProvider);
    final id = session['id'] as String;
    final duration = session['duration_seconds'] as int;
    final running = session['status'] == 'running';
    final key = '$id-${session['updated_at']}';
    if (_clockKey != key && !_clockLoading) {
      _clockLoading = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _syncServerClock(session, key),
      );
    }
    final fallbackElapsed =
        (session['elapsed_seconds'] as int) +
        (running
            ? DateTime.now()
                  .toUtc()
                  .difference(
                    DateTime.parse(session['segment_started_at'] as String),
                  )
                  .inSeconds
            : 0);
    final anchoredElapsed = _clockKey == key && _sharedLocalAnchor != null
        ? _sharedElapsedAtSync +
              (running
                  ? DateTime.now().difference(_sharedLocalAnchor!).inSeconds
                  : 0)
        : fallbackElapsed;
    final elapsed = anchoredElapsed.clamp(0, duration);
    final remaining = (duration - elapsed).clamp(0, duration);
    final participants = _participantStreams.putIfAbsent(
      id,
      () => Supabase.instance.client
          .from('shared_focus_participants')
          .stream(primaryKey: ['id'])
          .eq('session_id', id)
          .order('joined_at'),
    );
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (remaining == 0 &&
        session['status'] == 'running' &&
        _clockKey == key &&
        _finishingSessionId != id) {
      _finishingSessionId = id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run(() => repo.controlSharedSession(id, 'finish'));
      });
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              session['status'] == 'paused'
                  ? 'الجلسة متوقفة مؤقتاً'
                  : 'الجلسة جارية',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 210,
              height: 210,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: duration == 0 ? 0 : remaining / duration,
                      strokeWidth: 11,
                      strokeCap: StrokeCap.round,
                      color: StudyBridgeColors.purple,
                      backgroundColor: StudyBridgeColors.lilacWash,
                    ),
                  ),
                  Text(
                    _format(remaining),
                    style: Theme.of(context).textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: participants,
              builder: (context, snapshot) {
                final list = snapshot.data ?? const <Map<String, dynamic>>[];
                final joined = list.where((p) => p['left_at'] == null).toList();
                final meJoined = joined.any((p) => p['user_id'] == userId);
                return Column(
                  children: [
                    Text(
                      'يشاركون الآن: ${joined.map((p) => p['display_name']).join('، ')}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (!meJoined)
                      OutlinedButton.icon(
                        onPressed: _working
                            ? null
                            : () => _run(() => repo.joinSharedSession(id)),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('انضم للجلسة'),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _working
                            ? null
                            : () => _run(() => repo.leaveSharedSession(id)),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('مغادرة الجلسة'),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (session['status'] == 'running')
                  OutlinedButton.icon(
                    onPressed: _working
                        ? null
                        : () => _run(
                            () => repo.controlSharedSession(id, 'pause'),
                          ),
                    icon: const Icon(Icons.pause_rounded),
                    label: const Text('إيقاف مؤقت'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _working
                        ? null
                        : () => _run(
                            () => repo.controlSharedSession(id, 'resume'),
                          ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('استئناف'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: _working
                      ? null
                      : () =>
                            _run(() => repo.controlSharedSession(id, 'finish')),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('إنهاء'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncServerClock(
    Map<String, dynamic> session,
    String key,
  ) async {
    try {
      final before = DateTime.now();
      final serverNow = await ref
          .read(studySpaceRepositoryProvider)
          .serverTime(_selected!['id']);
      final after = DateTime.now();
      final localAnchor = before.add(after.difference(before) ~/ 2);
      final running = session['status'] == 'running';
      final segment = session['segment_started_at'] == null
          ? null
          : DateTime.parse(session['segment_started_at'] as String);
      final elapsed = const SharedFocusClock().elapsedAt(
        storedElapsedSeconds: session['elapsed_seconds'] as int,
        durationSeconds: session['duration_seconds'] as int,
        running: running,
        segmentStartedAt: segment,
        serverNow: serverNow,
      );
      if (mounted)
        setState(() {
          _clockKey = key;
          _sharedElapsedAtSync = elapsed;
          _sharedLocalAnchor = localAnchor;
          _clockLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _clockLoading = false;
          _error = 'تعذر مزامنة ساعة الخادم: ';
        });
    }
  }

  Widget _errorCard({String? message}) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        message ?? 'تعذر تنفيذ العملية. تحقق من اتصال Supabase ورموز الدعوة.',
      ),
    ),
  );
  String _format(int seconds) {
    final clamped = seconds.clamp(0, 864000);
    final m = clamped ~/ 60;
    final s = clamped % 60;
    final h = m ~/ 60;
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
