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
///
/// Routing is driven by the presence of a session, never by whether the
/// client can currently reach Supabase — the app is offline-first, and a
/// signed-in user mid-workout must stay signed in.
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      // The stream is hardened against transient network failures upstream,
      // so reaching here means something unexpected. Route on the session we
      // still hold rather than stranding the user on a dead-end error screen
      // with a workout's data sitting unsynced behind it.
      error: (_, _) =>
          ref.read(supabaseClientProvider).auth.currentSession != null
          ? const HomeScreen()
          : const AuthScreen(),
    );
  }
}
