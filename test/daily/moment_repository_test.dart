import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/system_bootstrap.dart';
import 'package:life_os/features/daily/data/repositories/moment_repository_drift.dart';

/// MomentRepository (Drift 实现) 集成测 —— P4-1。
///
/// 重点验证：一对多写入（一条瞬间 + 多张 MomentPhoto，sortOrder 保留顺序）、
/// 删瞬间级联删照片记录（ON DELETE CASCADE）并返回路径、watch 反映当前状态、
/// 纯照片瞬间（content/mood 可空）、FK 依赖。photoPath 用伪路径字符串即可，
/// Repository 只管行，磁盘文件由 MomentPhotoStore 另管。
void main() {
  late AppDatabase db;
  late MomentRepositoryDrift repo;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await SystemBootstrap(db).ensureSystemUser();
    repo = MomentRepositoryDrift(db);
  });

  tearDown(() async => db.close());

  group('addMoment 一对多写入', () {
    test('一条瞬间 + 多张照片，sortOrder 按入参顺序保留', () async {
      final momentId = await repo.addMoment(
        content: '今天的晚霞',
        moodTag: '😊',
        photoPaths: const ['/docs/a.jpg', '/docs/b.jpg', '/docs/c.jpg'],
        loggedAt: DateTime(2026, 7, 24, 18, 30),
      );

      final moments = await db.select(db.lifeMoment).get();
      expect(moments, hasLength(1));
      final m = moments.single;
      expect(m.momentId, momentId);
      expect(m.userId, systemUserId);
      expect(m.content, '今天的晚霞');
      expect(m.moodTag, '😊');
      expect(m.loggedAt, DateTime(2026, 7, 24, 18, 30));

      final photos = await db.select(db.momentPhoto).get();
      expect(photos, hasLength(3));
      expect(photos.map((p) => p.photoPath).toList(), [
        '/docs/a.jpg',
        '/docs/b.jpg',
        '/docs/c.jpg',
      ]);
      // sortOrder 0,1,2 严格递增（保留用户选图顺序）。
      expect(photos.map((p) => p.sortOrder).toList(), [0, 1, 2]);
      // 全部挂在该瞬间下。
      expect(photos.every((p) => p.momentId == momentId), true);
    });

    test('纯照片瞬间：content 与 moodTag 均可空', () async {
      await repo.addMoment(photoPaths: const ['/docs/x.jpg']);

      final m = (await db.select(db.lifeMoment).get()).single;
      expect(m.content, isNull);
      expect(m.moodTag, isNull);
      expect((await db.select(db.momentPhoto).get()), hasLength(1));
    });

    test('无照片也能存（content-only）', () async {
      await repo.addMoment(content: '只有文字', photoPaths: const []);
      expect(await db.select(db.lifeMoment).get(), hasLength(1));
      expect(await db.select(db.momentPhoto).get(), isEmpty);
    });
  });

  group('删除 & 级联', () {
    test('deleteMoment 级联删照片记录并返回路径', () async {
      final momentId = await repo.addMoment(
        content: '要删掉的',
        photoPaths: const ['/docs/d1.jpg', '/docs/d2.jpg'],
      );
      expect(await db.select(db.momentPhoto).get(), hasLength(2));

      final removedPaths = await repo.deleteMoment(momentId);

      expect(removedPaths, ['/docs/d1.jpg', '/docs/d2.jpg']);
      expect(await db.select(db.lifeMoment).get(), isEmpty);
      // ON DELETE CASCADE：照片行随瞬间行一起消失。
      expect(await db.select(db.momentPhoto).get(), isEmpty);
    });

    test('deleteMoment 对不存在的瞬间返回空且不报错', () async {
      final removed = await repo.deleteMoment('no-such-moment');
      expect(removed, isEmpty);
    });
  });

  group('流读', () {
    test('watchMoments 反映当前状态并按 loggedAt 倒序', () async {
      expect(await repo.watchMoments().first, isEmpty);

      await repo.addMoment(
        content: '早',
        photoPaths: const [],
        loggedAt: DateTime(2026, 7, 24, 8),
      );
      await repo.addMoment(
        content: '晚',
        photoPaths: const [],
        loggedAt: DateTime(2026, 7, 24, 20),
      );

      final moments = await repo.watchMoments().first;
      expect(moments.map((m) => m.content).toList(), ['晚', '早']); // 倒序
    });

    test('watchPhotos 按 sortOrder 升序', () async {
      await repo.addMoment(
        photoPaths: const ['/z.jpg', '/a.jpg', '/m.jpg'],
      );
      final photos = await repo.watchPhotos().first;
      expect(photos.map((p) => p.photoPath).toList(), [
        '/z.jpg',
        '/a.jpg',
        '/m.jpg',
      ]);
    });
  });

  group('FK 依赖', () {
    test('无系统用户时 addMoment 因 userId FK 失败', () async {
      final fresh = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(fresh.close);
      final freshRepo = MomentRepositoryDrift(fresh);
      // LifeMoment.userId FK -> UserAccounts；无系统用户 → 违反约束。
      await expectLater(
        freshRepo.addMoment(content: '孤儿', photoPaths: const []),
        throwsA(anything),
      );
    });

    test('MomentPhoto.momentId 的 ON DELETE CASCADE 在 DB 层生效', () async {
      // 直接验证 DDL 级别的外键级联（不经过 Repository 的 deleteMoment）。
      await repo.addMoment(photoPaths: const ['/docs/casc.jpg']);
      final momentId =
          (await db.select(db.lifeMoment).get()).single.momentId;
      expect(await db.select(db.momentPhoto).get(), hasLength(1));

      await (db.delete(db.lifeMoment)
            ..where((t) => t.momentId.equals(momentId)))
          .go();

      expect(await db.select(db.lifeMoment).get(), isEmpty);
      expect(await db.select(db.momentPhoto).get(), isEmpty);
    });
  });
}
