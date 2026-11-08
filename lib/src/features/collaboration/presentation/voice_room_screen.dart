import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';

class VoiceRoomScreen extends StatefulWidget {
  const VoiceRoomScreen({
    required this.spaceId,
    required this.spaceName,
    super.key,
  });

  final String spaceId;
  final String spaceName;

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _events;
  bool _connecting = true;
  bool _connected = false;
  bool _micEnabled = false;
  bool _audioUnlocked = false;
  bool _remoteAudioEnabled = true;
  bool _speakerPreferred = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  Future<void> _connect() async {
    try {
      final result = await Supabase.instance.client.functions.invoke(
        'livekit-token',
        body: {'spaceId': widget.spaceId},
      );
      if (result.status < 200 || result.status >= 300) {
        final detail = result.data is Map ? result.data['error'] : null;
        throw Exception(detail ?? 'تعذر الحصول على صلاحية غرفة الصوت.');
      }
      final data = Map<String, dynamic>.from(result.data as Map);
      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _room = room;
      _events = room.createListener()
        ..on<RoomDisconnectedEvent>((_) {
          if (mounted) setState(() => _connected = false);
        });
      room.addListener(_onRoomChanged);
      await room.connect(data['serverUrl'] as String, data['token'] as String);
      if (!mounted) {
        await room.disconnect();
        return;
      }
      setState(() {
        _connected = true;
        _connecting = false;
      });
      // Explicitly start web audio playback after the user entered this room.
      await room.startAudio();
      _audioUnlocked = room.canPlaybackAudio;
      if (!kIsWeb) {
        await AudioManager.instance.setSpeakerOutputPreferred(true);
      }
      await _setMicrophone(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = _friendlyError(error);
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('Permission') ||
        message.contains('permission') ||
        message.contains('NotAllowedError')) {
      return 'يلزم السماح باستخدام الميكروفون من إعدادات المتصفح أو الجهاز.';
    }
    if (message.contains('404') || message.contains('Function not found')) {
      return 'خدمة غرفة الصوت لم تُنشر بعد في Supabase.';
    }
    return message.replaceFirst('Exception: ', '');
  }

  void _onRoomChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _setMicrophone(bool enabled) async {
    final room = _room;
    if (room?.localParticipant == null) return;
    try {
      await room!.localParticipant!.setMicrophoneEnabled(enabled);
      if (mounted) setState(() => _micEnabled = enabled);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _toggleSpeakerRoute() async {
    final next = !_speakerPreferred;
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(next);
      if (mounted) setState(() => _speakerPreferred = next);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _enableAudioFromUserGesture() async {
    final room = _room;
    if (room == null) return;
    try {
      // Browsers may block autoplay after the async token request. Calling this
      // from the button tap gives the browser a fresh user gesture to unlock it.
      await room.startAudio();
      for (final participant in room.remoteParticipants.values) {
        for (final publication in participant.audioTrackPublications) {
          final track = publication.track;
          if (track != null) await track.start();
        }
      }
      if (mounted) setState(() => _audioUnlocked = true);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _toggleRemoteAudio() async {
    final next = !_remoteAudioEnabled;
    final publications =
        _room?.remoteParticipants.values.expand(
          (participant) => participant.audioTrackPublications,
        ) ??
        const <RemoteTrackPublication<RemoteAudioTrack>>[];
    try {
      for (final publication in publications) {
        final track = publication.track;
        if (track == null) continue;
        if (next) {
          await track.start();
        } else {
          await track.stop();
        }
      }
      if (mounted) setState(() => _remoteAudioEnabled = next);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  @override
  void dispose() {
    _room?.removeListener(_onRoomChanged);
    _events?.dispose();
    final room = _room;
    if (room != null) unawaited(room.disconnect());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final participants =
        _room?.remoteParticipants.values.toList() ??
        const <RemoteParticipant>[];
    final local = _room?.localParticipant;
    return Scaffold(
      appBar: AppBar(
        title: Text('غرفة صوتية • ${widget.spaceName}'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _connecting
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('جارٍ الاتصال بغرفة الصوت...'),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: StudyBridgeColors.elevated,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _connected
                                  ? Icons.graphic_eq_rounded
                                  : Icons.headset_off_rounded,
                              size: 56,
                              color: StudyBridgeColors.purple,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _connected
                                  ? 'أنت في غرفة الدراسة الصوتية'
                                  : 'انتهى الاتصال',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _connected ? 'الصوت خاص بأعضاء هذه المساحة.' : 'يمكنك العودة إلى المساحة والمحاولة مرة أخرى.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      if (_error != null)
                        Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(_error!),
                          ),
                        ),
                      const SizedBox(height: 18),
                      Text(
                        'الموجودون في الغرفة',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Card(
                        child: Column(
                          children: [
                            if (local != null)
                              ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person),
                                ),
                                title: Text(
                                  '${local.name.isEmpty ? 'أنت' : local.name} (أنت)',
                                ),
                                trailing: Icon(
                                  _micEnabled
                                      ? Icons.mic_rounded
                                      : Icons.mic_off_rounded,
                                  color: _micEnabled
                                      ? StudyBridgeColors.purple
                                      : StudyBridgeColors.muted,
                                ),
                              ),
                            ...participants.map(
                              (person) => ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person_outline_rounded),
                                ),
                                title: Text(
                                  person.name.isEmpty ? 'عضو' : person.name,
                                ),
                                trailing: const Icon(
                                  Icons.graphic_eq_rounded,
                                  color: StudyBridgeColors.purple,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (kIsWeb)
                            OutlinedButton.icon(
                              onPressed: _connected
                                  ? _enableAudioFromUserGesture
                                  : null,
                              icon: Icon(
                                _audioUnlocked
                                    ? Icons.volume_up_rounded
                                    : Icons.play_circle_outline_rounded,
                              ),
                              label: Text(
                                _audioUnlocked
                                    ? 'إعادة تفعيل صوت الآخرين'
                                    : 'تفعيل صوت الآخرين',
                              ),
                            ),
                          FilledButton.icon(
                            onPressed: _connected
                                ? () => _setMicrophone(!_micEnabled)
                                : null,
                            icon: Icon(
                              _micEnabled
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                            ),
                            label: Text(
                              _micEnabled
                                  ? 'كتم الميكروفون'
                                  : 'تشغيل الميكروفون',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _connected ? _toggleRemoteAudio : null,
                            icon: Icon(
                              _remoteAudioEnabled
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                            ),
                            label: Text(
                              _remoteAudioEnabled
                                  ? 'كتم صوت الآخرين'
                                  : 'تشغيل صوت الآخرين',
                            ),
                          ),
                          if (!kIsWeb)
                            OutlinedButton.icon(
                              onPressed: _connected
                                  ? _toggleSpeakerRoute
                                  : null,
                              icon: Icon(
                                _speakerPreferred
                                    ? Icons.volume_up_rounded
                                    : Icons.headphones_rounded,
                              ),
                              label: Text(
                                _speakerPreferred
                                    ? 'مخرج الصوت: مكبر'
                                    : 'مخرج الصوت: سماعة',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        kIsWeb
                            ? 'اسمح للمتصفح باستخدام الميكروفون. إذا لم تسمع الأعضاء، اضغط «تفعيل صوت الآخرين» بعد الانضمام.'
                            : 'يمكنك كتم الميكروفون أو صوت الآخرين بشكل منفصل. اختيار مخرج الصوت متاح على Android وiOS.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: StudyBridgeColors.muted),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
