import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/database/system_bootstrap.dart';
import 'room_repository.dart';

const _uuid = Uuid();

/// [RoomRepository] 的 Drift 实现：房间摆件 SQL 集中于此。
///
/// 摆件 = `AssetInventory(projectToRoom = true)` 左连接 `RoomFurniturePlacement`。
/// 左连接而非内连接：新增的资产还没有 placement 行，也应立刻出现在房间里
/// （用确定性默认位置），首次拖动时才写入 placement。
class RoomRepositoryDrift implements RoomRepository {
  RoomRepositoryDrift(this._db);

  final AppDatabase _db;

  @override
  Stream<List<RoomAssetItem>> watchRoomAssets() {
    final asset = _db.assetInventory;
    final place = _db.roomFurniturePlacement;
    final query = _db.select(asset).join([
      leftOuterJoin(place, place.assetId.equalsExp(asset.assetId)),
    ])
      ..where(asset.projectToRoom.equals(true))
      // 按 assetId 排序保证「默认排布」在多次查询间稳定（不会跳来跳去）。
      ..orderBy([OrderingTerm.asc(asset.assetId)]);

    return query.watch().map((rows) {
      final items = <RoomAssetItem>[];
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final a = row.readTable(asset);
        final p = row.readTableOrNull(place);
        if (p != null && !p.isVisible) continue; // 用户手动隐藏的不显示
        final fallback = _defaultSlot(i);
        items.add(
          RoomAssetItem(
            placementId: p?.placementId,
            assetId: a.assetId,
            assetName: a.assetName,
            iconId: a.iconId,
            posX: p?.posX ?? fallback.$1,
            posY: p?.posY ?? fallback.$2,
            scale: p?.scale ?? 1.0,
            zIndex: p?.zIndex ?? 0,
          ),
        );
      }
      items.sort((x, y) => x.zIndex.compareTo(y.zIndex));
      return items;
    });
  }

  /// 未摆放资产的确定性默认位置（归一化 0~1，房间坐标系）。
  ///
  /// 槽位刻意避开三处场景元素：左侧的床、右侧的书桌、以及中央地毯上的宠物 ——
  /// 让新资产落在地板空处而不是压在家具/宠物身上。超出槽位数量后循环复用。
  static (double, double) _defaultSlot(int index) {
    const slots = <(double, double)>[
      (0.05, 0.68), (0.19, 0.81), (0.74, 0.66), (0.86, 0.79),
      (0.05, 0.85), (0.19, 0.64), (0.74, 0.85), (0.86, 0.62),
    ];
    return slots[index % slots.length];
  }

  /// 取（或建）某资产的 placement 行 id。
  Future<String> _ensurePlacement(String assetId) async {
    final existing = await (_db.select(_db.roomFurniturePlacement)
          ..where((t) => t.assetId.equals(assetId)))
        .getSingleOrNull();
    if (existing != null) return existing.placementId;

    final id = _uuid.v4();
    await _db.into(_db.roomFurniturePlacement).insert(
          RoomFurniturePlacementCompanion.insert(
            placementId: id,
            userId: systemUserId,
            assetId: assetId,
          ),
        );
    return id;
  }

  @override
  Future<void> moveAsset(String assetId, double posX, double posY) async {
    final id = await _ensurePlacement(assetId);
    await (_db.update(_db.roomFurniturePlacement)
          ..where((t) => t.placementId.equals(id)))
        .write(
      RoomFurniturePlacementCompanion(
        posX: Value(posX.clamp(0.02, 0.92)),
        posY: Value(posY.clamp(0.18, 0.88)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> scaleAsset(String assetId, double scale) async {
    final id = await _ensurePlacement(assetId);
    await (_db.update(_db.roomFurniturePlacement)
          ..where((t) => t.placementId.equals(id)))
        .write(
      RoomFurniturePlacementCompanion(
        scale: Value(scale.clamp(0.6, 1.8)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> bringToFront(String assetId) async {
    final id = await _ensurePlacement(assetId);
    final maxZ = await _db
        .customSelect(
          'SELECT COALESCE(MAX(z_index), 0) AS m FROM room_furniture_placement',
        )
        .getSingle()
        .then((r) => r.read<int>('m'));
    await (_db.update(_db.roomFurniturePlacement)
          ..where((t) => t.placementId.equals(id)))
        .write(
      RoomFurniturePlacementCompanion(
        zIndex: Value(maxZ + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

/// Repository 的 Riverpod 入口；presentation 依赖此接口。
final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepositoryDrift(ref.read(databaseProvider));
});
