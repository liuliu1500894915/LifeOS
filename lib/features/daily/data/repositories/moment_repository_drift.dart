import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/database/system_bootstrap.dart';
import 'moment_repository.dart';

const _uuid = Uuid();

/// [MomentRepository] 的 Drift 实现：所有 SQL 集中于此。
///
/// 读用 `.watch()`/`.get()`，写用 `Future`，新建瞬间+多照片用事务。
/// 系统用户由 [SystemBootstrap] 启动时一次性确保，此处不自调 ensureSystemUser。
///
/// 注意：磁盘照片文件由 [MomentPhotoStore] 管理（拷入 App 文档目录、删行后清理），
/// 本类只处理 DB 行，[photoPaths] 参数是已落盘的绝对路径。
class MomentRepositoryDrift implements MomentRepository {
  MomentRepositoryDrift(this._db);

  final AppDatabase _db;

  @override
  Stream<List<LifeMomentData>> watchMoments() =>
      (_db.select(_db.lifeMoment)
            ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
          .watch();

  @override
  Stream<List<MomentPhotoData>> watchPhotos() =>
      (_db.select(_db.momentPhoto)
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  @override
  Future<String> addMoment({
    String? content,
    String? moodTag,
    required List<String> photoPaths,
    DateTime? loggedAt,
  }) async {
    final momentId = _uuid.v4();
    final dt = loggedAt ?? DateTime.now();
    // 事务：一条瞬间 + N 张照片原子写入。sortOrder 取路径数组下标，保留用户选图顺序。
    await _db.transaction(() async {
      await _db.into(_db.lifeMoment).insert(
            LifeMomentCompanion.insert(
              momentId: momentId,
              userId: systemUserId,
              content: Value(content),
              moodTag: Value(moodTag),
              loggedAt: dt,
            ),
          );
      for (var i = 0; i < photoPaths.length; i++) {
        await _db.into(_db.momentPhoto).insert(
              MomentPhotoCompanion.insert(
                photoId: _uuid.v4(),
                momentId: momentId,
                photoPath: photoPaths[i],
                sortOrder: Value(i),
              ),
            );
      }
    });
    return momentId;
  }

  @override
  Future<List<String>> deleteMoment(String momentId) async {
    // 先读出该瞬间的全部照片路径（供调用方 best-effort 清理磁盘文件），
    // 再删瞬间行 —— MomentPhoto.momentId 的 ON DELETE CASCADE 会级联删照片行。
    final photos = await (_db.select(_db.momentPhoto)
          ..where((t) => t.momentId.equals(momentId)))
        .get();
    await (_db.delete(_db.lifeMoment)
          ..where((t) => t.momentId.equals(momentId)))
        .go();
    return photos.map((p) => p.photoPath).toList();
  }
}

/// Repository 的 Riverpod 入口；Provider 依赖此 [MomentRepository] 接口。
final momentRepositoryProvider = Provider<MomentRepository>((ref) {
  return MomentRepositoryDrift(ref.read(databaseProvider));
});
