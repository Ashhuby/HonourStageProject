import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_app/features/auth/data/auth_repository.dart';

/// Regression tests for the offline sign-out bug.
///
/// gotrue reports a failed background token refresh as an *error* on its auth
/// state stream while keeping the session, so finishing a workout logged
/// without a connection used to drop the user on an "Auth error" screen.
void main() {
  late StreamController<AuthState> source;

  setUp(() {
    source = StreamController<AuthState>();
  });

  tearDown(() async {
    await source.close();
  });

  Session buildSession() => Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: User(
      id: 'user-1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime(2026).toIso8601String(),
    ),
  );

  test('a refresh failure keeps the user signed in', () async {
    final session = buildSession();
    final states = <AuthState>[];

    recoverableAuthStream(source.stream, () => session).listen(states.add);

    source.addError(
      AuthRetryableFetchException(
        message: 'ClientException: Failed host lookup',
      ),
    );
    await pumpEventQueue();

    expect(states, hasLength(1));
    expect(states.single.session, session);
  });

  test('a refresh failure with no session routes to signed out', () async {
    final states = <AuthState>[];

    recoverableAuthStream(source.stream, () => null).listen(states.add);

    source.addError(AuthRetryableFetchException(message: 'Failed host lookup'));
    await pumpEventQueue();

    expect(states.single.session, isNull);
  });

  test('the stream survives repeated failures and later events', () async {
    final session = buildSession();
    final states = <AuthState>[];
    var errors = 0;

    recoverableAuthStream(
      source.stream,
      () => session,
    ).listen(states.add, onError: (_) => errors++);

    source.addError(AuthRetryableFetchException(message: 'Failed host lookup'));
    source.addError(AuthRetryableFetchException(message: 'Failed host lookup'));
    source.add(AuthState(AuthChangeEvent.tokenRefreshed, session));
    await pumpEventQueue();

    expect(errors, 0, reason: 'errors must never reach listeners');
    expect(states, hasLength(3));
    expect(states.last.event, AuthChangeEvent.tokenRefreshed);
  });

  test('a genuine sign-out still passes through', () async {
    final states = <AuthState>[];

    recoverableAuthStream(source.stream, () => null).listen(states.add);

    source.add(const AuthState(AuthChangeEvent.signedOut, null));
    await pumpEventQueue();

    expect(states.single.event, AuthChangeEvent.signedOut);
    expect(states.single.session, isNull);
  });
}
