import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/daily/domain/daily_snapshot.dart';

/// DailyReviewSnapshot 纯模型单测 —— P4-2 domain。
///
/// 重点：JSON roundtrip（encode→decode 还原）、空/损坏 JSON 降级、数值字段容错
/// （存成字符串也能解析）、派生量（净热量/完成率，含除零）。纯 Dart、无 DB/UI 依赖。
void main() {
  group('toJson / fromJson roundtrip', () {
    test('典型值 encode 后 decode 完全还原', () {
      const s = DailyReviewSnapshot(
        expense: 128.5,
        intakeCalories: 1850,
        burnedCalories: 320,
        todoTotal: 4,
        todoCompleted: 3,
      );
      final decoded = DailyReviewSnapshot.decode(DailyReviewSnapshot.encode(s));
      expect(decoded, isNotNull);
      expect(decoded!.expense, 128.5);
      expect(decoded.intakeCalories, 1850);
      expect(decoded.burnedCalories, 320);
      expect(decoded.todoTotal, 4);
      expect(decoded.todoCompleted, 3);
    });

    test('全零值 roundtrip 不丢失', () {
      const s = DailyReviewSnapshot(
        expense: 0,
        intakeCalories: 0,
        burnedCalories: 0,
        todoTotal: 0,
        todoCompleted: 0,
      );
      final decoded = DailyReviewSnapshot.decode(DailyReviewSnapshot.encode(s));
      expect(decoded!.expense, 0);
      expect(decoded.todoTotal, 0);
      expect(decoded.todoCompleted, 0);
    });

    test('小数热量与负净值 roundtrip', () {
      const s = DailyReviewSnapshot(
        expense: 12.34,
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
        'expense': '128',
        'intakeCalories': '1850.5',
        'burnedCalories': '0',
        'todoTotal': '4',
        'todoCompleted': '3',
      });
      expect(s.expense, 128);
      expect(s.intakeCalories, 1850.5);
      expect(s.todoTotal, 4);
    });
  });

  group('派生量', () {
    test('netCalories = 摄入 − 消耗', () {
      const s = DailyReviewSnapshot(
        expense: 0,
        intakeCalories: 2000,
        burnedCalories: 500,
        todoTotal: 0,
        todoCompleted: 0,
      );
      expect(s.netCalories, 1500);
    });

    test('todoCompletionRate：正常比例', () {
      const s = DailyReviewSnapshot(
        expense: 0,
        intakeCalories: 0,
        burnedCalories: 0,
        todoTotal: 4,
        todoCompleted: 3,
      );
      expect(s.todoCompletionRate, 0.75);
    });

    test('todoCompletionRate：todoTotal=0 不除零（返回 0）', () {
      const s = DailyReviewSnapshot(
        expense: 0,
        intakeCalories: 0,
        burnedCalories: 0,
        todoTotal: 0,
        todoCompleted: 0,
      );
      expect(s.todoCompletionRate, 0);
    });

    test('todoCompletionRate：全完成 = 1', () {
      const s = DailyReviewSnapshot(
        expense: 0,
        intakeCalories: 0,
        burnedCalories: 0,
        todoTotal: 5,
        todoCompleted: 5,
      );
      expect(s.todoCompletionRate, 1);
    });
  });
}
