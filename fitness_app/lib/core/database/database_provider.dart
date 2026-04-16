import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import 'local_database.dart';

part 'database_provider.g.dart';

@riverpod
AppDatabase database(Ref ref) {
  final db = AppDatabase();

  ref.onDispose(() => db.close());

  return db;
}
