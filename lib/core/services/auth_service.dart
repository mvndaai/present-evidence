import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import 'supabase_service.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentSession != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign in with Google OAuth.
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.presentevidence://login-callback/',
    );
  }

  /// Sign in with Apple OAuth.
  Future<void> signInWithApple() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.supabase.presentevidence://login-callback/',
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Upsert the user's profile record after login.
  Future<AppUser> upsertProfile({
    required String displayName,
  }) async {
    final userId = currentUser!.id;
    final email = currentUser!.email!;
    final data = {
      'id': userId,
      'email': email,
      'display_name': displayName,
    };
    final result = await _client
        .from('users')
        .upsert(data, onConflict: 'id')
        .select()
        .single();
    return AppUser.fromMap(result);
  }

  /// Fetch the current user's profile.
  Future<AppUser?> fetchProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;
    final result = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (result == null) return null;
    return AppUser.fromMap(result);
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});
