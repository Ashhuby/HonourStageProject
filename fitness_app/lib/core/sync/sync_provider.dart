import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_provider.dart';
import 'sync_service.dart';

part 'sync_provider.g.dart';

@riverpod
SyncService syncService(Ref ref) {
  return SyncService(
    db: ref.watch(databaseProvider),
    supabase: Supabase.instance.client,
  );
}

/// Manual sync trigger — call ref.read(syncNotifierProvider.notifier).sync()
/// from UI. Exposes AsyncValue<SyncResult> for the UI to react to.
@riverpod
class SyncNotifier extends _$SyncNotifier {
  @override
  AsyncValue<SyncResult> build() =>
      const AsyncValue.data(SyncResult(success: true, uploaded: 0, errors: []));

  Future<void> sync() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(syncServiceProvider).uploadDirtyRecords(),
    );
  }
}
