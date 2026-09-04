// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$databaseHash() => r'd66464688f3f3beae31aa517238455b4413086f1';

/// The one database the whole app talks to.
///
/// Kept alive deliberately, and this is not a detail. As an auto-disposing
/// provider it closed the database the instant nothing was listening and built
/// a fresh [AppDatabase] on the next read — which happens constantly, because
/// screens come and go and a repository writing through `ref.read` holds
/// nothing open.
///
/// Drift's update notifications are per-instance: each [AppDatabase] has its
/// own stream store, and a write through one instance cannot notify a query
/// stream opened on another. So a screen that had subscribed before the swap
/// went deaf. The write landed, the row changed, and the UI kept drawing the
/// old answer until it was rebuilt for some unrelated reason — which is
/// exactly what "it saves but nothing updates in real time" looks like.
///
/// There is no lifecycle argument for disposing it either. The database is
/// open for as long as the app is, and closing it mid-session is not a saving,
/// it is a bug.
///
/// Copied from [database].
@ProviderFor(database)
final databaseProvider = Provider<AppDatabase>.internal(
  database,
  name: r'databaseProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$databaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DatabaseRef = ProviderRef<AppDatabase>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
