// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rank_up_queue.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$rankUpQueueHash() => r'6aeb5fc01b0a64a17cfebc8987b7fb46dbfaaaa1';

/// Kept alive for the same reason the badge queue is: a rank-up can land while
/// no widget happens to be listening, and one that is dropped is never
/// mentioned again — the header simply reads differently the next time the
/// user looks.
///
/// Copied from [RankUpQueue].
@ProviderFor(RankUpQueue)
final rankUpQueueProvider = NotifierProvider<RankUpQueue, Rank?>.internal(
  RankUpQueue.new,
  name: r'rankUpQueueProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$rankUpQueueHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RankUpQueue = Notifier<Rank?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
