// drift 也导出了 isNull/isNotNull（SQL 表达式），与 matcher 的同名断言冲突。
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/system_bootstrap.dart';
import 'package:life_os/features/home/data/repositories/room_repository_drift.dart';

/// RoomRepository（Drift 实现）集成测。
///
/// 重点验证「固定资产 → 宠物房间摆件」的投影：此前房间家具是硬编码 mock、
/// 资产的 `projectToRoom` 从未生效，现在改为真实落库。
void main() {
  late AppDatabase db;
  late RoomRepositoryDrift repo;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await SystemBootstrap(db).ensureSystemUser();
    repo = RoomRepositoryDrift(db);
  });

  tearDown(() async => db.close());

  /// 插入一件固定资产（测试夹具，绕过 Repository）。
  Future<void> addAsset(String id, {required bool projectToRoom}) {
    return db.into(db.assetInventory).insert(
          AssetInventoryCompanion.insert(
            assetId: id,
            userId: systemUserId,
            assetName: '资产 $id',
            purchasePrice: 100,
            purchaseDate: DateTime(2026, 1, 1),
            iconId: 'laptop',
            projectToRoom: Value(projectToRoom),
          ),
        );
  }

  test('只投影 projectToRoom = true 的资产', () async {
    await addAsset('a1', projectToRoom: true);
    await addAsset('a2', projectToRoom: false);

    final items = await repo.watchRoomAssets().first;

    expect(items.map((e) => e.assetId), ['a1']);
    expect(items.single.assetName, '资产 a1');
    expect(items.single.iconId, 'laptop');
  });

  test('未摆放的资产有默认位置且互不重叠', () async {
    for (var i = 0; i < 4; i++) {
      await addAsset('a$i', projectToRoom: true);
    }

    final items = await repo.watchRoomAssets().first;

    expect(items.length, 4);
    // 都还没有 placement 行
    expect(items.every((e) => e.placementId == null), isTrue);
    // 默认位置两两不同（避免全叠在一起）
    final positions = items.map((e) => '${e.posX},${e.posY}').toSet();
    expect(positions.length, 4);
    // 且都落在房间可见范围内
    for (final it in items) {
      expect(it.posX, inInclusiveRange(0.0, 1.0));
      expect(it.posY, inInclusiveRange(0.0, 1.0));
    }
  });

  test('moveAsset 首次调用会创建 placement 并持久化位置', () async {
    await addAsset('a1', projectToRoom: true);

    await repo.moveAsset('a1', 0.42, 0.66);

    final items = await repo.watchRoomAssets().first;
    expect(items.single.placementId, isNotNull);
    expect(items.single.posX, closeTo(0.42, 1e-9));
    expect(items.single.posY, closeTo(0.66, 1e-9));

    // 再次移动复用同一 placement 行（不重复插入）
    await repo.moveAsset('a1', 0.10, 0.30);
    final rows = await db.select(db.roomFurniturePlacement).get();
    expect(rows.length, 1);
    expect(rows.single.posX, closeTo(0.10, 1e-9));
  });

  test('位置与缩放会被钳制在合法范围内', () async {
    await addAsset('a1', projectToRoom: true);

    await repo.moveAsset('a1', 5.0, -3.0); // 远超边界
    await repo.scaleAsset('a1', 99); // 远超上限

    final item = (await repo.watchRoomAssets().first).single;
    expect(item.posX, lessThanOrEqualTo(1.0));
    expect(item.posY, greaterThanOrEqualTo(0.0));
    expect(item.scale, 1.8); // 上限

    await repo.scaleAsset('a1', 0.1);
    expect((await repo.watchRoomAssets().first).single.scale, 0.6); // 下限
  });

  test('bringToFront 让摆件 zIndex 最大并排在末位', () async {
    await addAsset('a1', projectToRoom: true);
    await addAsset('a2', projectToRoom: true);

    await repo.bringToFront('a1');
    await repo.bringToFront('a2');
    await repo.bringToFront('a1'); // a1 重新置顶

    final items = await repo.watchRoomAssets().first;
    // 返回结果按 zIndex 升序，末位即最前
    expect(items.last.assetId, 'a1');
    final z = items.map((e) => e.zIndex).toList();
    expect(z, orderedEquals([...z]..sort()));
  });

  test('watch 流在摆件变化后重新发射', () async {
    await addAsset('a1', projectToRoom: true);
    final stream = repo.watchRoomAssets();

    final first = await stream.first;
    expect(first.single.placementId, isNull);

    await repo.moveAsset('a1', 0.5, 0.5);

    final after = await stream.first;
    expect(after.single.placementId, isNotNull);
    expect(after.single.posX, closeTo(0.5, 1e-9));
  });
}
