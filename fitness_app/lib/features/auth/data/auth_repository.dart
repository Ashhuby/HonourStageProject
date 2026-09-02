import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_service.dart';

/// Wraps a gotrue auth stream so a network failure cannot look like a
/// sign-out.
///
/// gotrue's background token refresh pushes failures onto
/// [GoTrueClient.onAuthStateChange] as stream *errors*. For a retryable
/// failure — which is what a lost connection produces — it deliberately keeps
/// the session and retries later, so the user is still signed in. A workout
/// logged offline for longer than the access token's lifetime therefore
/// raises an error on a perfectly valid session.
///
/// Those errors are swallowed and replaced with the session still held, so
/// listeners route on real auth state rather than on connectivity. A failure
/// that genuinely invalidates the session arrives separately as a signed-out
/// event, which passes through untouched.
Stream<AuthState> recoverableAuthStream(
  Stream<AuthState> source,
  Session? Function() currentSession,
) {
  return source.transform(
    StreamTransformer<AuthState, AuthState>.fromHandlers(
      handleError: (error, stackTrace, sink) {
        sink.add(AuthState(AuthChangeEvent.initialSession, currentSession()));
      },
    ),
  );
}

class AuthRepository {
  final SupabaseClient _client;
  final AppDatabase _db;

  AuthRepository(this._client, this._db);

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => recoverableAuthStream(
    _client.auth.onAuthStateChange,
    () => _client.auth.currentSession,
  );

  Future<void> signUp({required String email, required String password}) async {
    try {
      await _client.auth.signUp(email: email, password: password);
      // New account — no data to download, local DB is already clean.
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      // Download this user's data into the local DB.
      final syncService = SyncService(db: _db, supabase: _client);
      await syncService.downloadUserData();
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> signOut() async {
    // Clear local data before signing out so the next user
    // starts with a clean slate.
    final syncService = SyncService(db: _db, supabase: _client);
    await syncService.clearLocalData();
    await _client.auth.signOut();
  }
}
