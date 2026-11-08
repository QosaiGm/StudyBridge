import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/settings_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _avatarController;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _weekStartsOn = 1;
  bool _taskReminders = true;
  bool _overdueReminders = true;
  bool _plannerReminders = true;
  bool _sharedActivityReminders = true;
  bool _encouragement = true;
  int _reminderLeadMinutes = 15;
  bool _quietHours = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    final user = ref.read(settingsRepositoryProvider).currentUser;
    _nameController = TextEditingController(
      text: user?.userMetadata?['display_name'] as String? ?? '',
    );
    _avatarController = TextEditingController(
      text: user?.userMetadata?['avatar_url'] as String? ?? '',
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await ref.read(settingsRepositoryProvider).load();
      if (!mounted) return;
      setState(() {
        _nameController.text = settings.displayName;
        _avatarController.text = settings.avatarUrl;
        _weekStartsOn = settings.weekStartsOn;
        _taskReminders = settings.taskReminders;
        _overdueReminders = settings.overdueReminders;
        _plannerReminders = settings.plannerReminders;
        _sharedActivityReminders = settings.sharedActivityReminders;
        _encouragement = settings.encouragement;
        _reminderLeadMinutes = settings.reminderLeadMinutes;
        _quietHours = settings.quietHours;
        _quietStart = _parseTime(
          settings.quietStart,
          const TimeOfDay(hour: 22, minute: 0),
        );
        _quietEnd = _parseTime(
          settings.quietEnd,
          const TimeOfDay(hour: 7, minute: 0),
        );
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(settingsRepositoryProvider)
          .save(
            PersonalSettings(
              displayName: _nameController.text,
              avatarUrl: _avatarController.text,
              weekStartsOn: _weekStartsOn,
              taskReminders: _taskReminders,
              overdueReminders: _overdueReminders,
              plannerReminders: _plannerReminders,
              sharedActivityReminders: _sharedActivityReminders,
              encouragement: _encouragement,
              reminderLeadMinutes: _reminderLeadMinutes,
              quietHours: _quietHours,
              quietStart: _timeString(_quietStart),
              quietEnd: _timeString(_quietEnd),
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ إعداداتك.')));
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) => showTimePicker(
    context: context,
    initialTime: initial,
    helpText: 'اختر الوقت',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الإعدادات الشخصية')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                    children: [
                      if (_error != null) _errorCard(),
                      _section(
                        'ملفك الشخصي',
                        'الاسم والصورة التي تظهر لأعضاء مساحاتك.',
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              _avatarPreview(),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _nameController,
                                maxLength: 80,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'اكتب اسماً للعرض.'
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'اسم العرض',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _avatarController,
                                keyboardType: TextInputType.url,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'رابط الصورة (اختياري)',
                                  hintText: 'https://...',
                                ),
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) return null;
                                  final uri = Uri.tryParse(text);
                                  return uri != null &&
                                          (uri.scheme == 'https' ||
                                              uri.scheme == 'http') &&
                                          uri.host.isNotEmpty
                                      ? null
                                      : 'أدخل رابط صورة يبدأ بـ https://';
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _section(
                        'تفضيلات الدراسة',
                        'خصّص طريقة عرض الأسبوع في الإحصاءات.',
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: DropdownButtonFormField<int>(
                            initialValue: _weekStartsOn,
                            decoration: const InputDecoration(
                              labelText: 'أول يوم في الأسبوع',
                              border: InputBorder.none,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 1,
                                child: Text('الاثنين'),
                              ),
                              DropdownMenuItem(value: 7, child: Text('الأحد')),
                              DropdownMenuItem(value: 6, child: Text('السبت')),
                            ],
                            onChanged: (value) =>
                                setState(() => _weekStartsOn = value ?? 1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _section(
                        'التذكيرات',
                        'اختر أنواع التذكير والوقت المناسب لك.',
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            _preferenceTile(
                              'تذكير بالمهام القادمة',
                              _taskReminders,
                              (v) => setState(() => _taskReminders = v),
                            ),
                            _preferenceTile(
                              'تنبيه بالمهام المتأخرة',
                              _overdueReminders,
                              (v) => setState(() => _overdueReminders = v),
                            ),
                            _preferenceTile(
                              'جلسات المخطط الدراسي',
                              _plannerReminders,
                              (v) => setState(() => _plannerReminders = v),
                            ),
                            _preferenceTile(
                              'نشاط مساحة الدراسة',
                              _sharedActivityReminders,
                              (v) =>
                                  setState(() => _sharedActivityReminders = v),
                            ),
                            _preferenceTile(
                              'رسائل التشجيع والإنجازات',
                              _encouragement,
                              (v) => setState(() => _encouragement = v),
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                16,
                                4,
                                16,
                                14,
                              ),
                              child: DropdownButtonFormField<int>(
                                initialValue: _reminderLeadMinutes,
                                decoration: const InputDecoration(
                                  labelText: 'وقت التذكير قبل الموعد',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 0,
                                    child: Text('عند الموعد'),
                                  ),
                                  DropdownMenuItem(
                                    value: 5,
                                    child: Text('قبل 5 دقائق'),
                                  ),
                                  DropdownMenuItem(
                                    value: 15,
                                    child: Text('قبل 15 دقيقة'),
                                  ),
                                  DropdownMenuItem(
                                    value: 30,
                                    child: Text('قبل 30 دقيقة'),
                                  ),
                                  DropdownMenuItem(
                                    value: 60,
                                    child: Text('قبل ساعة'),
                                  ),
                                  DropdownMenuItem(
                                    value: 1440,
                                    child: Text('قبل يوم'),
                                  ),
                                ],
                                onChanged: (value) => setState(
                                  () => _reminderLeadMinutes = value ?? 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              value: _quietHours,
                              onChanged: (value) =>
                                  setState(() => _quietHours = value),
                              title: const Text('ساعات الهدوء'),
                              subtitle: const Text(
                                'لا ترسل تذكيرات خلال هذه الفترة.',
                              ),
                              activeThumbColor: StudyBridgeColors.gold,
                            ),
                            if (_quietHours)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          final time = await _pickTime(
                                            _quietStart,
                                          );
                                          if (time != null && mounted)
                                            setState(() => _quietStart = time);
                                        },
                                        icon: const Icon(
                                          Icons.bedtime_outlined,
                                        ),
                                        label: Text(
                                          'من ${_quietStart.format(context)}',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          final time = await _pickTime(
                                            _quietEnd,
                                          );
                                          if (time != null && mounted)
                                            setState(() => _quietEnd = time);
                                        },
                                        icon: const Icon(
                                          Icons.wb_sunny_outlined,
                                        ),
                                        label: Text(
                                          'حتى ${_quietEnd.format(context)}',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'تُحفظ هذه التفضيلات في حسابك. توصيل التنبيهات إلى الجهاز يحتاج تفعيل خدمة الإشعارات.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _saving ? 'جارٍ الحفظ...' : 'حفظ الإعدادات',
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    ),
  );

  Widget _avatarPreview() {
    final url = _avatarController.text.trim();
    final uri = Uri.tryParse(url);
    final valid =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    return CircleAvatar(
      radius: 38,
      backgroundColor: StudyBridgeColors.lilacWash,
      backgroundImage: valid ? NetworkImage(url) : null,
      child: valid
          ? null
          : const Icon(
              Icons.person_rounded,
              size: 38,
              color: StudyBridgeColors.gold,
            ),
    );
  }

  Widget _section(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );

  Widget _preferenceTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) => SwitchListTile.adaptive(
    value: value,
    onChanged: onChanged,
    title: Text(title),
    activeThumbColor: StudyBridgeColors.gold,
  );

  Widget _errorCard() => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        _error!.contains('user_settings') ||
                _error!.contains('notification_preferences')
            ? 'حدّث قاعدة البيانات أولاً: استخدم ملف SQL الكامل الأخير من مشروع StudyBridge.'
            : 'تعذر تحميل الإعدادات: $_error',
        textDirection: TextDirection.rtl,
      ),
    ),
  );

  static TimeOfDay _parseTime(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length < 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59)
      return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _timeString(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
}
