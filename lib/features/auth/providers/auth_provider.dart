import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/app_user.dart';
import '../../../core/services/auth_service.dart';

class AuthNotifierState {
  final bool isLoading;
  final String? error;

  const AuthNotifierState({this.isLoading = false, this.error});

  AuthNotifierState copyWith({bool? isLoading, String? error}) =>
      AuthNotifierState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthNotifierState> {
  AuthNotifier(this._authService) : super(const AuthNotifierState());

  final AuthService _authService;

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.signInWithApple();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AuthNotifierState();
  }

  Future<void> updateProfile({required String displayName}) async {
    try {
      await _authService.upsertProfile(displayName: displayName);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthNotifierState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});

/// Current authenticated Supabase user profile.
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  // Re-fetch whenever auth state changes
  final _ = ref.watch(supabaseAuthStateProvider);
  return ref.watch(authServiceProvider).fetchProfile();
});

/// Raw Supabase auth state stream.
final supabaseAuthStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});
