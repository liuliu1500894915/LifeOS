import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/finance/domain/amortization.dart';

/// 表驱动单测，覆盖开发执行计划 §3.3 / P1-3 验收：
/// 含头含尾(coverageDays = inDays + 1)、单日、闰年 2 月、跨月、端点包含、
/// 区间外、coverageDays < 1 守卫；`amortizedCostInRange` 与「重叠天数 × 日均」
/// 解析式交叉校验（二者结果需一致）。
void main() {
  // 便捷构造（本地日零点，去掉时分秒噪声）。
  DateTime d(int y, int m, int day) => DateTime(y, m, day);
  AmortizedTx tx(double amount, DateTime start, DateTime end) =>
      AmortizedTx(amount: amount, start: start, end: end);

  group('dailyAmortizedCost · 含头含尾平摊', () {
    // 300 元覆盖 [1/1 .. 1/3] = 3 天 → 每天 100。
    final txn = tx(300, d(2026, 1, 1), d(2026, 1, 3));
    final cases = <(String, DateTime, double)>[
      ('区间内中段', d(2026, 1, 2), 100),
      ('起点端点 == start', d(2026, 1, 1), 100),
      ('终点端点 == end', d(2026, 1, 3), 100),
      ('起点前一天(区间外)', d(2025, 12, 31), 0),
      ('终点后一天(区间外)', d(2026, 1, 4), 0),
      ('远在区间前', d(2025, 6, 1), 0),
      ('远在区间后', d(2026, 12, 31), 0),
    ];
    for (final (label, day, expected) in cases) {
      test(label, () {
        expect(dailyAmortizedCost([txn], day), closeTo(expected, 1e-9));
      });
    }

    test('空交易列表 → 0', () {
      expect(dailyAmortizedCost(const [], d(2026, 1, 2)), 0);
    });

    test('单日交易(start==end → coverageDays=1) 全额计入当天', () {
      final single = tx(88, d(2026, 5, 10), d(2026, 5, 10));
      expect(dailyAmortizedCost([single], d(2026, 5, 10)), closeTo(88, 1e-9));
      expect(dailyAmortizedCost([single], d(2026, 5, 9)), 0);
      expect(dailyAmortizedCost([single], d(2026, 5, 11)), 0);
    });

    test('时分秒被截断：带时分秒的 day 与区间端点仍按日匹配', () {
      // 区间端点、查询日都带时分秒，应等价于零点比较。
      final noisy = AmortizedTx(
        amount: 300,
        start: DateTime(2026, 1, 1, 23, 59),
        end: DateTime(2026, 1, 3, 0, 1),
      );
      expect(
        dailyAmortizedCost([noisy], DateTime(2026, 1, 2, 15, 30)),
        closeTo(100, 1e-9),
      );
      // 起点当天 23:59 的端点也算覆盖。
      expect(
        dailyAmortizedCost([noisy], DateTime(2026, 1, 1, 12)),
        closeTo(100, 1e-9),
      );
    });
  });

  group('dailyAmortizedCost · 跨月', () {
    // 400 元覆盖 [1/30 .. 2/2] = 1/30, 1/31, 2/1, 2/2 共 4 天 → 每天 100。
    final txn = tx(400, d(2026, 1, 30), d(2026, 2, 2));
    final cases = <(String, DateTime, double)>[
      ('跨月交界 2/1', d(2026, 2, 1), 100),
      ('跨月交界 1/31', d(2026, 1, 31), 100),
      ('1 月侧端点 1/30', d(2026, 1, 30), 100),
      ('2 月侧端点 2/2', d(2026, 2, 2), 100),
      ('1 月侧外 1/29', d(2026, 1, 29), 0),
      ('2 月侧外 2/3', d(2026, 2, 3), 0),
    ];
    for (final (label, day, expected) in cases) {
      test(label, () {
        expect(dailyAmortizedCost([txn], day), closeTo(expected, 1e-9));
      });
    }
  });

  group('dailyAmortizedCost · 闰年 2 月（含 2/29）', () {
    test('闰年(2024) [2/28 .. 3/1] = 2/28, 2/29, 3/1 共 3 天', () {
      final txn = tx(300, d(2024, 2, 28), d(2024, 3, 1)); // coverageDays = 3
      expect(dailyAmortizedCost([txn], d(2024, 2, 29)), closeTo(100, 1e-9));
      expect(dailyAmortizedCost([txn], d(2024, 2, 28)), closeTo(100, 1e-9));
      expect(dailyAmortizedCost([txn], d(2024, 3, 1)), closeTo(100, 1e-9));
      expect(dailyAmortizedCost([txn], d(2024, 3, 2)), 0);
    });

    test('平年(2023) 同区间 [2/28 .. 3/1] = 2 天（无 2/29）→ 每天 150', () {
      final txn = tx(300, d(2023, 2, 28), d(2023, 3, 1)); // coverageDays = 2
      expect(dailyAmortizedCost([txn], d(2023, 2, 28)), closeTo(150, 1e-9));
      expect(dailyAmortizedCost([txn], d(2023, 3, 1)), closeTo(150, 1e-9));
      expect(dailyAmortizedCost([txn], d(2023, 3, 2)), 0);
    });

    test('跨 2/29 整个 2 月：闰年 2 月共 29 天', () {
      // 2024/2/1 .. 2024/2/29 = 29 天；290 元 → 每天 10。
      final txn = tx(290, d(2024, 2, 1), d(2024, 2, 29));
      expect(dailyAmortizedCost([txn], d(2024, 2, 1)), closeTo(10, 1e-9));
      expect(dailyAmortizedCost([txn], d(2024, 2, 29)), closeTo(10, 1e-9));
      expect(dailyAmortizedCost([txn], d(2024, 1, 31)), 0);
      expect(dailyAmortizedCost([txn], d(2024, 3, 1)), 0);
    });
  });

  group('dailyAmortizedCost · 守卫 coverageDays < 1（end < start）', () {
    test('非法区间(end<start) 对任意日均贡献 0', () {
      final bad = tx(300, d(2026, 1, 5), d(2026, 1, 1)); // end < start
      for (final day in [
        d(2026, 1, 1),
        d(2026, 1, 3),
        d(2026, 1, 5),
        d(2026, 1, 10),
      ]) {
        expect(dailyAmortizedCost([bad], day), 0, reason: 'day=$day');
      }
    });

    test('合法与非法混存：只计合法那笔', () {
      final good = tx(200, d(2026, 1, 1), d(2026, 1, 1)); // 200 当天
      final bad = tx(999, d(2026, 1, 5), d(2026, 1, 1)); // 非法，被守卫跳过
      expect(
        dailyAmortizedCost([good, bad], d(2026, 1, 1)),
        closeTo(200, 1e-9),
      );
    });
  });

  group('dailyAmortizedCost · 多笔求和', () {
    test('两笔都覆盖该日 → 日均相加', () {
      // A: 300/3天 = 100/天 (1/1..1/3)；B: 50/1天 = 50/天 (1/2..1/2)。
      final a = tx(300, d(2026, 1, 1), d(2026, 1, 3));
      final b = tx(50, d(2026, 1, 2), d(2026, 1, 2));
      expect(dailyAmortizedCost([a, b], d(2026, 1, 2)), closeTo(150, 1e-9));
      // 1/1 只有 A。
      expect(dailyAmortizedCost([a, b], d(2026, 1, 1)), closeTo(100, 1e-9));
      // 1/3 只有 A。
      expect(dailyAmortizedCost([a, b], d(2026, 1, 3)), closeTo(100, 1e-9));
    });
  });

  group('amortizedCostInRange · 基本语义', () {
    test('区间 == 交易覆盖区间 → 合计 == 全额', () {
      final txn = tx(300, d(2026, 1, 1), d(2026, 1, 3));
      expect(
        amortizedCostInRange([txn], d(2026, 1, 1), d(2026, 1, 3)),
        closeTo(300, 1e-9),
      );
    });

    test('区间完全包含交易覆盖区间 → 合计 == 全额', () {
      final txn = tx(300, d(2026, 1, 2), d(2026, 1, 4));
      expect(
        amortizedCostInRange([txn], d(2026, 1, 1), d(2026, 1, 10)),
        closeTo(300, 1e-9),
      );
    });

    test('区间落在交易内部 → 按重叠天数比例', () {
      // 300/3天 = 100/天；区间取中间 2 天 → 200。
      final txn = tx(300, d(2026, 1, 1), d(2026, 1, 3));
      expect(
        amortizedCostInRange([txn], d(2026, 1, 1), d(2026, 1, 2)),
        closeTo(200, 1e-9),
      );
    });

    test('区间与交易无重叠 → 0', () {
      final txn = tx(300, d(2026, 1, 10), d(2026, 1, 12));
      expect(
        amortizedCostInRange([txn], d(2026, 1, 1), d(2026, 1, 5)),
        0,
      );
    });

    test('多笔在区间内合计', () {
      final a = tx(300, d(2026, 1, 1), d(2026, 1, 3)); // 全在内 → 300
      final b = tx(50, d(2026, 1, 2), d(2026, 1, 2)); // 全在内 → 50
      expect(
        amortizedCostInRange([a, b], d(2026, 1, 1), d(2026, 1, 3)),
        closeTo(350, 1e-9),
      );
    });

    test('非法查询区间(to < from) → 0', () {
      final txn = tx(300, d(2026, 1, 1), d(2026, 1, 3));
      expect(
        amortizedCostInRange([txn], d(2026, 1, 5), d(2026, 1, 1)),
        0,
      );
    });

    test('跨月 + 闰年区间合计 == 各笔全额之和', () {
      final a = tx(290, d(2024, 2, 1), d(2024, 2, 29)); // 整个闰 2 月
      final b = tx(400, d(2026, 1, 30), d(2026, 2, 2)); // 跨月
      // 区间足够宽，完全覆盖两笔。
      expect(
        amortizedCostInRange([a, b], d(2023, 1, 1), d(2027, 1, 1)),
        closeTo(290 + 400, 1e-9),
      );
    });
  });

  group('amortizedCostInRange · 与解析式交叉校验（二者需一致）', () {
    // 一组多样的场景：宽窄区间 × 单/多笔 × 跨月/闰年/端点对齐/部分重叠。
    final scenarios = <(String, List<AmortizedTx>, DateTime, DateTime)>[
      (
        '单笔·区间==覆盖',
        [tx(300, d(2026, 1, 1), d(2026, 1, 3))],
        d(2026, 1, 1),
        d(2026, 1, 3),
      ),
      (
        '单笔·部分重叠(起点侧)',
        [tx(300, d(2026, 1, 1), d(2026, 1, 10))],
        d(2026, 1, 1),
        d(2026, 1, 4),
      ),
      (
        '单笔·部分重叠(终点侧)',
        [tx(300, d(2026, 1, 1), d(2026, 1, 10))],
        d(2026, 1, 7),
        d(2026, 1, 10),
      ),
      (
        '单笔·区间内嵌',
        [tx(300, d(2026, 1, 1), d(2026, 1, 10))],
        d(2026, 1, 3),
        d(2026, 1, 6),
      ),
      (
        '单笔·无重叠',
        [tx(300, d(2026, 1, 1), d(2026, 1, 3))],
        d(2026, 6, 1),
        d(2026, 6, 5),
      ),
      (
        '多笔·混合重叠',
        [
          tx(300, d(2026, 1, 1), d(2026, 1, 3)),
          tx(50, d(2026, 1, 2), d(2026, 1, 2)),
          tx(1000, d(2026, 1, 2), d(2026, 1, 11)),
        ],
        d(2026, 1, 2),
        d(2026, 1, 5),
      ),
      (
        '跨月',
        [tx(400, d(2026, 1, 30), d(2026, 2, 2))],
        d(2026, 1, 31),
        d(2026, 2, 1),
      ),
      (
        '闰年 2 月',
        [tx(290, d(2024, 2, 1), d(2024, 2, 29))],
        d(2024, 2, 28),
        d(2024, 3, 1),
      ),
      (
        '非法交易(end<start)应被忽略',
        [tx(999, d(2026, 1, 5), d(2026, 1, 1)), tx(200, d(2026, 1, 1), d(2026, 1, 2))],
        d(2026, 1, 1),
        d(2026, 1, 2),
      ),
    ];

    for (final (label, txns, from, to) in scenarios) {
      test(label, () {
        final impl = amortizedCostInRange(txns, from, to);
        final oracle = _closedFormOracle(txns, from, to);
        expect(
          impl,
          closeTo(oracle, 1e-9),
          reason: '逐日累加(实现) 与 重叠天数×日均(解析式) 应一致：'
              'impl=$impl oracle=$oracle',
        );
      });
    }
  });
}

