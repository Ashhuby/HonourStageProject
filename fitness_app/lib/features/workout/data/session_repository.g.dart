// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$getProgressSeriesForExerciseHash() =>
    r'36a4492adf800d801a39b9b807cb71fe128f7dd0';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [getProgressSeriesForExercise].
@ProviderFor(getProgressSeriesForExercise)
const getProgressSeriesForExerciseProvider =
    GetProgressSeriesForExerciseFamily();

/// See also [getProgressSeriesForExercise].
class GetProgressSeriesForExerciseFamily
    extends Family<AsyncValue<ExerciseProgress>> {
  /// See also [getProgressSeriesForExercise].
  const GetProgressSeriesForExerciseFamily();

  /// See also [getProgressSeriesForExercise].
  GetProgressSeriesForExerciseProvider call(int exerciseId) {
    return GetProgressSeriesForExerciseProvider(exerciseId);
  }

  @override
  GetProgressSeriesForExerciseProvider getProviderOverride(
    covariant GetProgressSeriesForExerciseProvider provider,
  ) {
    return call(provider.exerciseId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getProgressSeriesForExerciseProvider';
}

/// See also [getProgressSeriesForExercise].
class GetProgressSeriesForExerciseProvider
    extends AutoDisposeFutureProvider<ExerciseProgress> {
  /// See also [getProgressSeriesForExercise].
  GetProgressSeriesForExerciseProvider(int exerciseId)
    : this._internal(
        (ref) => getProgressSeriesForExercise(
          ref as GetProgressSeriesForExerciseRef,
          exerciseId,
        ),
        from: getProgressSeriesForExerciseProvider,
        name: r'getProgressSeriesForExerciseProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$getProgressSeriesForExerciseHash,
        dependencies: GetProgressSeriesForExerciseFamily._dependencies,
        allTransitiveDependencies:
            GetProgressSeriesForExerciseFamily._allTransitiveDependencies,
        exerciseId: exerciseId,
      );

  GetProgressSeriesForExerciseProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.exerciseId,
  }) : super.internal();

  final int exerciseId;

  @override
  Override overrideWith(
    FutureOr<ExerciseProgress> Function(
      GetProgressSeriesForExerciseRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetProgressSeriesForExerciseProvider._internal(
        (ref) => create(ref as GetProgressSeriesForExerciseRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        exerciseId: exerciseId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ExerciseProgress> createElement() {
    return _GetProgressSeriesForExerciseProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetProgressSeriesForExerciseProvider &&
        other.exerciseId == exerciseId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, exerciseId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetProgressSeriesForExerciseRef
    on AutoDisposeFutureProviderRef<ExerciseProgress> {
  /// The parameter `exerciseId` of this provider.
  int get exerciseId;
}

class _GetProgressSeriesForExerciseProviderElement
    extends AutoDisposeFutureProviderElement<ExerciseProgress>
    with GetProgressSeriesForExerciseRef {
  _GetProgressSeriesForExerciseProviderElement(super.provider);

  @override
  int get exerciseId =>
      (origin as GetProgressSeriesForExerciseProvider).exerciseId;
}

String _$getAttendanceDataHash() => r'3cac6246a31b12e502c48c537e8049e60ae0353b';

/// See also [getAttendanceData].
@ProviderFor(getAttendanceData)
final getAttendanceDataProvider =
    AutoDisposeStreamProvider<Map<DateTime, int>>.internal(
      getAttendanceData,
      name: r'getAttendanceDataProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$getAttendanceDataHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GetAttendanceDataRef = AutoDisposeStreamProviderRef<Map<DateTime, int>>;
String _$getWeeklyStreakHash() => r'8789c341e4e0f7b4808db0944dc11e422577dc6b';

/// See also [getWeeklyStreak].
@ProviderFor(getWeeklyStreak)
final getWeeklyStreakProvider = AutoDisposeFutureProvider<int>.internal(
  getWeeklyStreak,
  name: r'getWeeklyStreakProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$getWeeklyStreakHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GetWeeklyStreakRef = AutoDisposeFutureProviderRef<int>;
String _$watchCompletedSessionDetailsHash() =>
    r'95ca80ee815ad3c3bf8155b29b1f6096cb89a0a8';

/// Completed sessions, newest first, each named by its routine and split.
///
/// Left outer joins throughout: a freestyle session has no routine, and a
/// routine-backed one may point at a routine that no longer exists. Follows
/// the shape of [watchActiveSession], which does the same join one level
/// shallower.
///
/// Copied from [watchCompletedSessionDetails].
@ProviderFor(watchCompletedSessionDetails)
final watchCompletedSessionDetailsProvider =
    AutoDisposeStreamProvider<List<CompletedSession>>.internal(
      watchCompletedSessionDetails,
      name: r'watchCompletedSessionDetailsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$watchCompletedSessionDetailsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WatchCompletedSessionDetailsRef =
    AutoDisposeStreamProviderRef<List<CompletedSession>>;
String _$watchSessionHighlightsHash() =>
    r'af0867e5d672941d3ea5e7b4963635c1c40b2af6';

/// What each session achieved — records set, exercises tried for the first
/// time, badges earned.
///
/// One pass over the whole history rather than a query per session. That is
/// not only cheaper: a personal-best verdict for one session depends on every
/// set logged before it, so a per-session query would rescan all of history
/// anyway — and the history list is a `shrinkWrap` list with no viewport
/// culling, so every row builds on every frame.
///
/// The population deliberately matches `recalculateForExercise`: non-deleted
/// sets in non-deleted sessions, **including sessions still in progress**,
/// because `logSet` awards records immediately. Filtering to completed
/// sessions happens when rendering; doing it here would let these verdicts
/// disagree with the records table.
///
/// Copied from [watchSessionHighlights].
@ProviderFor(watchSessionHighlights)
final watchSessionHighlightsProvider =
    AutoDisposeStreamProvider<Map<int, SessionHighlights>>.internal(
      watchSessionHighlights,
      name: r'watchSessionHighlightsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$watchSessionHighlightsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WatchSessionHighlightsRef =
    AutoDisposeStreamProviderRef<Map<int, SessionHighlights>>;
String _$watchSetsForSessionHash() =>
    r'f73dbdc7180a58080618a3d25695b3985063fb74';

/// See also [watchSetsForSession].
@ProviderFor(watchSetsForSession)
const watchSetsForSessionProvider = WatchSetsForSessionFamily();

/// See also [watchSetsForSession].
class WatchSetsForSessionFamily
    extends Family<AsyncValue<List<WorkoutSetWithExercise>>> {
  /// See also [watchSetsForSession].
  const WatchSetsForSessionFamily();

  /// See also [watchSetsForSession].
  WatchSetsForSessionProvider call(int sessionId) {
    return WatchSetsForSessionProvider(sessionId);
  }

  @override
  WatchSetsForSessionProvider getProviderOverride(
    covariant WatchSetsForSessionProvider provider,
  ) {
    return call(provider.sessionId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'watchSetsForSessionProvider';
}

/// See also [watchSetsForSession].
class WatchSetsForSessionProvider
    extends AutoDisposeStreamProvider<List<WorkoutSetWithExercise>> {
  /// See also [watchSetsForSession].
  WatchSetsForSessionProvider(int sessionId)
    : this._internal(
        (ref) => watchSetsForSession(ref as WatchSetsForSessionRef, sessionId),
        from: watchSetsForSessionProvider,
        name: r'watchSetsForSessionProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$watchSetsForSessionHash,
        dependencies: WatchSetsForSessionFamily._dependencies,
        allTransitiveDependencies:
            WatchSetsForSessionFamily._allTransitiveDependencies,
        sessionId: sessionId,
      );

  WatchSetsForSessionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sessionId,
  }) : super.internal();

  final int sessionId;

  @override
  Override overrideWith(
    Stream<List<WorkoutSetWithExercise>> Function(
      WatchSetsForSessionRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchSetsForSessionProvider._internal(
        (ref) => create(ref as WatchSetsForSessionRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sessionId: sessionId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<WorkoutSetWithExercise>>
  createElement() {
    return _WatchSetsForSessionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchSetsForSessionProvider && other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sessionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WatchSetsForSessionRef
    on AutoDisposeStreamProviderRef<List<WorkoutSetWithExercise>> {
  /// The parameter `sessionId` of this provider.
  int get sessionId;
}

class _WatchSetsForSessionProviderElement
    extends AutoDisposeStreamProviderElement<List<WorkoutSetWithExercise>>
    with WatchSetsForSessionRef {
  _WatchSetsForSessionProviderElement(super.provider);

  @override
  int get sessionId => (origin as WatchSetsForSessionProvider).sessionId;
}

String _$watchActiveSessionHash() =>
    r'2156f0148a40c65109b1d7e921635eb8ab53464b';

/// The session currently in progress, or null when there is none.
///
/// A session with no [WorkoutSessions.endTime] is in progress: it is skipped
/// by sync and by every history query, so without a way back into it the
/// workout is stranded. Killing the app mid-set is the common cause.
///
/// The most recent one wins if several were left open by older builds.
///
/// Copied from [watchActiveSession].
@ProviderFor(watchActiveSession)
final watchActiveSessionProvider =
    AutoDisposeStreamProvider<ActiveSession?>.internal(
      watchActiveSession,
      name: r'watchActiveSessionProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$watchActiveSessionHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WatchActiveSessionRef = AutoDisposeStreamProviderRef<ActiveSession?>;
String _$watchSetCountForSessionHash() =>
    r'102ba1b294993f83a8a3226b8943d2fb88792821';

/// How many sets have been logged in [sessionId].
///
/// Copied from [watchSetCountForSession].
@ProviderFor(watchSetCountForSession)
const watchSetCountForSessionProvider = WatchSetCountForSessionFamily();

/// How many sets have been logged in [sessionId].
///
/// Copied from [watchSetCountForSession].
class WatchSetCountForSessionFamily extends Family<AsyncValue<int>> {
  /// How many sets have been logged in [sessionId].
  ///
  /// Copied from [watchSetCountForSession].
  const WatchSetCountForSessionFamily();

  /// How many sets have been logged in [sessionId].
  ///
  /// Copied from [watchSetCountForSession].
  WatchSetCountForSessionProvider call(int sessionId) {
    return WatchSetCountForSessionProvider(sessionId);
  }

  @override
  WatchSetCountForSessionProvider getProviderOverride(
    covariant WatchSetCountForSessionProvider provider,
  ) {
    return call(provider.sessionId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'watchSetCountForSessionProvider';
}

/// How many sets have been logged in [sessionId].
///
/// Copied from [watchSetCountForSession].
class WatchSetCountForSessionProvider extends AutoDisposeStreamProvider<int> {
  /// How many sets have been logged in [sessionId].
  ///
  /// Copied from [watchSetCountForSession].
  WatchSetCountForSessionProvider(int sessionId)
    : this._internal(
        (ref) => watchSetCountForSession(
          ref as WatchSetCountForSessionRef,
          sessionId,
        ),
        from: watchSetCountForSessionProvider,
        name: r'watchSetCountForSessionProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$watchSetCountForSessionHash,
        dependencies: WatchSetCountForSessionFamily._dependencies,
        allTransitiveDependencies:
            WatchSetCountForSessionFamily._allTransitiveDependencies,
        sessionId: sessionId,
      );

  WatchSetCountForSessionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sessionId,
  }) : super.internal();

  final int sessionId;

  @override
  Override overrideWith(
    Stream<int> Function(WatchSetCountForSessionRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchSetCountForSessionProvider._internal(
        (ref) => create(ref as WatchSetCountForSessionRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sessionId: sessionId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<int> createElement() {
    return _WatchSetCountForSessionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchSetCountForSessionProvider &&
        other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sessionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WatchSetCountForSessionRef on AutoDisposeStreamProviderRef<int> {
  /// The parameter `sessionId` of this provider.
  int get sessionId;
}

class _WatchSetCountForSessionProviderElement
    extends AutoDisposeStreamProviderElement<int>
    with WatchSetCountForSessionRef {
  _WatchSetCountForSessionProviderElement(super.provider);

  @override
  int get sessionId => (origin as WatchSetCountForSessionProvider).sessionId;
}

String _$watchLastPerformanceForExerciseHash() =>
    r'8bc06820c55439b79d4559d17cca049f7f0fc508';

/// Sets logged for [exerciseId] in the most recent completed session, ignoring
/// [currentSessionId] so the session in progress never reports back to itself.
///
/// Emits null when the exercise has not been logged in a completed session.
///
/// Copied from [watchLastPerformanceForExercise].
@ProviderFor(watchLastPerformanceForExercise)
const watchLastPerformanceForExerciseProvider =
    WatchLastPerformanceForExerciseFamily();

/// Sets logged for [exerciseId] in the most recent completed session, ignoring
/// [currentSessionId] so the session in progress never reports back to itself.
///
/// Emits null when the exercise has not been logged in a completed session.
///
/// Copied from [watchLastPerformanceForExercise].
class WatchLastPerformanceForExerciseFamily
    extends Family<AsyncValue<LastSessionPerformance?>> {
  /// Sets logged for [exerciseId] in the most recent completed session, ignoring
  /// [currentSessionId] so the session in progress never reports back to itself.
  ///
  /// Emits null when the exercise has not been logged in a completed session.
  ///
  /// Copied from [watchLastPerformanceForExercise].
  const WatchLastPerformanceForExerciseFamily();

  /// Sets logged for [exerciseId] in the most recent completed session, ignoring
  /// [currentSessionId] so the session in progress never reports back to itself.
  ///
  /// Emits null when the exercise has not been logged in a completed session.
  ///
  /// Copied from [watchLastPerformanceForExercise].
  WatchLastPerformanceForExerciseProvider call(
    int exerciseId,
    int currentSessionId,
  ) {
    return WatchLastPerformanceForExerciseProvider(
      exerciseId,
      currentSessionId,
    );
  }

  @override
  WatchLastPerformanceForExerciseProvider getProviderOverride(
    covariant WatchLastPerformanceForExerciseProvider provider,
  ) {
    return call(provider.exerciseId, provider.currentSessionId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'watchLastPerformanceForExerciseProvider';
}

/// Sets logged for [exerciseId] in the most recent completed session, ignoring
/// [currentSessionId] so the session in progress never reports back to itself.
///
/// Emits null when the exercise has not been logged in a completed session.
///
/// Copied from [watchLastPerformanceForExercise].
class WatchLastPerformanceForExerciseProvider
    extends AutoDisposeStreamProvider<LastSessionPerformance?> {
  /// Sets logged for [exerciseId] in the most recent completed session, ignoring
  /// [currentSessionId] so the session in progress never reports back to itself.
  ///
  /// Emits null when the exercise has not been logged in a completed session.
  ///
  /// Copied from [watchLastPerformanceForExercise].
  WatchLastPerformanceForExerciseProvider(int exerciseId, int currentSessionId)
    : this._internal(
        (ref) => watchLastPerformanceForExercise(
          ref as WatchLastPerformanceForExerciseRef,
          exerciseId,
          currentSessionId,
        ),
        from: watchLastPerformanceForExerciseProvider,
        name: r'watchLastPerformanceForExerciseProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$watchLastPerformanceForExerciseHash,
        dependencies: WatchLastPerformanceForExerciseFamily._dependencies,
        allTransitiveDependencies:
            WatchLastPerformanceForExerciseFamily._allTransitiveDependencies,
        exerciseId: exerciseId,
        currentSessionId: currentSessionId,
      );

  WatchLastPerformanceForExerciseProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.exerciseId,
    required this.currentSessionId,
  }) : super.internal();

  final int exerciseId;
  final int currentSessionId;

  @override
  Override overrideWith(
    Stream<LastSessionPerformance?> Function(
      WatchLastPerformanceForExerciseRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchLastPerformanceForExerciseProvider._internal(
        (ref) => create(ref as WatchLastPerformanceForExerciseRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        exerciseId: exerciseId,
        currentSessionId: currentSessionId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<LastSessionPerformance?> createElement() {
    return _WatchLastPerformanceForExerciseProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchLastPerformanceForExerciseProvider &&
        other.exerciseId == exerciseId &&
        other.currentSessionId == currentSessionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, exerciseId.hashCode);
    hash = _SystemHash.combine(hash, currentSessionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WatchLastPerformanceForExerciseRef
    on AutoDisposeStreamProviderRef<LastSessionPerformance?> {
  /// The parameter `exerciseId` of this provider.
  int get exerciseId;

  /// The parameter `currentSessionId` of this provider.
  int get currentSessionId;
}

class _WatchLastPerformanceForExerciseProviderElement
    extends AutoDisposeStreamProviderElement<LastSessionPerformance?>
    with WatchLastPerformanceForExerciseRef {
  _WatchLastPerformanceForExerciseProviderElement(super.provider);

  @override
  int get exerciseId =>
      (origin as WatchLastPerformanceForExerciseProvider).exerciseId;
  @override
  int get currentSessionId =>
      (origin as WatchLastPerformanceForExerciseProvider).currentSessionId;
}

String _$watchRecentExerciseIdsHash() =>
    r'27a07aeefd54b5feb6d6a6a56b6bbc5b4d3396a8';

/// Exercise ids the user logged most recently, newest first and de-duplicated.
///
/// Derived from sets already logged, so it needs no schema support — there is
/// no `lastUsedAt` column and this deliberately avoids adding one.
///
/// Copied from [watchRecentExerciseIds].
@ProviderFor(watchRecentExerciseIds)
const watchRecentExerciseIdsProvider = WatchRecentExerciseIdsFamily();

/// Exercise ids the user logged most recently, newest first and de-duplicated.
///
/// Derived from sets already logged, so it needs no schema support — there is
/// no `lastUsedAt` column and this deliberately avoids adding one.
///
/// Copied from [watchRecentExerciseIds].
class WatchRecentExerciseIdsFamily extends Family<AsyncValue<List<int>>> {
  /// Exercise ids the user logged most recently, newest first and de-duplicated.
  ///
  /// Derived from sets already logged, so it needs no schema support — there is
  /// no `lastUsedAt` column and this deliberately avoids adding one.
  ///
  /// Copied from [watchRecentExerciseIds].
  const WatchRecentExerciseIdsFamily();

  /// Exercise ids the user logged most recently, newest first and de-duplicated.
  ///
  /// Derived from sets already logged, so it needs no schema support — there is
  /// no `lastUsedAt` column and this deliberately avoids adding one.
  ///
  /// Copied from [watchRecentExerciseIds].
  WatchRecentExerciseIdsProvider call({int limit = 6}) {
    return WatchRecentExerciseIdsProvider(limit: limit);
  }

  @override
  WatchRecentExerciseIdsProvider getProviderOverride(
    covariant WatchRecentExerciseIdsProvider provider,
  ) {
    return call(limit: provider.limit);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'watchRecentExerciseIdsProvider';
}

/// Exercise ids the user logged most recently, newest first and de-duplicated.
///
/// Derived from sets already logged, so it needs no schema support — there is
/// no `lastUsedAt` column and this deliberately avoids adding one.
///
/// Copied from [watchRecentExerciseIds].
class WatchRecentExerciseIdsProvider
    extends AutoDisposeStreamProvider<List<int>> {
  /// Exercise ids the user logged most recently, newest first and de-duplicated.
  ///
  /// Derived from sets already logged, so it needs no schema support — there is
  /// no `lastUsedAt` column and this deliberately avoids adding one.
  ///
  /// Copied from [watchRecentExerciseIds].
  WatchRecentExerciseIdsProvider({int limit = 6})
    : this._internal(
        (ref) => watchRecentExerciseIds(
          ref as WatchRecentExerciseIdsRef,
          limit: limit,
        ),
        from: watchRecentExerciseIdsProvider,
        name: r'watchRecentExerciseIdsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$watchRecentExerciseIdsHash,
        dependencies: WatchRecentExerciseIdsFamily._dependencies,
        allTransitiveDependencies:
            WatchRecentExerciseIdsFamily._allTransitiveDependencies,
        limit: limit,
      );

  WatchRecentExerciseIdsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.limit,
  }) : super.internal();

  final int limit;

  @override
  Override overrideWith(
    Stream<List<int>> Function(WatchRecentExerciseIdsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchRecentExerciseIdsProvider._internal(
        (ref) => create(ref as WatchRecentExerciseIdsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        limit: limit,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<int>> createElement() {
    return _WatchRecentExerciseIdsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchRecentExerciseIdsProvider && other.limit == limit;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, limit.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WatchRecentExerciseIdsRef on AutoDisposeStreamProviderRef<List<int>> {
  /// The parameter `limit` of this provider.
  int get limit;
}

class _WatchRecentExerciseIdsProviderElement
    extends AutoDisposeStreamProviderElement<List<int>>
    with WatchRecentExerciseIdsRef {
  _WatchRecentExerciseIdsProviderElement(super.provider);

  @override
  int get limit => (origin as WatchRecentExerciseIdsProvider).limit;
}

String _$sessionRepositoryHash() => r'19cd74c7d6d48f1879095d648e627c7d3fb6db80';

/// See also [SessionRepository].
@ProviderFor(SessionRepository)
final sessionRepositoryProvider =
    AutoDisposeNotifierProvider<SessionRepository, void>.internal(
      SessionRepository.new,
      name: r'sessionRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sessionRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SessionRepository = AutoDisposeNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
