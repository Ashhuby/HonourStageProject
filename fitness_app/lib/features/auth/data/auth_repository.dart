import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_service.dart';

class AuthRepository {
  final SupabaseClient _client;
  final AppDatabase _db;

  AuthRepository(this._client, this._db);

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

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
