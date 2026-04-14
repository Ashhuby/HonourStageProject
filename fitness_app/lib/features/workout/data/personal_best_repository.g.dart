// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_best_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$watchPrsForExerciseHash() =>
    r'a077cf469db9987eaeb0515940e171636013e83d';

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

/// See also [watchPrsForExercise].
@ProviderFor(watchPrsForExercise)
const watchPrsForExerciseProvider = WatchPrsForExerciseFamily();

/// See also [watchPrsForExercise].
class WatchPrsForExerciseFamily extends Family<AsyncValue<List<PersonalBest>>> {
  /// See also [watchPrsForExercise].
  const WatchPrsForExerciseFamily();

  /// See also [watchPrsForExercise].
  WatchPrsForExerciseProvider call(int exerciseId) {
    return WatchPrsForExerciseProvider(exerciseId);
  }

  @override
  WatchPrsForExerciseProvider getProviderOverride(
    covariant WatchPrsForExerciseProvider provider,
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
  String? get name => r'watchPrsForExerciseProvider';
}

/// See also [watchPrsForExercise].
class WatchPrsForExerciseProvider
    extends AutoDisposeStreamProvider<List<PersonalBest>> {
  /// See also [watchPrsForExercise].
  WatchPrsForExerciseProvider(int exerciseId)
    : this._internal(
        (ref) => watchPrsForExercise(ref as WatchPrsForExerciseRef, exerciseId),
        from: watchPrsForExerciseProvider,
        name: r'watchPrsForExerciseProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$watchPrsForExerciseHash,
        dependencies: WatchPrsForExerciseFamily._dependencies,
        allTransitiveDependencies:
            WatchPrsForExerciseFamily._allTransitiveDependencies,
        exerciseId: exerciseId,
      );

  WatchPrsForExerciseProvider._internal(
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
    Stream<List<PersonalBest>> Function(WatchPrsForExerciseRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchPrsForExerciseProvider._internal(
        (ref) => create(ref as WatchPrsForExerciseRef),
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
  AutoDisposeStreamProviderElement<List<PersonalBest>> createElement() {
    return _WatchPrsForExerciseProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchPrsForExerciseProvider &&
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
mixin WatchPrsForExerciseRef
    on AutoDisposeStreamProviderRef<List<PersonalBest>> {
  /// The parameter `exerciseId` of this provider.
  int get exerciseId;
}

class _WatchPrsForExerciseProviderElement
    extends AutoDisposeStreamProviderElement<List<PersonalBest>>
    with WatchPrsForExerciseRef {
  _WatchPrsForExerciseProviderElement(super.provider);

  @override
  int get exerciseId => (origin as WatchPrsForExerciseProvider).exerciseId;
}

String _$getBestLiftForExerciseHash() =>
    r'97cde4e180856ee8b38e7d83efe9a66194c8d658';

/// See also [getBestLiftForExercise].
@ProviderFor(getBestLiftForExercise)
const getBestLiftForExerciseProvider = GetBestLiftForExerciseFamily();

/// See also [getBestLiftForExercise].
class GetBestLiftForExerciseFamily extends Family<AsyncValue<PersonalBest?>> {
  /// See also [getBestLiftForExercise].
  const GetBestLiftForExerciseFamily();

  /// See also [getBestLiftForExercise].
  GetBestLiftForExerciseProvider call(int exerciseId) {
    return GetBestLiftForExerciseProvider(exerciseId);
  }

  @override
  GetBestLiftForExerciseProvider getProviderOverride(
    covariant GetBestLiftForExerciseProvider provider,
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
  String? get name => r'getBestLiftForExerciseProvider';
}

/// See also [getBestLiftForExercise].
class GetBestLiftForExerciseProvider
    extends AutoDisposeFutureProvider<PersonalBest?> {
  /// See also [getBestLiftForExercise].
  GetBestLiftForExerciseProvider(int exerciseId)
    : this._internal(
        (ref) => getBestLiftForExercise(
          ref as GetBestLiftForExerciseRef,
          exerciseId,
        ),
        from: getBestLiftForExerciseProvider,
        name: r'getBestLiftForExerciseProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$getBestLiftForExerciseHash,
        dependencies: GetBestLiftForExerciseFamily._dependencies,
        allTransitiveDependencies:
            GetBestLiftForExerciseFamily._allTransitiveDependencies,
        exerciseId: exerciseId,
      );

  GetBestLiftForExerciseProvider._internal(
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
    FutureOr<PersonalBest?> Function(GetBestLiftForExerciseRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetBestLiftForExerciseProvider._internal(
        (ref) => create(ref as GetBestLiftForExerciseRef),
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
  AutoDisposeFutureProviderElement<PersonalBest?> createElement() {
    return _GetBestLiftForExerciseProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetBestLiftForExerciseProvider &&
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
mixin GetBestLiftForExerciseRef on AutoDisposeFutureProviderRef<PersonalBest?> {
  /// The parameter `exerciseId` of this provider.
  int get exerciseId;
}

class _GetBestLiftForExerciseProviderElement
    extends AutoDisposeFutureProviderElement<PersonalBest?>
    with GetBestLiftForExerciseRef {
  _GetBestLiftForExerciseProviderElement(super.provider);

  @override
  int get exerciseId => (origin as GetBestLiftForExerciseProvider).exerciseId;
}

String _$watchAllPrsHash() => r'27ba1510a3bc005ef00286a2ae1abb8432c88506';

/// See also [watchAllPrs].
@ProviderFor(watchAllPrs)
final watchAllPrsProvider =
    AutoDisposeStreamProvider<List<PersonalBest>>.internal(
      watchAllPrs,
      name: r'watchAllPrsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$watchAllPrsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WatchAllPrsRef = AutoDisposeStreamProviderRef<List<PersonalBest>>;
String _$personalBestRepositoryHash() =>
    r'2e17c38851c70ca2d01381953735fcf956bc8f9f';

/// See also [PersonalBestRepository].
@ProviderFor(PersonalBestRepository)
final personalBestRepositoryProvider =
    AutoDisposeNotifierProvider<PersonalBestRepository, void>.internal(
      PersonalBestRepository.new,
      name: r'personalBestRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$personalBestRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PersonalBestRepository = AutoDisposeNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
