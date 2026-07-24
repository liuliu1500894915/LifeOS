# LifeOS 重构与新功能蓝图

> 整理日期：2026-07-24
> 状态：设计已锁定，**尚未动工**。开工顺序见文末「分步排期」。
> 核心原则：**先修地基，再建功能**；所有品类/字典类数据走 DB 单一真相，不硬编码；所有列表走 Drift `.watch()` 响应式流。

---

## 目录
1. [第一部分：现状诊断（数据库层 & finance）](#第一部分现状诊断)
2. [第二部分：地基改造清单](#第二部分地基改造清单)
3. [第三部分：新功能设计](#第三部分新功能设计)
   - [A. 财务 — 日常/长期支出摊销](#a-财务--日常长期支出摊销)
   - [B. 健康·摄入 — 饮食营养记录](#b-健康摄入--饮食营养记录)
   - [C. 健康·消耗 — 运动记录](#c-健康消耗--运动记录)
   - [D. 每日 — 生活瞬间 + 结构化复盘](#d-每日--生活瞬间--结构化复盘)
4. [第四部分：Schema 变更汇总](#第四部分schema-变更汇总)
5. [第五部分：分步排期](#第五部分分步排期)
6. [附：决策记录](#附决策记录)

---

## 第一部分：现状诊断

当前架构：`UI → finance_providers.dart(直接写裸 Drift 查询) → databaseProvider(单例) → AppDatabase(26 张表一个库) → native(加密)/web(不加密)`。

`dao/` 与各 feature 的 `data/repositories/` 目录均为空 —— 原本想做的分层半途而废，DB 逻辑全塞进了 presentation 层的 Provider。目前只有 finance 一个模块真正接了数据库。

### 1. 连接层
- **加密等于没加密**：`EncryptionConfig.defaultKey = 'life_os_v1_encryption_key'` 是硬编码常量，直接编进 APK，反编译即得，SQLCipher 形同虚设。而 App 本身还做了「隐私保险箱」功能，这个前提站不住。
- **Web 端完全无加密**：`WebDatabase` + indexedDb，不支持 SQLCipher 那套 PRAGMA，`PRAGMA key` 也没设。native 加密、web 明文，安全模型不一致。
- **`PRAGMA key = '${config.key}'` 字符串插值**：现在 key 是常量没事，一旦换用户输入就是注入点。应参数化或正确转义。
- **`foreign_keys = ON` 放在 `setup` 不可靠**：Drift 官方建议放 `beforeOpen`（迁移之后）；当前连 `beforeOpen` 都没有。

### 2. 迁移策略脆弱
- `onCreate` 用 `createAll()`（26 张全建），`onUpgrade` 只手动补 finance 8 张 —— 全新安装 vs 升级安装的库结构没有任何东西保证一致，最容易出线上事故。
- `AccountNotifier.build()` 里的 `// Retry once — migration may not have run yet` 重试，是被迁移坑过后打的补丁，盖住了真正的 bug。
- 没有 v1→v2 真实升级路径的迁移测试。

### 3. 响应式数据流（做得最差的一块）
- 完全没用 Drift 的 `.watch()` 流，而是手工重造响应式：每次增删改都 `state = AsyncData(await _fetchAll(db))` 全量重查。
- 转账改余额还要手动 `ref.invalidate(accountProvider)` 通知另一个 Provider，漏一个就数据不同步。
- `prev = state.valueOrNull` → 出错 `state = AsyncData(prev)` 的「乐观回滚」是**死代码**：写库前根本没改 state，回滚回去就是当前值。

### 4. 数据完整性 & 效率
- `todayTransactionsProvider`/`monthTransactionsProvider` 把整张交易表拉进内存再 `.where` 过滤，交易越多越慢。应 `WHERE` + 索引。
- `FinancialTransaction.categoryId/accountId` 是裸 text，**没有外键**（其他表都有 FK）；删账户不检查关联交易 → 孤儿交易，余额重算出错。
- **分类两套真相**：硬编码 `_defaultCategorySeeds` 与 DB `expenseCategories` 并存，交易列表用硬编码取名 → 用户自定义分类显示不出正确名称。
- 账户 `balance` 冗余：既被每笔交易增减、又能被 `updateAccount` 直接改，与「所有交易之和」无对账机制，会漂移。

### 5. 架构
- `_ensureSystemUser` 在每个 Provider 的 build() 和每次 mutation 里都调，冗余写库。
- 全 App 只有一个硬编码 `_systemUserId = 'user-001'`，但 schema 到处是 userId FK —— 多用户 schema 配单用户实现。
- `_TransactionItemNotifier` 用 `// ignore: invalid_use_of_protected_member` 直接改 `notifier.state`；Drift 行类型和手写 `TransactionItem` 两套模型来回映射，都是分层缺失导致的临时补丁。

---

## 第二部分：地基改造清单

> 这些是所有新功能的前提，**先做**。

| # | 事项 | 说明 |
|---|---|---|
| F1 | 🔑 加密 key 入设备安全存储 | 首启生成随机 key，存 `flutter_secure_storage`/Keystore/Keychain，不再硬编码。`PRAGMA key` 参数化。 |
| F2 | 🧱 规范分步迁移 | 改用 Drift `stepByStep`，`beforeOpen` 里开 FK，一步一测；补迁移测试覆盖真实升级路径。 |
| F3 | 🗂️ finance 抽 Repository/DAO | 把裸查询从 Provider 移进 `FinanceRepository`/DAO 层，作为其他模块的模板。 |
| F4 | 🌊 finance 改 `.watch()` 流 | 用 Drift stream → `StreamProvider`；删掉手动 `_fetchAll`/`invalidate`/假乐观回滚。 |
| F5 | 🔗 finance 数据完整性 | 交易补 FK + 索引；分类统一到 DB 单一真相；余额对账。 |

---

## 第三部分：新功能设计

### A. 财务 — 日常/长期支出摊销

**目标**：区分「日常即时支出」（交通/餐饮/意外）和「长期支出」（房租/影视会员/健身卡），后者按天摊平到分析里，查看时又能与日常区分开。

**核心正确性 —— 现金流 vs 成本分摊分离**：
- 房租 3000 该扣的时候照扣，账户余额当天就是 −3000（真金白银出账，余额必须准）。
- 但在**日常支出趋势分析**里，这 3000 不落在付款那天，而是按覆盖天数摊平（3000÷当月天数 ≈ 100/天）。
- 「日常支出」视图**完全不显示**这根 3000。
- **摊销是分析层的事，不动账本余额。**

**数据模型 —— 给支出加「性质」维度**（在 `FinancialTransaction` 上扩展）：
```
expenseNature: SPOT(日常) | AMORTIZED(长期摊销)     默认 SPOT
amortizeStartDate / amortizeEndDate                 仅 AMORTIZED 填（覆盖区间）
sourceSubscriptionId  (nullable, FK → SubscriptionServices)  标记"订阅自动生成的"
```

**分析引擎新增**：
```
某天 D 的长期摊销成本 = Σ (所有覆盖 D 的 AMORTIZED 支出的 金额 ÷ 实际覆盖天数)

  健身卡年卡 2000 (覆盖365天) → 每天 5.5
  房租 3000 (覆盖当月30天)    → 每天 100
  影视会员 25 (覆盖当月)      → 每天 0.8
```

**登记两条路（最后都产出带覆盖区间的 AMORTIZED 交易）**：
- **周期性**（房租/影视会员）→ 进 `SubscriptionServices`，`SUBSCRIPTION_CHECK` worker 到期时自动 post 一笔 AMORTIZED 交易（扣余额 + 带覆盖区间）。
- **一次性**（健身卡年卡）→ 普通记账时手动打开「摊销」开关、填覆盖区间。

**摊销天数口径**：按**实际覆盖天数**（房租按当月 28/30/31，年卡按 365）。

**分析页展示（区分开又能合看）**：
```
7月24日
  日常支出(SPOT)      ¥68    ← 交通12 餐饮38 意外18
  长期摊销(AMORTIZED)  ¥106   ← 房租100 + 会员0.8 + 健身卡5.5
  ─────────────────────
  真实日成本           ¥174
```
> 附带：现有 `monthExpenseProvider`/`todayExpenseProvider`（现在一把加所有支出）要改成按 SPOT / 摊销分开算。

---

### B. 健康·摄入 — 饮食营养记录

**目标**：薄荷健康/MyFitnessPal 式饮食日记 —— 食物库 + 称重记录 + 宏量营养素（热量/碳水/脂肪/蛋白质）自动计算 + 每日目标对比。

**核心计算**：食物库按**每 100g** 存营养值；吃 150g → 全部 ×1.5；一天累加对比目标 → 剩余/超标。

**数据模型**：
```
✅ 复用 UserProfile   → gender / heightCm / weightKg / birthDate（TDEE 输入，已有）
✅ 复用 WeightHistory → 体重曲线（已有）

🆕 FoodCategory（食物品类，扁平，可自定义）
   categoryId(PK) / userId / categoryName / categoryIcon / sortOrder
   isBuiltIn(bool)  ← 预置 vs 用户自建；预置可禁删
   isActive

🆕 FoodLibrary（食物库）
   foodId(PK) / foodName / categoryId(FK → FoodCategory) / isCustom
   per100g: calories / protein / fat / carbs
   defaultServingGrams

🆕 MealLog（饮食记录，分餐次）
   logId(PK) / userId / foodId(FK → FoodLibrary)
   mealType: BREAKFAST / LUNCH / DINNER / SNACK
   grams / loggedAt
   冻结快照: snapCalories / snapProtein / snapFat / snapCarbs
     （记录时把算好的营养值冻结进来，之后改食物库不影响历史；与 finance 存 amount 同理）

🆕 NutritionGoal（每日目标，每人一条）
   userId(PK)
   activityLevel: SEDENTARY / LIGHT / MODERATE / ACTIVE / VERY_ACTIVE
   goalType: CUT / MAINTAIN / BULK（减脂/维持/增肌）
   calorieTarget / proteinTarget / fatTarget / carbTarget  ← TDEE 算出、可手动覆盖
   isAutoCalculated(bool)
```

**TDEE 计算**（薄荷同款 Mifflin-St Jeor，放 `domain/tdee_calculator.dart` 纯函数、可单测）：
```
BMR：
  男: 10×kg + 6.25×cm − 5×age + 5
  女: 10×kg + 6.25×cm − 5×age − 161

TDEE = BMR × 活动系数(1.2 久坐 ~ 1.9 高强度)
热量目标 = TDEE × { 减脂 0.8 / 维持 1.0 / 增肌 1.1 }

三大营养素默认分配：
  蛋白质 = 体重kg × 1.6~2.0g
  脂肪   = 热量 × 25% ÷ 9
  碳水   = 剩余热量 ÷ 4
```
算完写进 `NutritionGoal`，用户改任意一项就把 `isAutoCalculated` 置 false。

**扩展入口（都是往表 insert，不碰代码）**：
| 想加什么 | 入口 | 数据 |
|---|---|---|
| 新食物 | 食物搜索页「+ 自定义食物」 | FoodLibrary insert (isCustom) |
| 新品类 | 品类管理页「+ 新建品类」 | FoodCategory insert (isBuiltIn=false) |

**食物库来源**：打包一份常见中餐食物 JSON（`assets/food_library.json`）首启导入 + 用户自建。

---

### C. 健康·消耗 — 运动记录

**目标**：记录每日运动/健身及卡路里消耗，与摄入组成「能量账本」。

**现状（三处各说各话，加之前必须统一）**：
- DB 表 `PetActionQuickLog` 的 `actionType='SPORT'`（宠物模块 + 午夜 worker 在用）；
- `home_providers.dart` 的 MET 计算，**体重写死 65kg**，喂的是 **mock 假数据**，没落库；
- UI 今日汇总 `caloriesOut` 来自上面的 mock。

**设计 —— 做成饮食的对称结构**：
```
能量摄入侧                        能量消耗侧
─────────────                    ─────────────
FoodLibrary(每100g营养)     ↔    运动 MET 表(代码常量, 十几个常见运动)
MealLog(克数→冻结营养快照)   ↔    🆕 ExerciseLog(分钟→冻结消耗快照)

🆕 ExerciseLog（运动/健身记录）
   logId(PK) / userId
   exerciseName(跑步/力量/瑜伽/游泳…) / durationMinutes
   intensity(可选: LOW/MEDIUM/HIGH)
   caloriesBurned  ← 冻结快照 = MET × 体重 × 时长
     ✅ 体重从 UserProfile.weightKg 取（不再写死 65）
   loggedAt
```
> MET 表就十几个常见运动，放代码常量够用；每条允许手动改消耗值，以后想加自定义运动再抽 `ExerciseLibrary` 表。

**与宠物的关系**：**健康模块独占运动记录（唯一真相）**，通过 EventBus 发运动事件，宠物**监听**事件涨精力。宠物那边的 SPORT 写入路径要改造迁到健康。

**热量口径**：**目标固定，不加回**。运动消耗只做净值展示，不抬高当日可吃额度。
```
今日: 吃 1800  −  动 300  =  净 1500   目标 1600 固定 → 净值 vs 目标一眼看清
```

---

### D. 每日 — 生活瞬间 + 结构化复盘

**目标**：白天随手拍照+文字记录生活（One Second Everyday / 小日常 式微日记）；睡前对当日结构化复盘。放同一个「每日」页面，数据分开。

**现状**：
- 复盘表 `DailyReviewLog` **已存在**（午夜 worker 读它填心情），但**无写入路径、UI 只有占位**，路由 `review-log`/`review-editor` 已占位待实现。
- 拍照+文字记录**完全没有**（无表无界面）。

**数据模型**：
```
🆕 LifeMoment（生活瞬间）
   momentId(PK) / userId / content(一段话) / moodTag / loggedAt

🆕 MomentPhoto（瞬间照片，一对多，支持多张）
   photoId(PK) / momentId(FK → LifeMoment) / photoPath / sortOrder
   （用子表而非 JSON 塞路径 —— 单一真相原则，可排序、以后可给单张加描述）

DailyReviewLog（复用 + 补全）
   reviewDate + userId (PK)
   moodTag(心情)
   + highlightText(今日高光) / improveText(待改进) / tomorrowPlanText(明日计划)  ← 结构引导新增列
   summarySnapshotJson  ← 睡前自动冻结当日全景快照
   → 补：复盘写入逻辑 + review-editor 界面
```

**复盘形式**：结构引导 + 自动带数据快照。`summarySnapshotJson` 本就是为跨模块整合留的字段 —— 睡前自动带出当日全景（数据来自已有 `DailyAggregationCache` + 午夜结算 worker，冻结成快照）：
```
今日复盘 · 7月24日   心情 😌
  💰 支出 ¥174 (日常68 + 摊销106)
  🥗 摄入 1800kcal / 目标1600  超标200
  🏃 运动 30min 消耗300
  ✅ 待办 5/7 完成
  ─────────────────────
  📝 [高光/待改进/明日计划]   📸 今日3个瞬间 →
```
> 照片以文件存 App 目录，DB 只存路径。SQLCipher 加密的是数据库，照片文件本身不加密（普通生活照暂不处理，要锁再走保险箱那套）。

---

## 第四部分：Schema 变更汇总

全部并进 **schemaVersion 3** 的分步迁移，一步一测。

**新增表（7 张）**：
- 财务：无新表（在现有表加字段）
- 健康·摄入：`FoodCategory` `FoodLibrary` `MealLog` `NutritionGoal`
- 健康·消耗：`ExerciseLog`
- 每日：`LifeMoment` `MomentPhoto`

**现有表字段扩展（3 处）**：
- `FinancialTransaction`：+ `expenseNature` + `amortizeStartDate` + `amortizeEndDate` + `sourceSubscriptionId` + 补 `categoryId`/`accountId` 外键 + 索引
- `DailyReviewLog`：+ `highlightText` + `improveText` + `tomorrowPlanText`
- `SubscriptionServices`：增强自动 post 摊销交易（逻辑，非必然加列）

**复用（不动）**：`UserProfile`、`WeightHistory`、`DailyAggregationCache`、`SubscriptionServices`、`BudgetSettings`、EventBus。

---

## 第五部分：分步排期

> 顺序原则：地基 → 财务打样 → 健康 → 每日 → 联动收口。每步跑测试再进下一步。

**阶段 0 · 地基（F1–F5）**
1. F1 加密 key 入安全存储 + `PRAGMA key` 参数化
2. F2 迁移改 `stepByStep` + `beforeOpen` 开 FK + 迁移测试框架
3. F3 抽 `FinanceRepository`/DAO
4. F4 finance 改 `.watch()` 流，删手动 refetch/invalidate/假回滚
5. F5 交易补 FK+索引、分类统一 DB、余额对账

**阶段 1 · 财务摊销**
6. `FinancialTransaction` 加摊销字段（migration step）
7. 一次性摊销开关（记账 UI）
8. 订阅到期自动 post 摊销交易（worker）
9. 分析引擎拆 SPOT/摊销 + 日常分析页三层展示

**阶段 2 · 健康·摄入**
10. `FoodCategory`/`FoodLibrary`/`MealLog`/`NutritionGoal` 建表（migration）+ 打包食物 JSON 首启导入
11. `tdee_calculator` 纯函数 + 单测
12. 食物搜索/称重/记录 UI（分餐次）+ 自定义食物/品类入口
13. 每日营养环形进度 + 目标对比

**阶段 3 · 健康·消耗**
14. `ExerciseLog` 建表 + MET 常量表
15. 运动记录 UI + 消耗计算（体重取 Profile）
16. 能量账本合并展示（摄入 − 消耗 = 净值）

**阶段 4 · 每日**
17. `LifeMoment`/`MomentPhoto` 建表 + 拍照/多图/文字记录 UI + 时间线
18. `DailyReviewLog` 加列 + 复盘写入 + review-editor 界面 + 自动数据快照

**阶段 5 · 联动收口**
19. 运动入口从宠物迁到健康，宠物改监听 EventBus 事件
20. 首页 today summary、午夜结算 worker 改读新数据源（ExerciseLog/MealLog）
21. 复盘 `summarySnapshotJson` 聚合各模块

---

## 附：决策记录

| 主题 | 决策 |
|---|---|
| 推进顺序 | **先修完地基再建功能** |
| 财务·长期支出登记 | 周期性进订阅表（自动摊）+ 一次性走交易摊销开关 |
| 财务·摊销天数 | 按**实际覆盖天数** |
| 财务·余额 | 照旧真实扣款；摊销仅分析层视图，不动余额 |
| 健康·目标设定 | 按身高体重活动量 **TDEE 推荐**（可手动覆盖） |
| 健康·食物库来源 | 打包常见食物 + 用户自建 |
| 健康·记录粒度 | 分餐次（早/午/晚/加餐） |
| 健康·营养值 | 记录时**冻结快照** |
| 健康·食物品类 | 独立成表、**扁平**、可自定义、DB 单一真相 |
| 健康·运动 vs 宠物 | 健康模块统一，宠物**监听事件** |
| 健康·热量口径 | 目标固定，运动消耗**不加回**可吃额度 |
| 每日·瞬间照片 | **多张**（子表 MomentPhoto） |
| 每日·复盘形式 | **结构引导 + 自动带数据快照** |
