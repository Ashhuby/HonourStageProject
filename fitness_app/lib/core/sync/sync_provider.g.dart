// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$syncServiceHash() => r'1f46859b81552a7071d77f0b348f7c49defd2dd7';

/// See also [syncService].
@ProviderFor(syncService)
final syncServiceProvider = AutoDisposeProvider<SyncService>.internal(
  syncService,
  name: r'syncServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$syncServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SyncServiceRef = AutoDisposeProviderRef<SyncService>;
String _$syncNotifierHash() => r'0497da26f21124d7360b87bcd1f80f37c6eda86d';

/// Manual sync trigger — call ref.read(syncNotifierProvider.notifier).sync()
/// from UI. Exposes AsyncValue<SyncResult> for the UI to react to.
///
/// Copied from [SyncNotifier].
@ProviderFor(SyncNotifier)
final syncNotifierProvider =
    AutoDisposeNotifierProvider<SyncNotifier, AsyncValue<SyncResult>>.internal(
      SyncNotifier.new,
      name: r'syncNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$syncNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SyncNotifier = AutoDisposeNotifier<AsyncValue<SyncResult>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
