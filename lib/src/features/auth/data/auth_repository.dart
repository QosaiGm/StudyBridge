import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      SupabaseConfig.isConfigured ? Supabase.instance.client : null,
    ));

class AuthRepository {
  const AuthRepository(this._client);
  final SupabaseClient? _client;

  bool get isConfigured => _client != null;

  Future<void> signIn({required String email, required String password}) async {
    await _requireClient().auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signUp({required String displayName, required String email, required String password}) async {
    await _requireClient().auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
  }

  Future<void> resetPassword(String email) async {
    await _requireClient().auth.resetPasswordForEmail(email.trim());
  }

  Future<void> signOut() async {
    final client = _requireClient();
    try { await client.rpc('set_my_presence', params: {'p_status': 'offline'}); } catch (_) { /* Presence is best-effort. */ }
    await client.auth.signOut();
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) throw StateError('إعدادات Supabase غير مكتملة.');
    return client;
  }
}

