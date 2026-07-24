import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'database_provider.dart';

/// 全 App 唯一的硬编码系统用户 ID。
///
/// 🟠 已知问题:schema 是多用户的,实现是单用户的(CLAUDE.md 已知问题)。
/// 所有本地数据都挂在这个用户下,直到多用户落地。
const String systemUserId = 'user-001';

/// 启动时一次性确保系统用户存在(幂等),取代旧代码里散落在每个 finance
/// Provider 的 `build()` / mutation 中的 `_ensureSystemUser` 冗余写库(P0-3)。
///
/// 用法:在 `app.dart` 顶层 `ref.watch(systemBootstrapProvider)` 触发一次;
/// 需要保证它在 finance 之前完成的 Provider,在 build 里
/// `await ref.read(systemBootstrapProvider.future)`。
class SystemBootstrap {
  SystemBootstrap(this._db);

  final AppDatabase _db;

  Future<void> ensureSystemUser() async {
    await _db.into(_db.userAccounts).insertOnConflictUpdate(
          UserAccountsCompanion.insert(
            userId: systemUserId,
            displayName: '默认用户',
          ),
        );
  }
}

/// 在 app 启动时 watch 一次,缓存其 Future 供其它 Provider await。
final systemBootstrapProvider = FutureProvider<void>((ref) async {
  await SystemBootstrap(ref.read(databaseProvider)).ensureSystemUser();
});
