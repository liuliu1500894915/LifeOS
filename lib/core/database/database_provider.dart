import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// 数据库实例 Provider（单例）
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
