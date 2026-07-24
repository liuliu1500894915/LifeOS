import '../../../../core/database/app_database.dart';

/// 生活瞬间数据访问抽象层 —— presentation 只依赖此接口，不碰 `AppDatabase`。
///
/// 读暴露 `watchXxx()`(Drift `.watch()` 流)；写一律 `Future`。
/// 照片文件存 App 文档目录，DB 只存路径（蓝图 §D）；磁盘文件清理见
/// [MomentPhotoStore]，本接口只管行。
///
/// 见 docs/LifeOS-开发执行计划.md P4-1 与 §3.1。
abstract interface class MomentRepository {
  /// 全部瞬间（按时间倒序）流。写库后流自动重发，UI 时间线自动刷新。
  Stream<List<LifeMomentData>> watchMoments();

  /// 全部照片（按 sortOrder 升序）流。与 [watchMoments] 合并即可还原
  /// 「瞬间 → 其多张照片」结构，无需为每条瞬间单独查库（N+1）。
  Stream<List<MomentPhotoData>> watchPhotos();

  /// 新建一条瞬间 + 其多张照片（事务）。[photoPaths] 为已落盘的绝对路径
  /// （由 [MomentPhotoStore] 拷贝到 App 文档目录）。
  Future<String> addMoment({
    String? content,
    String? moodTag,
    required List<String> photoPaths,
    DateTime? loggedAt,
  });

  /// 删除瞬间：级联删其全部照片行，返回被删照片的磁盘路径，供调用方
  /// best-effort 清理文件（蓝图 §3 照片一致性）。DB 是唯一真相，行删了即算删。
  Future<List<String>> deleteMoment(String momentId);
}

/// 读投影：一条瞬间 + 其按 [MomentPhoto.sortOrder] 排序的照片路径列表。
/// 由 presentation 派生 Provider 合并 [MomentRepository.watchMoments] 与
/// [MomentRepository.watchPhotos] 得到。
class MomentWithPhotos {
  final LifeMomentData moment;
  final List<String> photoPaths;

  const MomentWithPhotos({required this.moment, required this.photoPaths});
}
