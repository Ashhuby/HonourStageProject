// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$watchSetsForSessionHash() =>
    r'8a41b8f67b183c47f40f9ec204051cda9a092218';

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
