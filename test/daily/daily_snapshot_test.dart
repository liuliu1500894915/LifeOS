import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/daily/domain/daily_snapshot.dart';

/// DailyReviewSnapshot 纯模型单测 —— P4-2 domain / P5-3 扩展。
///
/// 重点：JSON roundtrip（encode→decode 还原）、空/损坏 JSON 降级、数值字段容错
/// （存成字符串也能解析）、派生量（真实成本/净热量/完成率，含除零）、以及
/// P5-3 财务三层（日常 SPOT / 长期摊销 / 真实成本）与 P4-2 旧 `expense` 键的向后
/// 兼容解码。纯 Dart、无 DB/UI 依赖。
void main() {
  group('toJson / fromJson roundtrip', () {
    test('典型值（含财务三层）encode 后 decode 完全还原', () {
      const s = DailyReviewSnapshot(
        spotExpense: 100,
        amortizedExpense: 80,
        intakeCalories: 1850,
        burnedCalories: 320,
        todoTotal: 4,
        todoCompleted: 3,
      );
      final decoded = DailyReviewSnapshot.decode(DailyReviewSnapshot.encode(s));
      expect(decoded, isNotNull);
      expect(decoded!.spotExpense, 100);
      expect(decoded.amortizedExpense, 80);
      expect(decoded.trueExpense, 180);
      expect(decoded.intakeCalories, 1850);
      expect(decoded.burnedCalories, 320);
      expect(decoded.todoTotal, 4);
      expect(decoded.todoCompleted, 3);
    });

    test('全零值 roundtrip 不丢失', () {
      const s = DailyReviewSnapshot(
        spotExpense: 0,
        amortizedExpense: 0,
        intakeCalories: 0,
        burnedCalories: 0,
        todoTotal: 0,
        todoCompleted: 0,
      );
      final decoded = DailyReviewSnapshot.decode(DailyReviewSnapshot.encode(s));
      expect(decoded!.spotExpense, 0);
      expect(decoded.amortizedExpense, 0);
      expect(decoded.todoTotal, 0);
      expect(decoded.todoCompleted, 0);
    });

    test('小数热量与负净值 roundtrip', () {
      const s = DailyReviewSnapshot(
        spotExpense: 12.34,
        amortizedExpense: 7.5,
        intakeCalories: 1500.5,
        burnedCalories: 1800.25,
        todoTotal: 5,
        todoCompleted: 1,
      );
      final decoded = DailyReviewSnapshot.decode(DailyReviewSnapshot.encode(s));
      expect(decoded!.intakeCalories, 1500.5);
      expect(decoded.burnedCalories, 1800.25);
    });
  });

  group('P4-2 → P5-3 向后兼容解码', () {
    test('旧快照仅存合并 expense：读为 spot=expense、amort=0，trueExpense 不丢总额', () {
      // 模拟 P4-2 写入的历史 JSON：只有合并的 expense 键，无 spot/amort 拆分。
      const legacyJson = {
        'expense': 250,
        'intakeCalories': 1600,
        'burnedCalories': 200,
        'todoTotal': 3,
        'todoCompleted': 2,
      };
      final s = DailyReviewSnapshot.fromJson(legacyJson);
      // 拆分信息已不可恢复：视为全计日常、摊销 0。
      expect(s.spotExpense, 250);
      expect(s.amortizedExpense, 0);
      // 真实成本仍等于历史总额（冻结语义不丢总额）。
      expect(s.trueExpense, 250);
      expect(s.intakeCalories, 1600);
      expect(s.todoCompleted, 2);
    });

    test('decode 直读历史 JSON 字符串（旧键）也走兼容路径', () {
      const legacy = '{"expense": 88, "intakeCalories": 1000, '
          '"burnedCalories": 0, "todoTotal": 1, "todoCompleted": 1}';
      final s = DailyReviewSnapshot.decode(legacy);
      expect(s, isNotNull);
      expect(s!.spotExpense, 88);
      expect(s.amortizedExpense, 0);
      expect(s.trueExpense, 88);
    });
  });

  group('decode 降级', () {
    test('null / 空串 / 空白 均返回 null（不抛）', () {
      expect(DailyReviewSnapshot.decode(null), isNull);
      expect(DailyReviewSnapshot.decode(''), isNull);
      expect(DailyReviewSnapshot.decode('   '), isNull);
    });

    test('损坏 JSON 返回 null（不抛）', () {
      expect(DailyReviewSnapshot.decode('not a json'), isNull);
      expect(DailyReviewSnapshot.decode('{bad'), isNull);
    });

    test('数值字段存成字符串也能解析（容错）', () {
      // 模拟旧库/手改把 number 落成字符串，fromJson 的 num.parse 分支兜底。
      final s = DailyReviewSnapshot.fromJson({
        'spotExpense': '128',
        'amortizedExpense': '22',
        'intakeCalories': '1850.5',
        'burnedCalories': '0',
        'todoTotal': '4',
        'todoCompleted': '3',
      });
      expect(s.spotExpense, 128);
      expect(s.amortizedExpense, 22);
      expect(s.intakeCalories, 1850.5);
      expect(s.todoTotal, 4);
    });
  });

  group('派生量', () {
    test('trueExpense = 日常 + 摊销', () {
      const s = DailyReviewSnapshot(
        spotExpense: 120,
        amortizedExpense: 80,
        intakeCalories: 0,
        burnedCalories: 0,
        todoTotal: 0,
        todoCompleted: 0,
      );
      expect(s.trueExpense, 200);
    });

    test('netCalories = 摄入 − 消耗', () {
      const s = DailyReviewSnapshot(
        spotExpense: 0,
        amortizedExpense: 0,
        intakeCalories: 2000,
        burnedCalories: 500,
        todoTotal: 0,
        todoCompleted: 0,
      );
      expect(s.netCalories, 1500);
    });

    test('todoCompletionRate：正常比例', () {
      const s = DailyReviewSnapshot(
        spotExpense: 0,
        amortizedExpense: 0,
        intakeCalories: 0,
        burnedCalories: 0,
        todoTotal: 4,
        todoCompleted: 3,
      );
      expect(s.todoCompletionRate, 0.75);
    });

    test('todoCompletionRate：todoTotal=0 不除零（返回 0）', () {
      const s = DailyReviewSnapshot(
        spotExpense: 0,
        amortizedExpense: 0,
        intakeCalories: 0,
        burnedCalories: 0,
        todoTotal: 0,
        todoCompleted: 0,
      );
      expect(s.todoCompletionRate, 0);
    });

    test('todoCompletionRate：全完成 = 1', () {
      const s = DailyReviewSnapshot(
        spotExpense: 0,
        amortizedExpense: 0,
        intakeCalories: 0,
        burnedCalories: 0,
        todoTotal: 5,
        todoCompleted: 5,
      );
      expect(s.todoCompletionRate, 1);
    });
  });
}