/// 「重叠天数 × 日均」解析式 oracle（独立于被测实现，作交叉校验基准）。
///
/// 对每笔交易：覆盖天数 coverageDays = end.difference(start).inDays + 1（含头含尾，
/// < 1 跳过）；与查询区间 [from,to] 取重叠 [oStart,oEnd]，重叠天数 overlapDays 同口径；
/// 该笔贡献 = amount / coverageDays × overlapDays。求和即区间摊销成本。
double _closedFormOracle(
  Iterable<AmortizedTx> txns,
  DateTime from,
  DateTime to,
) {
  DateTime midnight(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  final rStart = midnight(from);
  final rEnd = midnight(to);
  if (rEnd.isBefore(rStart)) return 0.0;
  var sum = 0.0;
  for (final t in txns) {
    final start = midnight(t.start);
    final end = midnight(t.end);
    final coverageDays = end.difference(start).inDays + 1;
    if (coverageDays < 1) continue;
    final oStart = start.isBefore(rStart) ? rStart : start;
    final oEnd = end.isBefore(rEnd) ? end : rEnd;
    if (oEnd.isBefore(oStart)) continue; // 无重叠
    final overlapDays = oEnd.difference(oStart).inDays + 1;
    sum += t.amount / coverageDays * overlapDays;
  }
  return sum;
}
