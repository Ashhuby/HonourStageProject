// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'badge_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$watchBadgesHash() => r'f837ae1248892f514711e6eaff6d6f3aaeb09f5b';

/// Combines the static badge definitions with live Drift rows so the UI
/// always has a fully merged, sorted list. Earned badges show earnedAt;
/// unearned badges show null. The UI never needs to touch the DB directly.
///
/// Copied from [watchBadges].
@ProviderFor(watchBadges)
final watchBadgesProvider =
    AutoDisposeStreamProvider<List<BadgeViewModel>>.internal(
      watchBadges,
      name: r'watchBadgesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$watchBadgesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WatchBadgesRef = AutoDisposeStreamProviderRef<List<BadgeViewModel>>;
String _$badgeServiceHash() => r'845311a2b139564554974681145d67523d69ce5c';

/// See also [BadgeService].
@ProviderFor(BadgeService)
final badgeServiceProvider =
    AutoDisposeNotifierProvider<BadgeService, void>.internal(
      BadgeService.new,
      name: r'badgeServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$badgeServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BadgeService = AutoDisposeNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
