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
  final hasSession =
      SupabaseConfig.isConfigured &&
      Supabase.instance.client.auth.currentSession != null;
  return GoRouter(
    initialLocation: hasSession ? '/home' : '/login',
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
      if (state.matchedLocation == '/') return hasSession ? '/home' : '/login';
      if ((state.matchedLocation == '/home' ||
              state.matchedLocation == '/academics' ||
              state.matchedLocation == '/focus' ||
              state.matchedLocation == '/study-space' ||
              state.matchedLocation == '/insights' ||
              state.matchedLocation == '/settings') &&
          !hasSession)
        return '/login';
      if (state.matchedLocation == '/login' && hasSession) return '/home';
      return null;
    },
  );
});
