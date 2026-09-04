// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'split_schedule_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$watchDefaultSplitHash() => r'8abe62585983472ec2adf075c3d0e0af3364346d';

/// The split the Splits tab opens on, or null when there is none.
///
/// At most one row is ever flagged — [SplitScheduleRepository.setDefaultSplit]
/// clears the others in the same transaction — but this takes the first of
/// whatever it finds rather than asserting, because a half-applied sync is not
/// worth a crash on the app's opening screen.
///
/// Copied from [watchDefaultSplit].
@ProviderFor(watchDefaultSplit)
final watchDefaultSplitProvider =
    AutoDisposeStreamProvider<WorkoutSplit?>.internal(
      watchDefaultSplit,
      name: r'watchDefaultSplitProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$watchDefaultSplitHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WatchDefaultSplitRef = AutoDisposeStreamProviderRef<WorkoutSplit?>;
String _$watchSplitScheduleHash() =>
    r'3b65e2f28bca948802a9bc7ea90d7d641a7035da';

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

/// The rotation for one split.
///
/// Watches both tables the answer is built from. It used to be driven by the
/// split row alone, which is not where a rotation actually lives: putting a
/// routine on a day writes `schedule_slots` on **workout_routines**, so the
/// stream never fired. The write landed and the screen kept drawing the old
/// schedule — adding a day appeared to do nothing, and removing one appeared
/// to do nothing either.
///
/// The trivial query is here for its `readsFrom` set; drift re-emits when any
/// of those tables is written, which is exactly when this answer can change.
///
/// Copied from [watchSplitSchedule].
@ProviderFor(watchSplitSchedule)
const watchSplitScheduleProvider = WatchSplitScheduleFamily();

/// The rotation for one split.
///
/// Watches both tables the answer is built from. It used to be driven by the
/// split row alone, which is not where a rotation actually lives: putting a
/// routine on a day writes `schedule_slots` on **workout_routines**, so the
/// stream never fired. The write landed and the screen kept drawing the old
/// schedule — adding a day appeared to do nothing, and removing one appeared
/// to do nothing either.
///
/// The trivial query is here for its `readsFrom` set; drift re-emits when any
/// of those tables is written, which is exactly when this answer can change.
///
/// Copied from [watchSplitSchedule].
class WatchSplitScheduleFamily extends Family<AsyncValue<SplitSchedule>> {
  /// The rotation for one split.
  ///
  /// Watches both tables the answer is built from. It used to be driven by the
  /// split row alone, which is not where a rotation actually lives: putting a
  /// routine on a day writes `schedule_slots` on **workout_routines**, so the
  /// stream never fired. The write landed and the screen kept drawing the old
  /// schedule — adding a day appeared to do nothing, and removing one appeared
  /// to do nothing either.
  ///
  /// The trivial query is here for its `readsFrom` set; drift re-emits when any
  /// of those tables is written, which is exactly when this answer can change.
  ///
  /// Copied from [watchSplitSchedule].
  const WatchSplitScheduleFamily();

  /// The rotation for one split.
  ///
  /// Watches both tables the answer is built from. It used to be driven by the
  /// split row alone, which is not where a rotation actually lives: putting a
  /// routine on a day writes `schedule_slots` on **workout_routines**, so the
  /// stream never fired. The write landed and the screen kept drawing the old
  /// schedule — adding a day appeared to do nothing, and removing one appeared
  /// to do nothing either.
  ///
  /// The trivial query is here for its `readsFrom` set; drift re-emits when any
  /// of those tables is written, which is exactly when this answer can change.
  ///
  /// Copied from [watchSplitSchedule].
  WatchSplitScheduleProvider call(int splitId) {
    return WatchSplitScheduleProvider(splitId);
  }

  @override
  WatchSplitScheduleProvider getProviderOverride(
    covariant WatchSplitScheduleProvider provider,
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
  String? get name => r'watchSplitScheduleProvider';
}

/// The rotation for one split.
///
/// Watches both tables the answer is built from. It used to be driven by the
/// split row alone, which is not where a rotation actually lives: putting a
/// routine on a day writes `schedule_slots` on **workout_routines**, so the
/// stream never fired. The write landed and the screen kept drawing the old
/// schedule — adding a day appeared to do nothing, and removing one appeared
/// to do nothing either.
///
/// The trivial query is here for its `readsFrom` set; drift re-emits when any
/// of those tables is written, which is exactly when this answer can change.
///
/// Copied from [watchSplitSchedule].
class WatchSplitScheduleProvider
    extends AutoDisposeStreamProvider<SplitSchedule> {
  /// The rotation for one split.
  ///
  /// Watches both tables the answer is built from. It used to be driven by the
  /// split row alone, which is not where a rotation actually lives: putting a
  /// routine on a day writes `schedule_slots` on **workout_routines**, so the
  /// stream never fired. The write landed and the screen kept drawing the old
  /// schedule — adding a day appeared to do nothing, and removing one appeared
  /// to do nothing either.
  ///
  /// The trivial query is here for its `readsFrom` set; drift re-emits when any
  /// of those tables is written, which is exactly when this answer can change.
  ///
  /// Copied from [watchSplitSchedule].
  WatchSplitScheduleProvider(int splitId)
    : this._internal(
        (ref) => watchSplitSchedule(ref as WatchSplitScheduleRef, splitId),
        from: watchSplitScheduleProvider,
        name: r'watchSplitScheduleProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$watchSplitScheduleHash,
        dependencies: WatchSplitScheduleFamily._dependencies,
        allTransitiveDependencies:
            WatchSplitScheduleFamily._allTransitiveDependencies,
        splitId: splitId,
      );

  WatchSplitScheduleProvider._internal(
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
    Stream<SplitSchedule> Function(WatchSplitScheduleRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchSplitScheduleProvider._internal(
        (ref) => create(ref as WatchSplitScheduleRef),
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
  AutoDisposeStreamProviderElement<SplitSchedule> createElement() {
    return _WatchSplitScheduleProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchSplitScheduleProvider && other.splitId == splitId;
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
mixin WatchSplitScheduleRef on AutoDisposeStreamProviderRef<SplitSchedule> {
  /// The parameter `splitId` of this provider.
  int get splitId;
}

class _WatchSplitScheduleProviderElement
    extends AutoDisposeStreamProviderElement<SplitSchedule>
    with WatchSplitScheduleRef {
  _WatchSplitScheduleProviderElement(super.provider);

  @override
  int get splitId => (origin as WatchSplitScheduleProvider).splitId;
}

String _$watchSplitPlanHash() => r'e63592e39ccb47d3e00e429d73bcbb95fe9aa8ea';

/// The full picture for one split: its rotation, what is due, and when it was
/// last trained.
///
/// A stream rather than a future because the Splits tab stays mounted and the
/// answer changes the moment a session is finished — the whole point of the
/// card is that it is right when the user opens the app.
///
/// Copied from [watchSplitPlan].
@ProviderFor(watchSplitPlan)
const watchSplitPlanProvider = WatchSplitPlanFamily();

/// The full picture for one split: its rotation, what is due, and when it was
/// last trained.
///
/// A stream rather than a future because the Splits tab stays mounted and the
/// answer changes the moment a session is finished — the whole point of the
/// card is that it is right when the user opens the app.
///
/// Copied from [watchSplitPlan].
class WatchSplitPlanFamily extends Family<AsyncValue<SplitPlan?>> {
  /// The full picture for one split: its rotation, what is due, and when it was
  /// last trained.
  ///
  /// A stream rather than a future because the Splits tab stays mounted and the
  /// answer changes the moment a session is finished — the whole point of the
  /// card is that it is right when the user opens the app.
  ///
  /// Copied from [watchSplitPlan].
  const WatchSplitPlanFamily();

  /// The full picture for one split: its rotation, what is due, and when it was
  /// last trained.
  ///
  /// A stream rather than a future because the Splits tab stays mounted and the
  /// answer changes the moment a session is finished — the whole point of the
  /// card is that it is right when the user opens the app.
  ///
  /// Copied from [watchSplitPlan].
  WatchSplitPlanProvider call(int splitId) {
    return WatchSplitPlanProvider(splitId);
  }

  @override
  WatchSplitPlanProvider getProviderOverride(
    covariant WatchSplitPlanProvider provider,
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
  String? get name => r'watchSplitPlanProvider';
}

/// The full picture for one split: its rotation, what is due, and when it was
/// last trained.
///
/// A stream rather than a future because the Splits tab stays mounted and the
/// answer changes the moment a session is finished — the whole point of the
/// card is that it is right when the user opens the app.
///
/// Copied from [watchSplitPlan].
class WatchSplitPlanProvider extends AutoDisposeStreamProvider<SplitPlan?> {
  /// The full picture for one split: its rotation, what is due, and when it was
  /// last trained.
  ///
  /// A stream rather than a future because the Splits tab stays mounted and the
  /// answer changes the moment a session is finished — the whole point of the
  /// card is that it is right when the user opens the app.
  ///
  /// Copied from [watchSplitPlan].
  WatchSplitPlanProvider(int splitId)
    : this._internal(
        (ref) => watchSplitPlan(ref as WatchSplitPlanRef, splitId),
        from: watchSplitPlanProvider,
        name: r'watchSplitPlanProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$watchSplitPlanHash,
        dependencies: WatchSplitPlanFamily._dependencies,
        allTransitiveDependencies:
            WatchSplitPlanFamily._allTransitiveDependencies,
        splitId: splitId,
      );

  WatchSplitPlanProvider._internal(
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
    Stream<SplitPlan?> Function(WatchSplitPlanRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchSplitPlanProvider._internal(
        (ref) => create(ref as WatchSplitPlanRef),
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
  AutoDisposeStreamProviderElement<SplitPlan?> createElement() {
    return _WatchSplitPlanProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchSplitPlanProvider && other.splitId == splitId;
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
mixin WatchSplitPlanRef on AutoDisposeStreamProviderRef<SplitPlan?> {
  /// The parameter `splitId` of this provider.
  int get splitId;
}

class _WatchSplitPlanProviderElement
    extends AutoDisposeStreamProviderElement<SplitPlan?>
    with WatchSplitPlanRef {
  _WatchSplitPlanProviderElement(super.provider);

  @override
  int get splitId => (origin as WatchSplitPlanProvider).splitId;
}

String _$splitScheduleRepositoryHash() =>
    r'afc8a1a6c4b2de1c512a9dd6751b172161aff7b7';

/// See also [SplitScheduleRepository].
@ProviderFor(SplitScheduleRepository)
final splitScheduleRepositoryProvider =
    AutoDisposeNotifierProvider<SplitScheduleRepository, void>.internal(
      SplitScheduleRepository.new,
      name: r'splitScheduleRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$splitScheduleRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SplitScheduleRepository = AutoDisposeNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
