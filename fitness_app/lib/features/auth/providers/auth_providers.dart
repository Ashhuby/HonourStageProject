import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';

part 'auth_providers.g.dart';

@riverpod
SupabaseClient supabaseClient(Ref ref) {
  return Supabase.instance.client;
}

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
}

@riverpod
Stream<AuthState> authStateChanges(Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
}