import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signUp(email: email, password: password);
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}