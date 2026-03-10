// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'split_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$watchExercisesForRoutineWithNamesHash() =>
    r'd6e0aab8a15ed49e5a9ad3dd49e465682eb3567f';

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

/// See also [watchExercisesForRoutineWithNames].
@ProviderFor(watchExercisesForRoutineWithNames)
const watchExercisesForRoutineWithNamesProvider =
    WatchExercisesForRoutineWithNamesFamily();

/// See also [watchExercisesForRoutineWithNames].
class WatchExercisesForRoutineWithNamesFamily
    extends Family<AsyncValue<List<RoutineExerciseWithName>>> {
  /// See also [watchExercisesForRoutineWithNames].
  const WatchExercisesForRoutineWithNamesFamily();

  /// See also [watchExercisesForRoutineWithNames].
  WatchExercisesForRoutineWithNamesProvider call(int routineId) {
    return WatchExercisesForRoutineWithNamesProvider(routineId);
  }

  @override
  WatchExercisesForRoutineWithNamesProvider getProviderOverride(
    covariant WatchExercisesForRoutineWithNamesProvider provider,
  ) {
    return call(provider.routineId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'watchExercisesForRoutineWithNamesProvider';
}

/// See also [watchExercisesForRoutineWithNames].
class WatchExercisesForRoutineWithNamesProvider
    extends AutoDisposeStreamProvider<List<RoutineExerciseWithName>> {
  /// See also [watchExercisesForRoutineWithNames].
  WatchExercisesForRoutineWithNamesProvider(int routineId)
    : this._internal(
        (ref) => watchExercisesForRoutineWithNames(
          ref as WatchExercisesForRoutineWithNamesRef,
          routineId,
        ),
        from: watchExercisesForRoutineWithNamesProvider,
        name: r'watchExercisesForRoutineWithNamesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$watchExercisesForRoutineWithNamesHash,
        dependencies: WatchExercisesForRoutineWithNamesFamily._dependencies,
        allTransitiveDependencies:
            WatchExercisesForRoutineWithNamesFamily._allTransitiveDependencies,
        routineId: routineId,
      );

  WatchExercisesForRoutineWithNamesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.routineId,
  }) : super.internal();

  final int routineId;

  @override
  Override overrideWith(
    Stream<List<RoutineExerciseWithName>> Function(
      WatchExercisesForRoutineWithNamesRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchExercisesForRoutineWithNamesProvider._internal(
        (ref) => create(ref as WatchExercisesForRoutineWithNamesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        routineId: routineId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<RoutineExerciseWithName>>
  createElement() {
    return _WatchExercisesForRoutineWithNamesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchExercisesForRoutineWithNamesProvider &&
        other.routineId == routineId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, routineId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WatchExercisesForRoutineWithNamesRef
    on AutoDisposeStreamProviderRef<List<RoutineExerciseWithName>> {
  /// The parameter `routineId` of this provider.
  int get routineId;
}

class _WatchExercisesForRoutineWithNamesProviderElement
    extends AutoDisposeStreamProviderElement<List<RoutineExerciseWithName>>
    with WatchExercisesForRoutineWithNamesRef {
  _WatchExercisesForRoutineWithNamesProviderElement(super.provider);

  @override
  int get routineId =>
      (origin as WatchExercisesForRoutineWithNamesProvider).routineId;
}

String _$watchSplitsHash() => r'f045877d95ff972b0d48ab919fc33b6e7aa010ef';

/// See also [watchSplits].
@ProviderFor(watchSplits)
final watchSplitsProvider =
    AutoDisposeStreamProvider<List<WorkoutSplit>>.internal(
      watchSplits,
      name: r'watchSplitsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$watchSplitsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WatchSplitsRef = AutoDisposeStreamProviderRef<List<WorkoutSplit>>;
String _$watchRoutinesForSplitHash() =>
    r'd9685db4c0f7e2d0a34464a342643074e8872cd2';

/// See also [watchRoutinesForSplit].
@ProviderFor(watchRoutinesForSplit)
const watchRoutinesForSplitProvider = WatchRoutinesForSplitFamily();

/// See also [watchRoutinesForSplit].
class WatchRoutinesForSplitFamily
    extends Family<AsyncValue<List<WorkoutRoutine>>> {
  /// See also [watchRoutinesForSplit].
  const WatchRoutinesForSplitFamily();

  /// See also [watchRoutinesForSplit].
  WatchRoutinesForSplitProvider call(int splitId) {
    return WatchRoutinesForSplitProvider(splitId);
  }

  @override
  WatchRoutinesForSplitProvider getProviderOverride(
    covariant WatchRoutinesForSplitProvider provider,
  ) {
    return call(provider.splitId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'watchRoutinesForSplitProvider';
}

/// See also [watchRoutinesForSplit].
class WatchRoutinesForSplitProvider
    extends AutoDisposeStreamProvider<List<WorkoutRoutine>> {
  /// See also [watchRoutinesForSplit].
  WatchRoutinesForSplitProvider(int splitId)
    : this._internal(
        (ref) =>
            watchRoutinesForSplit(ref as WatchRoutinesForSplitRef, splitId),
        from: watchRoutinesForSplitProvider,
        name: r'watchRoutinesForSplitProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$watchRoutinesForSplitHash,
        dependencies: WatchRoutinesForSplitFamily._dependencies,
        allTransitiveDependencies:
            WatchRoutinesForSplitFamily._allTransitiveDependencies,
        splitId: splitId,
      );

  WatchRoutinesForSplitProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.splitId,
  }) : super.internal();

  final int splitId;

  @override
  Override overrideWith(
    Stream<List<WorkoutRoutine>> Function(WatchRoutinesForSplitRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchRoutinesForSplitProvider._internal(
        (ref) => create(ref as WatchRoutinesForSplitRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        splitId: splitId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<WorkoutRoutine>> createElement() {
    return _WatchRoutinesForSplitProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchRoutinesForSplitProvider && other.splitId == splitId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, splitId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WatchRoutinesForSplitRef
    on AutoDisposeStreamProviderRef<List<WorkoutRoutine>> {
  /// The parameter `splitId` of this provider.
  int get splitId;
}

class _WatchRoutinesForSplitProviderElement
    extends AutoDisposeStreamProviderElement<List<WorkoutRoutine>>
    with WatchRoutinesForSplitRef {
  _WatchRoutinesForSplitProviderElement(super.provider);

  @override
  int get splitId => (origin as WatchRoutinesForSplitProvider).splitId;
}

String _$watchExercisesForRoutineHash() =>
    r'6836c42b5f007c58024a1b6bfcf4a8f919105d74';

/// See also [watchExercisesForRoutine].
@ProviderFor(watchExercisesForRoutine)
const watchExercisesForRoutineProvider = WatchExercisesForRoutineFamily();

/// See also [watchExercisesForRoutine].
class WatchExercisesForRoutineFamily
    extends Family<AsyncValue<List<RoutineExercise>>> {
  /// See also [watchExercisesForRoutine].
  const WatchExercisesForRoutineFamily();

  /// See also [watchExercisesForRoutine].
  WatchExercisesForRoutineProvider call(int routineId) {
    return WatchExercisesForRoutineProvider(routineId);
  }

  @override
  WatchExercisesForRoutineProvider getProviderOverride(
    covariant WatchExercisesForRoutineProvider provider,
  ) {
    return call(provider.routineId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'watchExercisesForRoutineProvider';
}

/// See also [watchExercisesForRoutine].
class WatchExercisesForRoutineProvider
    extends AutoDisposeStreamProvider<List<RoutineExercise>> {
  /// See also [watchExercisesForRoutine].
  WatchExercisesForRoutineProvider(int routineId)
    : this._internal(
        (ref) => watchExercisesForRoutine(
          ref as WatchExercisesForRoutineRef,
          routineId,
        ),
        from: watchExercisesForRoutineProvider,
        name: r'watchExercisesForRoutineProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$watchExercisesForRoutineHash,
        dependencies: WatchExercisesForRoutineFamily._dependencies,
        allTransitiveDependencies:
            WatchExercisesForRoutineFamily._allTransitiveDependencies,
        routineId: routineId,
      );

  WatchExercisesForRoutineProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.routineId,
  }) : super.internal();

  final int routineId;

  @override
  Override overrideWith(
    Stream<List<RoutineExercise>> Function(WatchExercisesForRoutineRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchExercisesForRoutineProvider._internal(
        (ref) => create(ref as WatchExercisesForRoutineRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        routineId: routineId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<RoutineExercise>> createElement() {
    return _WatchExercisesForRoutineProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchExercisesForRoutineProvider &&
        other.routineId == routineId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, routineId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WatchExercisesForRoutineRef
    on AutoDisposeStreamProviderRef<List<RoutineExercise>> {
  /// The parameter `routineId` of this provider.
  int get routineId;
}

class _WatchExercisesForRoutineProviderElement
    extends AutoDisposeStreamProviderElement<List<RoutineExercise>>
    with WatchExercisesForRoutineRef {
  _WatchExercisesForRoutineProviderElement(super.provider);

  @override
  int get routineId => (origin as WatchExercisesForRoutineProvider).routineId;
}

String _$splitRepositoryHash() => r'589909d2545e7c5ee395f1556a32bf7a23d9e018';

/// See also [SplitRepository].
@ProviderFor(SplitRepository)
final splitRepositoryProvider =
    AutoDisposeNotifierProvider<SplitRepository, void>.internal(
      SplitRepository.new,
      name: r'splitRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$splitRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SplitRepository = AutoDisposeNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
