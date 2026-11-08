import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studybridge/src/app/study_bridge_app.dart';

void main() {
  testWidgets('shows Arabic sign-in while Supabase is not configured', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudyBridgeApp()));
    await tester.pumpAndSettle();

    expect(find.text('StudyBridge'), findsOneWidget);
    expect(find.text('مرحباً بعودتك'), findsOneWidget);
    expect(find.textContaining('واجهة الحساب جاهزة'), findsOneWidget);
  });
}
