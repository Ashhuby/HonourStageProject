import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/local_database.dart';
import 'sync_service.dart';

const kWeeklySyncTask = 'weekly_sync_task';

/// Called by workmanager in a separate isolate.
/// Must manually initialise all dependencies — no Flutter binding guaranteed.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL'),
        anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      );

      final db = AppDatabase();
      final syncService = SyncService(
        db: db,
        supabase: Supabase.instance.client,
      );

      final result = await syncService.uploadDirtyRecords();

      return result.success || result.unauthenticated;
    } catch (_) {
      return false; // workmanager will retry
    }
  });
}

/// Register the periodic background sync task.
/// Call once on app startup after Supabase.initialize().
Future<void> registerBackgroundSync() async {
  await Workmanager().initialize(callbackDispatcher);

  await Workmanager().registerPeriodicTask(
    kWeeklySyncTask,
    kWeeklySyncTask,
    frequency: const Duration(days: 7),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}