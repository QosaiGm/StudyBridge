import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/academics/presentation/academics_screen.dart';
import '../features/focus/presentation/focus_screen.dart';
import '../features/collaboration/presentation/study_space_screen.dart';
import '../features/insights/presentation/insights_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = SupabaseConfig.isConfigured
      ? _AuthStateRefresh(Supabase.instance.client.auth.onAuthStateChange)
      : null;

  final router = GoRouter(
    refreshListenable: authRefresh,
    initialLocation: _hasSession ? '/home' : '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/academics',
        builder: (context, state) => const AcademicsScreen(),
      ),
      GoRoute(path: '/focus', builder: (context, state) => const FocusScreen()),
      GoRoute(
        path: '/study-space',
        builder: (context, state) => const StudySpaceScreen(),
      ),
      GoRoute(
        path: '/insights',
        builder: (context, state) => const InsightsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    redirect: (context, state) {
      final signedIn = _hasSession;
      final needsSession = {
        '/home',
        '/academics',
        '/focus',
        '/study-space',
        '/insights',
        '/settings',
      }.contains(state.matchedLocation);

      if (state.matchedLocation == '/') {
        return signedIn ? '/home' : '/login';
      }
      if (needsSession && !signedIn) return '/login';
      if (state.matchedLocation == '/login' && signedIn) return '/home';
      return null;
    },
  );

  ref.onDispose(() {
    router.dispose();
    authRefresh?.dispose();
  });

  return router;
});

bool get _hasSession =>
    SupabaseConfig.isConfigured &&
    Supabase.instance.client.auth.currentSession != null;

class _AuthStateRefresh extends ChangeNotifier {
  _AuthStateRefresh(Stream<AuthState> authEvents) {
    _subscription = authEvents.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
