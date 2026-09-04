import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import 'local_database.dart';

part 'database_provider.g.dart';

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
@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) {
  final db = AppDatabase();

  ref.onDispose(() => db.close());

  return db;
}
