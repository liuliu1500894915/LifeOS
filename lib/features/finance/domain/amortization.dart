/// 摊销成本计算（纯 Dart，无 Flutter / Drift 依赖，可独立单测）。
///
/// 见开发执行计划 §1.1、§3.3 / P1-3：长期摊销类支出（`expenseNature = AMORTIZED`）
/// 按其覆盖区间把金额**平摊到每一天**，使日/月成本曲线平滑、不含「一次性全额尖峰」。
/// 余额仍按全额扣减（现金流不变），摊销只影响分析口径（P1-5）。
///
/// 口径约定（见风险 §5.6）：跨日一律取「本地日 dateOnly」——比较前先截断到当天零点，
/// 避免时分秒导致边界错位。区间**含头含尾**：覆盖天数 = `end.difference(start).inDays + 1`
/// （单日交易 → 1）。`end < start` 的非法区间一律跳过（[dailyAmortizedCost] 内守卫）。
library;

/// 一笔摊销交易（domain 边界 DTO）。
///
/// 由 data 层（Repository，P1-5）从 `FinancialTransactionData` 适配而来：仅取
/// `expenseNature == 'AMORTIZED'` 且 `amortizeStartDate` / `amortizeEndDate` 均非空
/// 的交易，按下表映射（domain 不依赖 Drift，故在此定义纯 Dart 结构作边界）：
///
/// | [AmortizedTx] | `FinancialTransactionData` |
/// |---|---|
/// | [amount] | `amount` |
/// | [start]  | `amortizeStartDate` |
/// | [end]    | `amortizeEndDate` |
///
/// 不可变；时分秒会被忽略，仅日期部分参与计算。
class AmortizedTx {
  const AmortizedTx({
    required this.amount,
    required this.start,
    required this.end,
  });

  /// 摊销总金额（按全额，单位与交易一致）。
  final double amount;

  /// 覆盖区间起点（含）。
  final DateTime start;

  /// 覆盖区间终点（含）。
  final DateTime end;
}

/// 把 [DateTime] 截断到本地日零点（仅保留年月日）。
///
/// 摊销按「日」平摊，比较前统一截断，避免时分秒导致边界错位（风险 §5.6）。
/// 与 `midnight_settlement_service._dateOnly` 同口径，待后续统一到 core util 时一并迁移。
DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// [day] 当天的摊销成本：所有覆盖该日的 [AmortizedTx]，按「金额 ÷ 覆盖天数(含头含尾)」求和。
///
/// 仅统计区间 `[start, end]` 包含 [day] 的交易。覆盖天数取「含头含尾」：
/// `coverageDays = end.difference(start).inDays + 1`（单日交易 → 1）。
/// `coverageDays < 1`（即 `end < start` 的非法区间）一律跳过（守卫，验收 P1-3）。
///
/// [day] 及各区间的时分秒都会被截断，只比日期；落在端点（== start / == end）算覆盖，
/// 落在区间外贡献 0。
double dailyAmortizedCost(Iterable<AmortizedTx> txns, DateTime day) {
  final d = _dateOnly(day);
  var sum = 0.0;
  for (final t in txns) {
    final start = _dateOnly(t.start);
    final end = _dateOnly(t.end);
    if (d.isBefore(start) || d.isAfter(end)) continue; // day 落在区间外
    final coverageDays = end.difference(start).inDays + 1; // 含头含尾
    if (coverageDays < 1) continue; // 守卫：非法区间(end<start)不计
    sum += t.amount / coverageDays;
  }
  return sum;
}

/// `[from, to]` 区间内的摊销成本合计：对区间内每一天累加 [dailyAmortizedCost]。
///
/// 区间含头含尾；`to` 早于 `from`（非法）返回 0。
///
/// 实现为逐日累加（复用 [dailyAmortizedCost] 作为单一真相，避免重复一套摊销逻辑）；
/// 逐日用日期分量构造（`DateTime(year, month, day + i)` 由构造器按日历归一化，
/// 正确跨月/跨年/闰年，不受夏令时影响）。等价的「重叠天数 × 日均」解析式结果与之
/// 一致，由单测交叉校验（验收 P1-3：二者结果需一致）。
double amortizedCostInRange(
  Iterable<AmortizedTx> txns,
  DateTime from,
  DateTime to,
) {
  final start = _dateOnly(from);
  final end = _dateOnly(to);
  if (end.isBefore(start)) return 0.0; // 非法区间
  final daySpan = end.difference(start).inDays; // start..end 之间的天数差
  var sum = 0.0;
  for (var i = 0; i <= daySpan; i++) {
    // 用日期分量构造第 i 天：构造器自动把越界 day/month 归一化（跨月/跨年/闰年），
    // 比 `d.add(Duration(days: 1))` 更稳——后者在夏令时边界会把零点漂移出当天。
    final d = DateTime(start.year, start.month, start.day + i);
    sum += dailyAmortizedCost(txns, d);
  }
  return sum;
}
