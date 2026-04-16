import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../auth/providers/auth_providers.dart';
import '../../workout/presentation/home_screen.dart';

/// Root routing widget.
///
/// Watches the Supabase auth stream and routes to [HomeScreen] when a
/// session is active, or [AuthScreen] when signed out. Using a stream
/// provider here means any auth state change — sign-in, sign-out, token
/// expiry — is handled automatically without explicit navigation calls.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (state) {
        if (state.session != null) return const HomeScreen();
        return const AuthScreen();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Auth error: $e')),
      ),
    );
  }
}