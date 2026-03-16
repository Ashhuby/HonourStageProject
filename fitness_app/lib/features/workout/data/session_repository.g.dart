// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$watchCompletedSessionsHash() =>
    r'31bdab35ab6ae66fea267b07f40099798630694a';

/// See also [watchCompletedSessions].
@ProviderFor(watchCompletedSessions)
final watchCompletedSessionsProvider =
    AutoDisposeStreamProvider<List<WorkoutSession>>.internal(
      watchCompletedSessions,
      name: r'watchCompletedSessionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$watchCompletedSessionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WatchCompletedSessionsRef =
    AutoDisposeStreamProviderRef<List<WorkoutSession>>;
String _$getVolumeForExerciseHash() =>
    r'9cf3b1c79377626cf36fbf8b91aaa3813482d081';

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

/// See also [getVolumeForExercise].
@ProviderFor(getVolumeForExercise)
const getVolumeForExerciseProvider = GetVolumeForExerciseFamily();

/// See also [getVolumeForExercise].
class GetVolumeForExerciseFamily
    extends Family<AsyncValue<List<VolumeDataPoint>>> {
  /// See also [getVolumeForExercise].
  const GetVolumeForExerciseFamily();

  /// See also [getVolumeForExercise].
  GetVolumeForExerciseProvider call(int exerciseId) {
    return GetVolumeForExerciseProvider(exerciseId);
  }

  @override
  GetVolumeForExerciseProvider getProviderOverride(
    covariant GetVolumeForExerciseProvider provider,
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
  String? get name => r'getVolumeForExerciseProvider';
}

/// See also [getVolumeForExercise].
class GetVolumeForExerciseProvider
    extends AutoDisposeFutureProvider<List<VolumeDataPoint>> {
  /// See also [getVolumeForExercise].
  GetVolumeForExerciseProvider(int exerciseId)
    : this._internal(
        (ref) =>
            getVolumeForExercise(ref as GetVolumeForExerciseRef, exerciseId),
        from: getVolumeForExerciseProvider,
        name: r'getVolumeForExerciseProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$getVolumeForExerciseHash,
        dependencies: GetVolumeForExerciseFamily._dependencies,
        allTransitiveDependencies:
            GetVolumeForExerciseFamily._allTransitiveDependencies,
        exerciseId: exerciseId,
      );

  GetVolumeForExerciseProvider._internal(
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
    FutureOr<List<VolumeDataPoint>> Function(GetVolumeForExerciseRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetVolumeForExerciseProvider._internal(
        (ref) => create(ref as GetVolumeForExerciseRef),
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
  AutoDisposeFutureProviderElement<List<VolumeDataPoint>> createElement() {
    return _GetVolumeForExerciseProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetVolumeForExerciseProvider &&
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
mixin GetVolumeForExerciseRef
    on AutoDisposeFutureProviderRef<List<VolumeDataPoint>> {
  /// The parameter `exerciseId` of this provider.
  int get exerciseId;
}

class _GetVolumeForExerciseProviderElement
    extends AutoDisposeFutureProviderElement<List<VolumeDataPoint>>
    with GetVolumeForExerciseRef {
  _GetVolumeForExerciseProviderElement(super.provider);

  @override
  int get exerciseId => (origin as GetVolumeForExerciseProvider).exerciseId;
}

String _$getAttendanceDataHash() => r'01407ad14f72b5a7ccc3505e9ee5bff914d7b4d0';

/// See also [getAttendanceData].
@ProviderFor(getAttendanceData)
final getAttendanceDataProvider =
    AutoDisposeFutureProvider<Map<DateTime, int>>.internal(
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
typedef GetAttendanceDataRef = AutoDisposeFutureProviderRef<Map<DateTime, int>>;
String _$getWeeklyStreakHash() => r'527845ffb6f520fc1695c09fa8373a26ff5da48f';

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
String _$watchSetsForSessionHash() =>
    r'8a41b8f67b183c47f40f9ec204051cda9a092218';

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

String _$sessionRepositoryHash() => r'93b81099ea03b3d94188be856546b6f88f264737';

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
