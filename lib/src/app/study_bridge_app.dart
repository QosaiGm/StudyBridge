import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/theme/app_theme.dart';
import 'app_router.dart';

class StudyBridgeApp extends ConsumerStatefulWidget {
  const StudyBridgeApp({super.key});
  @override
  ConsumerState<StudyBridgeApp> createState() => _StudyBridgeAppState();
}

class _StudyBridgeAppState extends ConsumerState<StudyBridgeApp>
    with WidgetsBindingObserver {
  Timer? _heartbeatTimer;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (SupabaseConfig.isConfigured) {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession != null) _heartbeat();
      _authSubscription = auth.onAuthStateChange.listen((event) {
        if (event.session != null) _heartbeat();
      });
      _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 45),
        (_) => _heartbeat(),
      );
    }
  }

  Future<void> _heartbeat() async {
    if (!SupabaseConfig.isConfigured ||
        Supabase.instance.client.auth.currentSession == null)
      return;
    try {
      await Supabase.instance.client.rpc('heartbeat_my_presence');
    } catch (_) {
      /* Presence is best-effort while offline. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _heartbeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'StudyBridge',
    debugShowCheckedModeBanner: false,
    theme: StudyBridgeTheme.dark,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: ref.watch(appRouterProvider),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}
