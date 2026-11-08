import 'package:flutter_test/flutter_test.dart';
import 'package:studybridge/src/features/collaboration/data/study_space_repository.dart';

void main() {
  test('shared timer derives elapsed time from the server segment timestamp', () {
    final segment = DateTime.utc(2026, 11, 7, 12);
    final clock = const SharedFocusClock();
    expect(clock.remainingAt(storedElapsedSeconds: 300, durationSeconds: 1500, running: true, segmentStartedAt: segment, serverNow: segment.add(const Duration(seconds: 25))), 1175);
  });

  test('paused shared timer remains stable until the server resumes it', () {
    final clock = const SharedFocusClock();
    expect(clock.remainingAt(storedElapsedSeconds: 420, durationSeconds: 1500, running: false, segmentStartedAt: null, serverNow: DateTime.utc(2026, 11, 7).add(const Duration(hours: 2))), 1080);
  });
}
