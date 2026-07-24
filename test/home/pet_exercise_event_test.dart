// ignore_for_file: discarded_futures

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/core/database/app_database.dart';
import 'package:life_os/core/database/database_provider.dart';
import 'package:life_os/core/event_bus/bus.dart';
import 'package:life_os/core/event_bus/events.dart';
import 'package:life_os/features/health/presentation/providers/exercise_providers.dart';
import 'package:life_os/features/home/domain/vital_calculator.dart';
import 'package:life_os/features/home/presentation/providers/home_providers.dart';

/// P5-1：运动入口迁至健康、宠物监听事件。
///
/// 覆盖：
/// 1. 纯函数 [VitalCalculator.exerciseEnergyGain] 表驱动边界（0/负/不足一轮/整轮）。
/// 2. 健康 `ExerciseLog` 为运动唯一真相：写一次只发一条 [ExerciseLoggedEvent]，
///    且数据落在 ExerciseLog。
/// 3. 宠物能量经事件驱动：发 [ExerciseLoggedEvent] → 能量维度即时上涨、多次累加、
///    封顶 100。
void main() {
  group('VitalCalculator.exerciseEnergyGain', () {
    test('maps duration to energy points, ceil per 10 min, guarded for <=0', () {
      // 非正时长不加（守卫）。
      expect(VitalCalculator.exerciseEnergyGain(0), 0);
      expect(VitalCalculator.exerciseEnergyGain(-5), 0);
      // 向上取整：不足 10 分钟也按 1 点。
      expect(VitalCalculator.exerciseEnergyGain(1), 1);
      expect(VitalCalculator.exerciseEnergyGain(9), 1);
      // 整轮。
      expect(VitalCalculator.exerciseEnergyGain(10), 1);
      expect(VitalCalculator.exerciseEnergyGain(11), 2);
      expect(VitalCalculator.exerciseEnergyGain(30), 3);
      expect(VitalCalculator.exerciseEnergyGain(60), 6);
      expect(VitalCalculator.exerciseEnergyGain(400), 40);
    });
  });

  group('exercise single source of truth', () {
    test('recording an ExerciseLog fires exactly one ExerciseLoggedEvent', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => db.close());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final events = <ExerciseLoggedEvent>[];
      final sub = globalEventBus.on<ExerciseLoggedEvent>().listen(events.add);
      addTearDown(sub.cancel);

      await container.read(exerciseLogProvider.notifier).addExerciseLog(
            exerciseName: '跑步',
            durationMinutes: 30,
            intensity: 'HIGH',
            caloriesBurned: 300,
          );
      // event_bus 默认异步派发，泵送微任务队列。
      await Future<void>.delayed(const Duration(milliseconds: 1));

      // 仅一条事件。
      expect(events, hasLength(1));
      expect(events.single.exerciseName, '跑步');
      expect(events.single.durationMinutes, 30);
      expect(events.single.caloriesBurned, 300);

      // 运动唯一真相落在 ExerciseLog（无第二处入账）。
      final logs = await db.select(db.exerciseLog).get();
      expect(logs, hasLength(1));
      expect(logs.single.exerciseName, '跑步');
      expect(logs.single.caloriesBurned, 300);
    });
  });

  group('pet energy is event-driven', () {
    test('ExerciseLoggedEvent boosts pet energy by the gain', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 读一次 → 创建 exerciseEnergyBonusProvider 并订阅事件。
      final before = container.read(petStatusProvider).energyPoints;

      globalEventBus.fire(ExerciseLoggedEvent(
        exerciseName: '跑步',
        durationMinutes: 30,
        caloriesBurned: 300,
        loggedAt: DateTime(2026, 7, 24, 8),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 1));

      final after = container.read(petStatusProvider).energyPoints;
      // 30min → exerciseEnergyGain(30) = 3 点。
      expect(after, before + 3);
    });

    test('multiple events accumulate the energy bonus', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final before = container.read(petStatusProvider).energyPoints;

      globalEventBus.fire(ExerciseLoggedEvent(
        exerciseName: '走路',
        durationMinutes: 30,
        caloriesBurned: 120,
        loggedAt: DateTime(2026, 7, 24, 9),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 1));
      globalEventBus.fire(ExerciseLoggedEvent(
        exerciseName: '骑行',
        durationMinutes: 60,
        caloriesBurned: 480,
        loggedAt: DateTime(2026, 7, 24, 10),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 1));

      final after = container.read(petStatusProvider).energyPoints;
      // 30min→3 + 60min→6 = 9 点（累加）。
      expect(after, before + 9);
    });

    test('energy clamps at 100 on a large exercise', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(petStatusProvider);
      // 400min → +40 点，叠加 base（68）→ 108 → 封顶 100。
      globalEventBus.fire(ExerciseLoggedEvent(
        exerciseName: '跑步',
        durationMinutes: 400,
        caloriesBurned: 3200,
        loggedAt: DateTime(2026, 7, 24, 11),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(container.read(petStatusProvider).energyPoints, 100);
    });
  });
}
