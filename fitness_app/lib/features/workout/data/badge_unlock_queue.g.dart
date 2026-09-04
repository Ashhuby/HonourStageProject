// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'badge_unlock_queue.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$badgeUnlockQueueHash() => r'8fca5b75548ca2d0ab2536f6f97bb479f716f1c1';

/// The pending celebrations, oldest first.
///
/// Kept alive rather than auto-disposed: an award can land while no widget
/// happens to be listening — during a rebuild, or between routes — and a
/// dropped queue is a badge the user is never told about.
///
/// Copied from [BadgeUnlockQueue].
@ProviderFor(BadgeUnlockQueue)
final badgeUnlockQueueProvider =
    NotifierProvider<BadgeUnlockQueue, List<BadgeDefinition>>.internal(
      BadgeUnlockQueue.new,
      name: r'badgeUnlockQueueProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$badgeUnlockQueueHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BadgeUnlockQueue = Notifier<List<BadgeDefinition>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
