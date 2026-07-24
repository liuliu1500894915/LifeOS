import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/system_bootstrap.dart';
import '../../data/moment_photo_store.dart';
import '../../data/repositories/moment_repository.dart';
import '../../data/repositories/moment_repository_drift.dart';

// 导出读投影 DTO(MomentWithPhotos)供时间线页引用。
export '../../data/repositories/moment_repository.dart';

// ── Stream-backed notifiers ──
//
// presentation 层状态编排 —— 只调 [MomentRepository] 接口，无任何 `db.`/
// `Companion`/裸查询。读取走 Repository 的 `.watch()` 流(Drift StreamQueries)：
// 写库后流自动重发新值，UI 时间线自动刷新。命令只转发给 Repository、不触碰 state、
// 不手动 _fetchAll、不靠 ref.invalidate 跨 Provider 同步(同 finance/health 范例)。
//
// 系统用户前置：每个写方法首行 `await ref.read(systemBootstrapProvider.future)`
// ——StreamNotifier 的 `async*` build 体是惰性的(被 listen 才跑)，写方法显式自保护。

class MomentNotifier extends StreamNotifier<List<LifeMomentData>> {
  @override
  Stream<List<LifeMomentData>> build() async* {
    await ref.read(systemBootstrapProvider.future);
    yield* ref.watch(momentRepositoryProvider).watchMoments();
  }

  /// 新建瞬间。photos 为 image_picker 返回的临时 XFile，先经
  /// [MomentPhotoStore] 拷入 App 文档目录得持久路径，再入库。
  Future<String> addMoment({
    String? content,
    String? moodTag,
    List<XFile> photos = const [],
    DateTime? loggedAt,
  }) async {
    await ref.read(systemBootstrapProvider.future);
    final store = ref.read(momentPhotoStoreProvider);
    final paths = <String>[];
    for (final photo in photos) {
      paths.add(await store.copyToAppDocs(photo));
    }
    return ref.read(momentRepositoryProvider).addMoment(
          content: content,
          moodTag: moodTag,
          photoPaths: paths,
          loggedAt: loggedAt,
        );
  }

  /// 删除瞬间：删行(DB 级联删照片行) + best-effort 清理磁盘照片文件。
  Future<void> deleteMoment(String momentId) async {
    await ref.read(systemBootstrapProvider.future);
    final repo = ref.read(momentRepositoryProvider);
    final store = ref.read(momentPhotoStoreProvider);
    final photoPaths = await repo.deleteMoment(momentId);
    await store.deleteFiles(photoPaths);
  }
}

final momentProvider =
    StreamNotifierProvider<MomentNotifier, List<LifeMomentData>>(
  MomentNotifier.new,
);

/// 全部照片流（按 sortOrder 升序）。与 [momentProvider] 合并还原「瞬间 → 多照片」。
final momentPhotoListProvider = StreamProvider<List<MomentPhotoData>>((ref) {
  ref.watch(systemBootstrapProvider);
  return ref.watch(momentRepositoryProvider).watchPhotos();
});

/// 时间线读投影：每条瞬间 + 其按 [MomentPhoto.sortOrder] 排序的照片路径。
/// 由 [momentProvider] 与 [momentPhotoListProvider] 两路流合并派生，任一写库
/// 自动重发，UI 自动刷新（无手动 _fetchAll / invalidate）。
final momentsWithPhotosProvider = Provider<List<MomentWithPhotos>>((ref) {
  final asyncMoments = ref.watch(momentProvider).valueOrNull ??
      const <LifeMomentData>[];
  // watch 触发 photo 流就绪；valueOrNull 在 loading 时为空，首帧后即有值。
  final asyncPhotos =
      ref.watch(momentPhotoListProvider).valueOrNull ?? const <MomentPhotoData>[];
  // 按 momentId 分组；MomentPhoto 已按 sortOrder 升序，保留读出顺序。
  final byMoment = <String, List<String>>{};
  for (final photo in asyncPhotos) {
    (byMoment[photo.momentId] ??= []).add(photo.photoPath);
  }
  return [
    for (final m in asyncMoments)
      MomentWithPhotos(moment: m, photoPaths: byMoment[m.momentId] ?? const []),
  ];
});

/// 当日瞬间数（供「每日」页入口卡角标）。
final todayMomentCountProvider = Provider<int>((ref) {
  final moments =
      ref.watch(momentProvider).valueOrNull ?? const <LifeMomentData>[];
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));
  return moments
      .where((m) => !m.loggedAt.isBefore(start) && m.loggedAt.isBefore(end))
      .length;
});
