// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'badge_stats.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$badgeProgressHash() => r'aeccd4d4e4082d72ddf3ba3e9b7fc7a272bf6002';

/// The full stats snapshot, for the badges screen.
///
/// A stream rather than a future because the badges screen lives inside the
/// home screen's `IndexedStack` and is therefore built once and never
/// disposed — a one-shot future would show the numbers as they stood when the
/// app launched. The trivial query exists only for its `readsFrom` set: drift
/// re-emits when any of those tables is written, which is exactly when a stat
/// can have moved.
///
/// Copied from [badgeProgress].
@ProviderFor(badgeProgress)
final badgeProgressProvider = AutoDisposeStreamProvider<BadgeStats>.internal(
  badgeProgress,
  name: r'badgeProgressProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$badgeProgressHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BadgeProgressRef = AutoDisposeStreamProviderRef<BadgeStats>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
