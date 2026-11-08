import 'package:flutter_test/flutter_test.dart';
import 'package:studybridge/src/features/focus/data/focus_repository.dart';

void main() {
  group('FocusSession timer calculations', () {
    final start = DateTime.utc(2026, 11, 7, 12);

    test('running session subtracts the current persisted segment', () {
      final session = FocusSession(id: 'a', durationSeconds: 1500, elapsedSeconds: 120, status: 'running', startedAt: start, segmentStartedAt: start);
      expect(session.elapsedAt(start.add(const Duration(seconds: 30))), 150);
      expect(session.remainingAt(start.add(const Duration(seconds: 30))), 1350);
    });

    test('paused session keeps the stored elapsed time stable', () {
      final session = FocusSession(id: 'b', durationSeconds: 1500, elapsedSeconds: 400, status: 'paused', startedAt: start, segmentStartedAt: null);
      expect(session.elapsedAt(start.add(const Duration(hours: 1))), 400);
      expect(session.remainingAt(start.add(const Duration(hours: 1))), 1100);
    });

    test('elapsed time clamps at the planned duration', () {
      final session = FocusSession(id: 'c', durationSeconds: 60, elapsedSeconds: 50, status: 'running', startedAt: start, segmentStartedAt: start);
      expect(session.elapsedAt(start.add(const Duration(seconds: 90))), 60);
      expect(session.remainingAt(start.add(const Duration(seconds: 90))), 0);
    });
  });
}
