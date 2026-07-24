# LifeOS 开发执行计划（工程师执行版）

> 版本：v1 · 2026-07-24
> 配套文档：[LifeOS-重构与新功能蓝图.md](./LifeOS-重构与新功能蓝图.md)（设计依据，本文档是其可执行化）
> 适用范围：地基重构 + 财务摊销 + 健康摄入/消耗 + 每日打卡复盘
> 技术栈：Flutter · Riverpod 2.x · Drift 2.25 · SQLCipher · go_router · workmanager

**阅读顺序**：先读 [§1 开发规范](#1-开发规范)（强制，所有人）→ 再读 [§2 任务分解](#2-任务分解)（认领任务）→ 写代码时查 [§3 技术规格](#3-技术规格附录) → 提交前对照 [§4 验收清单](#4-验收清单)。

---

## 0. 如何使用本文档

- **任务粒度 = 1 个 PR**。每个任务有唯一 ID（如 `P0-2`）、依赖、验收标准、必需测试。
- **验收标准是二元的**（做到/没做到），既是工程师的自检项，也是后续 Code Review 的依据。
- **禁止跨阶段并行改同一批文件**；阶段间有依赖，按 §2 顺序推进。
- 遇到设计歧义 → 停下来问，**不要自行发挥**新增数据结构或改变已锁定决策（见蓝图「决策记录」）。

---

## 1. 开发规范

### 1.1 分层架构（强制）

```
presentation/   页面、widget、Riverpod Provider —— 只做 UI 与状态编排
    │  （只允许调用 repository / domain，禁止出现任何 db.select / db.into / Companion）
domain/         纯 Dart 业务逻辑与计算 —— 无 Flutter、无 Drift 依赖，可独立单测
    │
data/
  ├─ dao/          Drift DAO：所有 SQL/查询集中于此
  └─ repositories/ Repository：对 Provider 暴露的接口，读用 Stream、写用 Future
```

**铁律**：
- ❌ presentation 层**禁止**直接访问 `AppDatabase` / `databaseProvider` / 写裸 Drift 查询。（当前 `finance_providers.dart` 是反面教材，本次要拆掉。）
- ✅ 每个 feature 提供一个 `XxxRepository` 抽象接口 + 一个 Drift 实现；Provider 依赖**接口**，便于测试替换。
- ✅ 计算逻辑（TDEE、摊销、营养换算）放 `domain/`，不碰 DB 与 UI。

### 1.2 数据库规范（强制）

1. **迁移**：统一使用 Drift **versioned schema + `stepByStep`**（见 §3.2）。禁止再写「`createAll` + 手写 `onUpgrade` 补表」的混合模式。每次改 schema：
   - `schemaVersion` +1；
   - 用 `drift_dev schema dump` 快照新版本；
   - 用 `drift_dev schema steps` 生成迁移步骤；
   - 补一条迁移测试（见 §1.9）。
2. **外键**：所有跨表引用必须 `.references(...)`；`PRAGMA foreign_keys = ON` 放在 **`beforeOpen`**，不放 `setup`。
3. **索引**：凡是会按某列过滤/排序的查询列（如 `loggedAt`、`userId`、`accountId`），必须建索引。禁止「全表 `.get()` 后在 Dart 里 `.where` 过滤」。
4. **快照冻结**：交易金额、营养值、运动消耗等「历史不可变」数据，记录时把**计算结果冻结**存表，不依赖引用表的当前值。
5. **单一真相**：字典/品类类数据（食物品类、支出分类）一律存 DB，**禁止**在代码里再维护一份硬编码列表当第二真相。（当前 finance 的 `_defaultCategorySeeds` 是反面教材。）
6. **命名**：Table 类 `PascalCase`（单数，如 `MealLog`）；列 getter `camelCase`（Drift 自动映射为 `snake_case` 列）；主键统一 `xxxId`。新表加进 `tables/` 对应文件并在 `tables.dart` barrel 导出、在 `@DriftDatabase` 注册。

### 1.3 状态管理规范（Riverpod，强制）

- **读**：一律用 Repository 暴露的 `Stream` → `StreamProvider` / `AsyncNotifier` 内 `ref.watch` 该流。UI 数据随 DB 自动更新。
- **禁止**：写库后手动 `state = AsyncData(await _fetchAll())` 全量重查；禁止靠 `ref.invalidate(otherProvider)` 维持跨 Provider 同步。（`.watch()` 天然解决关联刷新。）
- **禁止**：无意义的「乐观回滚」死代码（`prev = state.valueOrNull` → 出错还原）。如需真乐观更新，必须在 await **之前**改 state，并在 catch 里还原，且写注释说明。
- 派生数据（今日/本月汇总）用 `Provider` 组合，基于流式源数据计算。

### 1.4 Repository 规范

- 接口放 `data/repositories/xxx_repository.dart`（抽象类）；实现放同目录 `xxx_repository_drift.dart`。
- 方法命名：读 `watchXxx()` 返回 `Stream<...>`；一次性读 `getXxx()`；写 `addXxx/updateXxx/deleteXxx` 返回 `Future<void>`。
- 事务性写操作（如「插入交易 + 改账户余额」）必须包在 `db.transaction(() async {...})` 内。
- 余额这类累加更新用 SQL 表达式增量更新（`balance = balance + ?`），不要「先读再写回」。

### 1.5 安全规范（强制）

- ❌ 禁止硬编码任何密钥/口令。加密 key 首启随机生成，存 `flutter_secure_storage`（Android Keystore / iOS Keychain 背书）。
- `PRAGMA key` 用参数化/正确转义，不用字符串插值拼用户输入。
- 不在日志打印 key、PIN、文档号等敏感值。`debugPrint` 仅限非敏感调试信息，且发版前清理。

### 1.6 代码风格 & Lint

- 遵循 `flutter_lints`（项目已启用）。**PR 必须 `flutter analyze` 零新增告警。**
- `// ignore:` 抑制 lint 必须**同行写明理由**；无理由的 ignore 不予合并。（当前 `invalid_use_of_protected_member` 那处要一并消除。）
- 注释语言与现有代码保持一致（关键逻辑中文/英文均可，风格统一）。公共 API 写 `///` doc 注释。

### 1.7 EventBus 规范

- 跨模块通知用现有 EventBus（`lib/core/event_bus/`）。事件类：不可变、`const` 构造、命名必填参数，按「// ── 源 → 目标 ──」分组，与现有风格一致（参考 `events.dart` 的 `SubscriptionBillingEvent`）。
- 事件只携带接收方所需最小数据，不传整行实体。

### 1.8 测试规范（强制，PR 必带）

| 类型 | 要求 | 工具 |
|---|---|---|
| **纯逻辑单测** | `domain/` 下计算（TDEE、摊销、营养换算）必须表驱动单测，覆盖边界（0/空档/闰月/缺字段） | `flutter_test` |
| **DAO/Repository 集成测** | 在 `NativeDatabase.memory()` 上测 CRUD、事务、FK 约束 | `drift/native` |
| **迁移测** | 每次 schema 变更补 v(N-1)→vN 迁移验证 + 数据保留测（旧数据不丢） | `drift_dev` schema 工具 |
| **回归** | 改动已有逻辑必须补/改对应测试 | — |

- **全部测试必须绿**才可提 PR：`flutter analyze && flutter test`。
- 目标覆盖：`domain/` 计算逻辑 ≥ 90%；Repository 主路径全覆盖。

### 1.9 Git & PR 规范

- 分支：`feat/<模块>-<任务>`，如 `feat/health-meal-log`、`refactor/db-migration-stepbystep`。
- Commit：Conventional Commits（`feat:` `fix:` `refactor:` `test:` `chore:`）。
- **1 任务 = 1 PR**，控制体量（建议 < 400 行 diff，超了先拆）。
- PR 描述必须包含：① 对应任务 ID；② 逐条勾选验收标准；③ 测试说明；④ 是否涉及 migration（涉及则附升级验证结果）。

### 1.10 Definition of Done（通用完成定义）

一个任务「完成」当且仅当全部满足：

- [ ] 符合 §1.1 分层（presentation 无 DB 访问）
- [ ] 读用 Stream，无手动 refetch/invalidate（除非注释说明的正当例外）
- [ ] 新增/改动逻辑有测试且全绿；`flutter analyze` 零新增告警
- [ ] 涉及 schema 的：迁移用 stepByStep、有迁移测试、v2 旧库能升级不丢数据
- [ ] 无硬编码密钥、无第二真相、无未说明的 `// ignore:`
- [ ] PR 描述勾选完验收标准

### 1.11 禁止事项清单（勿重蹈现有代码覆辙）

| ❌ 反面模式（现存于代码） | ✅ 正确做法 |
|---|---|
| presentation 里写 `db.select/into` | 走 Repository/DAO |
| 硬编码字典 + DB 表两套真相 | 品类/分类只存 DB |
| 写库后 `_fetchAll` 全量重查 + `invalidate` | `.watch()` 流 |
| `prev`→出错还原的死代码 | 删除或写成真乐观更新 |
| 全表 `.get()` 后 Dart `.where` 过滤 | `WHERE` + 索引 |
| 每个 build/mutation 调 `_ensureSystemUser` | 启动时一次性 ensure |
| 硬编码加密 key | secure storage |
| `createAll` + 手写 `onUpgrade` 混合迁移 | versioned stepByStep |
| 交易表无 FK | categoryId/accountId 加 FK |

---

## 2. 任务分解

> 阶段严格串行；阶段内任务可按依赖并行。ID 对应蓝图「分步排期」。

### 阶段 0 · 地基（阻塞所有后续，最高优先级）

**P0-1 加密 key 入安全存储**
- 依赖：无
- 范围：`lib/core/crypto/encryption_config.dart`、`database_connection_native.dart`、新增 `key_store.dart`
- 规格：引入 `flutter_secure_storage`；首启检测无 key 则生成 32 字节随机值（hex/base64）写入；`_openConnection` 从 secure storage 读 key；`PRAGMA key` 参数化。Web 端策略见验收。
- 验收：
  - [ ] 卸载重装后 key 变化、旧库无法解密（预期，因本地库随之清除）；正常启动能持续解密同一库
  - [ ] 源码中 grep 不到明文常量 key
  - [ ] Web 端：明确降级策略（无 SQLCipher）并在代码注释 + 本文档记录，不静默明文
- 测试：key 生成/读取单测；解密开库集成测

**P0-2 迁移改 versioned stepByStep + beforeOpen 开 FK**
- 依赖：无（可与 P0-1 并行）
- 范围：`app_database.dart`、新增 `schema_versions.dart`（生成）、`drift_schemas/`、`test/migration/`
- 规格：见 §3.2。先快照当前 v2 schema，落地 `stepByStep` 框架与 `beforeOpen` FK；本任务**不**加新表（仅框架 + 保持 v2 行为等价）。
- 验收：
  - [ ] `onUpgrade` 改为 `stepByStep`；`beforeOpen` 内 `PRAGMA foreign_keys = ON`
  - [ ] 全新安装（onCreate）与迁移安装结构一致（迁移验证测试通过）
  - [ ] 删除 `finance_providers.dart` 中「Retry once — migration may not have run」重试补丁（P0-4 一并）
- 测试：`drift_dev schema generate` 生成的 schema 校验测；v1/v2→当前的迁移测

**P0-3 抽 FinanceRepository / DAO**
- 依赖：P0-2
- 范围：`lib/features/finance/data/{dao,repositories}/`
- 规格：见 §3.6。把 `finance_providers.dart` 里的所有查询迁进 DAO/Repository；Provider 改为依赖 `FinanceRepository` 接口。
- 验收：
  - [ ] `finance_providers.dart` 内无任何 `db.` 调用
  - [ ] Repository 有抽象接口 + Drift 实现
  - [ ] `_ensureSystemUser` 收敛为启动时一次（提供 `SystemBootstrap`），不再散落各处
- 测试：Repository CRUD/事务/FK 集成测

**P0-4 finance 改 .watch() 流**
- 依赖：P0-3
- 范围：`finance_providers.dart` 全量
- 规格：账户/交易/分类/资产/订阅/预算读取改为 `repo.watchXxx()` 流；删除手动 `_fetchAll`、`ref.invalidate`、死乐观回滚；消除 `invalid_use_of_protected_member`。
- 验收：
  - [ ] 加一笔交易后，账户余额 UI **无需手动 invalidate** 自动更新
  - [ ] 无 `_fetchAll` 全量重查、无 `prev` 死代码
  - [ ] `flutter analyze` 无 `invalid_use_of_protected_member`
- 测试：流式更新回归测（写入触发流发射新值）

**P0-5 finance 数据完整性**
- 依赖：P0-3
- 范围：`finance_tables.dart`、finance DAO、迁移
- 规格：`FinancialTransaction.categoryId/accountId` 加 FK（见 §3.1 注）；给 `loggedAt`、`accountId` 建索引；分类统一到 DB（移除 `_defaultCategorySeeds` 作为渲染真相，改从 `expenseCategories` 读，交易列表用 DB join 取分类名）；删账户前校验关联交易。
- 验收：
  - [ ] 交易列表分类名来自 DB 而非硬编码
  - [ ] 删除有交易的账户会被拦截或级联策略明确（二选一，注释说明）
  - [ ] 有索引：`EXPLAIN QUERY PLAN` 命中索引（截图/说明）
- 测试：FK 约束测、索引查询测

---

### 阶段 1 · 财务摊销

**P1-1 交易表加摊销字段**
- 依赖：P0-5
- 范围：`finance_tables.dart` + 迁移（schemaVersion→3 起步，本字段属 v3）
- 规格：见 §3.1（`expenseNature/amortizeStartDate/amortizeEndDate/sourceSubscriptionId`）。
- 验收：[ ] 字段加入且默认 `SPOT`；[ ] 旧交易迁移后默认 `SPOT` 不受影响；[ ] 迁移测试通过
- 测试：迁移 + 默认值测

**P1-2 一次性摊销开关（记账 UI）**
- 依赖：P1-1
- 范围：`transaction_drawer.dart` / 记账页
- 规格：记账时可切换「日常/长期」；选长期则填覆盖起止日期，写入 `AMORTIZED` + 区间。余额照常扣（现金流不变）。
- 验收：[ ] 能创建一笔 AMORTIZED 交易并带合法区间（end ≥ start）；[ ] 账户余额按全额扣减
- 测试：Repository 写入 + 校验测

**P1-3 摊销算法（domain）**
- 依赖：P1-1
- 范围：`lib/features/finance/domain/amortization.dart`
- 规格：见 §3.3。纯函数 `dailyAmortizedCost`、`amortizedCostInRange`。
- 验收：[ ] 覆盖闰月/单日/跨月/边界包含；[ ] `coverageDays ≥ 1` 守卫
- 测试：表驱动单测（必须，边界齐全）

**P1-4 订阅到期自动 post 摊销交易**
- 依赖：P1-1、P1-3
- 范围：`SUBSCRIPTION_CHECK` worker / `midnight_settlement_service` 或订阅服务
- 规格：订阅到期时，post 一笔 `AMORTIZED` 交易（金额=账单额，区间=本计费周期，`sourceSubscriptionId` 回填，扣对应账户余额），并推进 `nextBillingDate`。幂等：同一订阅同一周期不重复 post。复用/发 `SubscriptionBillingEvent`。
- 验收：[ ] 到期生成交易且余额扣减；[ ] 重复执行不重复入账（幂等）；[ ] 区间=计费周期实际天数
- 测试：幂等测、周期推进测

**P1-5 分析拆 SPOT/摊销 + 日常分析页三层展示**
- 依赖：P1-3
- 范围：finance providers（`todayExpenseProvider`/`monthExpenseProvider` 等）+ 分析页
- 规格：日/月支出拆成「日常(SPOT)」「长期摊销」两条；页面展示三层（日常 / 摊销 / 真实日成本）。摊销值来自 §3.3。
- 验收：[ ] 日常视图不含 AMORTIZED 全额尖峰；[ ] 三层数值自洽（日常+摊销=真实日成本）
- 测试：聚合计算测

---

### 阶段 2 · 健康·摄入

**P2-1 建表 + 打包食物库首启导入**
- 依赖：P0-2
- 范围：新增 `lib/core/database/tables/health_tables.dart`（`FoodCategory/FoodLibrary/MealLog/NutritionGoal`）、`assets/food_library.json`、`pubspec.yaml` assets、迁移 v3
- 规格：表定义见 §3.1；首启把 JSON 导入 `FoodLibrary` + seed 预置 `FoodCategory`（`isBuiltIn=true`）。导入幂等（已导入不重复）。
- 验收：[ ] 首启后食物库/品类非空；[ ] 二次启动不重复导入；[ ] 索引 `MealLog(userId, loggedAt)` 存在
- 测试：建表 CRUD 测、导入幂等测

**P2-2 TDEE 计算（domain）**
- 依赖：无（纯逻辑，可提前）
- 范围：`lib/features/health/domain/tdee_calculator.dart`
- 规格：见 §3.4。输入 gender/身高/体重/年龄/活动量/目标类型 → 输出四项目标。缺字段返回 `null` 并提示补全。
- 验收：[ ] 男女公式正确；[ ] 活动系数与目标系数正确；[ ] 缺 profile 字段安全降级
- 测试：表驱动单测（必须）

**P2-3 食物搜索/称重/记录 UI（分餐次）+ 自定义入口**
- 依赖：P2-1
- 范围：`lib/features/health/presentation/`（页面 + widgets）+ HealthRepository
- 规格：食物搜索（按品类/关键字）→ 选食物 → 输入克数（默认 `defaultServingGrams`）→ 选餐次 → 打卡，写 `MealLog` 并**冻结** `snap*`（克数×每100g÷100）。「+自定义食物」写 `FoodLibrary(isCustom)`；「+新建品类」写 `FoodCategory(isBuiltIn=false)`。
- 验收：[ ] `snap*` 冻结正确；[ ] 自定义食物/品类入口可用且入 DB；[ ] 分餐次记录与展示
- 测试：营养换算测、写入测

**P2-4 每日营养环形进度 + 目标对比**
- 依赖：P2-2、P2-3
- 范围：health providers + 首页/健康页 widget
- 规格：`.watch()` 当日 `MealLog` → SUM 四项 → 对比 `NutritionGoal` → 剩余/超标。目标未设时引导走 TDEE 或手填。
- 验收：[ ] 当日数据变化图表自动刷新；[ ] 超标/剩余显示正确；[ ] 改目标即时反映
- 测试：汇总测

---

### 阶段 3 · 健康·消耗

**P3-1 ExerciseLog 建表 + MET 常量**
- 依赖：P0-2
- 范围：`health_tables.dart`（+`ExerciseLog`）、`lib/features/health/domain/met_table.dart`、迁移 v3
- 规格：表见 §3.1；MET 常量表（跑步/走路/骑行/游泳/力量/瑜伽…）放 domain 常量。索引 `ExerciseLog(userId, loggedAt)`。
- 验收：[ ] 建表 + 索引；[ ] MET 表可查
- 测试：CRUD 测

**P3-2 运动记录 UI + 消耗计算（体重取 Profile）**
- 依赖：P3-1
- 范围：health presentation + HealthRepository
- 规格：选运动+时长 →（MET×体重×时长/60）算消耗，体重取 `UserProfile.weightKg`（缺则用合理默认并提示补全，**不写死 65**），可手动改；写 `ExerciseLog` 冻结 `caloriesBurned`。
- 验收：[ ] 消耗计算用真实体重；[ ] 可手动覆盖；[ ] 冻结存储
- 测试：消耗计算测（含缺体重降级）

**P3-3 能量账本合并展示**
- 依赖：P2-4、P3-2
- 范围：健康页汇总
- 规格：`.watch()` 当日摄入与消耗 → 展示「吃 − 动 = 净」，对比固定目标（**消耗不加回**额度）。
- 验收：[ ] 净值 = 摄入−消耗；[ ] 目标固定不被消耗抬高
- 测试：净值计算测

---

### 阶段 4 · 每日

**P4-1 LifeMoment + MomentPhoto 建表 + 记录 UI**
- 依赖：P0-2
- 范围：`daily_tables.dart`（+`LifeMoment/MomentPhoto`）、迁移 v3、daily presentation、`image_picker` 接入
- 规格：拍照/多图 + 文字 + 心情 → 写 `LifeMoment` + 多条 `MomentPhoto(sortOrder)`；照片存 App 文档目录，DB 存路径；时间线展示。
- 验收：[ ] 多图有序存取；[ ] 删除 moment 级联删照片记录（策略注释说明）；[ ] 时间线 `.watch()` 自动刷新
- 测试：一对多写入/读取测

**P4-2 复盘：DailyReviewLog 加列 + 写入 + editor + 自动快照**
- 依赖：P0-2；（快照数据依赖 P1-5/P2-4/P3-3 已就绪更佳）
- 范围：`daily_tables.dart`（+`highlightText/improveText/tomorrowPlanText`）、迁移 v3、`review-editor` 页（路由已占位）、daily providers
- 规格：结构化引导（高光/待改进/明日计划）+ 心情；打开时自动聚合当日全景（支出/摄入/运动/待办）冻结进 `summarySnapshotJson`；关联展示当日 moments。
- 验收：[ ] 复盘可写入/编辑；[ ] `summarySnapshotJson` 冻结当日快照；[ ] 历史复盘不随后续数据变化
- 测试：写入 + 快照冻结测

---

### 阶段 5 · 联动收口

**P5-1 运动入口迁到健康，宠物监听事件**
- 依赖：P3-2
- 范围：`event_bus/events.dart`（+`ExerciseLoggedEvent`，见 §3.5）、宠物模块、`home_providers.dart`
- 规格：运动只经健康 `ExerciseLog` 记录（唯一真相），发 `ExerciseLoggedEvent`；宠物订阅该事件涨精力，移除宠物侧 SPORT 的独立消耗写入；`home_providers` 的 mock 运动数据下线。
- 验收：[ ] 运动仅一处入账（无重复计）；[ ] 宠物精力经事件驱动；[ ] home mock 消耗移除
- 测试：事件驱动测

**P5-2 首页/午夜结算改读新数据源**
- 依赖：P5-1、P2-4
- 范围：`midnight_settlement_service.dart`、`home_providers.dart`
- 规格：`DailyAggregationCache` 的 calorieIn/Out 改从 `MealLog`/`ExerciseLog` 汇总（不再从宠物 FEED/SPORT）；首页 today summary 同步。
- 验收：[ ] 结算 calorieIn/Out 来自新表；[ ] 首页汇总一致
- 测试：结算汇总测

**P5-3 复盘聚合各模块**
- 依赖：P4-2、P1-5、P3-3
- 范围：复盘快照聚合器
- 规格：`summarySnapshotJson` 聚合财务(日常+摊销)/健康(摄入·消耗·净值)/待办完成率。
- 验收：[ ] 快照字段齐全且与各模块当日值一致
- 测试：聚合一致性测

---

## 3. 技术规格附录

### 3.1 新表 / 字段 Drift 定义

> 放置：健康表 → 新建 `tables/health_tables.dart`；每日表追加到 `tables/daily_tables.dart`；财务字段改 `tables/finance_tables.dart`。均需在 `tables.dart` barrel 导出并在 `@DriftDatabase(tables: [...])` 注册。列命名遵循现有风格。

```dart
// ── health_tables.dart ──

class FoodCategory extends Table {
  TextColumn get categoryId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text().withLength(min: 1, max: 36).references(UserAccounts, #userId)();
  TextColumn get categoryName => text().withLength(max: 30)();
  TextColumn get categoryIcon => text().withLength(max: 10)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  @override
  Set<Column> get primaryKey => {categoryId};
}

class FoodLibrary extends Table {
  TextColumn get foodId => text().withLength(min: 1, max: 36)();
  // 预置食物归系统用户(user-001)，isCustom=false；与现有单系统用户约定一致
  TextColumn get userId =>
      text().withLength(min: 1, max: 36).references(UserAccounts, #userId)();
  TextColumn get foodName => text().withLength(max: 100)();
  TextColumn get categoryId =>
      text().withLength(min: 1, max: 36).references(FoodCategory, #categoryId)();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  RealColumn get caloriesPer100g => real()();
  RealColumn get proteinPer100g => real().withDefault(const Constant(0.0))();
  RealColumn get fatPer100g => real().withDefault(const Constant(0.0))();
  RealColumn get carbsPer100g => real().withDefault(const Constant(0.0))();
  RealColumn get defaultServingGrams => real().withDefault(const Constant(100.0))();
  @override
  Set<Column> get primaryKey => {foodId};
}

class MealLog extends Table {
  TextColumn get logId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text().withLength(min: 1, max: 36).references(UserAccounts, #userId)();
  TextColumn get foodId =>
      text().withLength(min: 1, max: 36).references(FoodLibrary, #foodId)();
  TextColumn get mealType => text().check(
        mealType.equals('BREAKFAST') |
        mealType.equals('LUNCH') |
        mealType.equals('DINNER') |
        mealType.equals('SNACK'),
      )();
  RealColumn get grams => real()();
  // 冻结快照（= grams × per100 / 100）
  RealColumn get snapCalories => real()();
  RealColumn get snapProtein => real()();
  RealColumn get snapFat => real()();
  RealColumn get snapCarbs => real()();
  DateTimeColumn get loggedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {logId};
}

class NutritionGoal extends Table {
  TextColumn get userId =>
      text().withLength(min: 1, max: 36).references(UserAccounts, #userId)();
  TextColumn get activityLevel => text().check(
        activityLevel.equals('SEDENTARY') |
        activityLevel.equals('LIGHT') |
        activityLevel.equals('MODERATE') |
        activityLevel.equals('ACTIVE') |
        activityLevel.equals('VERY_ACTIVE'),
      )();
  TextColumn get goalType => text().check(
        goalType.equals('CUT') |
        goalType.equals('MAINTAIN') |
        goalType.equals('BULK'),
      )();
  RealColumn get calorieTarget => real()();
  RealColumn get proteinTarget => real()();
  RealColumn get fatTarget => real()();
  RealColumn get carbTarget => real()();
  BoolColumn get isAutoCalculated => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {userId};
}

class ExerciseLog extends Table {
  TextColumn get logId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text().withLength(min: 1, max: 36).references(UserAccounts, #userId)();
  TextColumn get exerciseName => text().withLength(max: 50)();
  IntColumn get durationMinutes => integer()();
  TextColumn get intensity => text().check(
        intensity.equals('LOW') |
        intensity.equals('MEDIUM') |
        intensity.equals('HIGH'),
      ).nullable()();
  RealColumn get caloriesBurned => real()();  // 冻结快照
  DateTimeColumn get loggedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {logId};
}
```

```dart
// ── daily_tables.dart 追加 ──

class LifeMoment extends Table {
  TextColumn get momentId => text().withLength(min: 1, max: 36)();
  TextColumn get userId =>
      text().withLength(min: 1, max: 36).references(UserAccounts, #userId)();
  TextColumn get content => text().withLength(max: 2000).nullable()();
  TextColumn get moodTag => text().withLength(max: 20).nullable()();
  DateTimeColumn get loggedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {momentId};
}

class MomentPhoto extends Table {
  TextColumn get photoId => text().withLength(min: 1, max: 36)();
  TextColumn get momentId =>
      text().withLength(min: 1, max: 36).references(LifeMoment, #momentId)();
  TextColumn get photoPath => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {photoId};
}

// DailyReviewLog 追加三列（结构引导）
//   TextColumn get highlightText    => text().nullable()();
//   TextColumn get improveText      => text().nullable()();
//   TextColumn get tomorrowPlanText => text().nullable()();
```

```dart
// ── finance_tables.dart：FinancialTransaction 追加 ──
//   TextColumn get expenseNature => text().withLength(max: 10)
//       .withDefault(const Constant('SPOT'))
//       .check(expenseNature.equals('SPOT') | expenseNature.equals('AMORTIZED'))();
//   DateTimeColumn get amortizeStartDate => dateTime().nullable()();
//   DateTimeColumn get amortizeEndDate   => dateTime().nullable()();
//   TextColumn get sourceSubscriptionId  => text().withLength(min: 1, max: 36)
//       .nullable().references(SubscriptionServices, #subscriptionId)();
//
// 注：categoryId / accountId 补 FK（P0-5）——
//   categoryId .references(ExpenseCategories, #categoryId)
//   accountId  .references(PaymentAccounts, #accountId)
//   若历史数据有孤儿引用，迁移中先清洗再加约束。
```

**索引（在 `@DriftDatabase` 或迁移中创建）**：
- `MealLog(userId, loggedAt)`、`ExerciseLog(userId, loggedAt)`
- `FinancialTransaction(loggedAt)`、`FinancialTransaction(accountId)`、`FinancialTransaction(expenseNature)`
- `LifeMoment(userId, loggedAt)`、`MomentPhoto(momentId)`

### 3.2 迁移 v2 → v3（versioned stepByStep）

**一次性准备**（引入 Drift schema 工具链）：
```bash
# 1) 先快照“当前 v2”结构（改任何东西之前）
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/

# 2) 加完 v3 的表/列、把 schemaVersion 改为 3 后，再次快照
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/

# 3) 生成 stepByStep 迁移辅助
dart run drift_dev schema steps drift_schemas/ lib/core/database/schema_versions.dart

# 4) 生成迁移测试用的各版本 schema
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
```

**app_database.dart**：
```dart
@override
int get schemaVersion => 3;

@override
MigrationStrategy get migration => MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: stepByStep(
        from1To2: (m, schema) async {
          // 保留原 v1→v2：补 finance 相关表（用生成的 schema 引用）
        },
        from2To3: (m, schema) async {
          // finance 新列
          await m.addColumn(schema.financialTransaction, schema.financialTransaction.expenseNature);
          await m.addColumn(schema.financialTransaction, schema.financialTransaction.amortizeStartDate);
          await m.addColumn(schema.financialTransaction, schema.financialTransaction.amortizeEndDate);
          await m.addColumn(schema.financialTransaction, schema.financialTransaction.sourceSubscriptionId);
          // daily 新列
          await m.addColumn(schema.dailyReviewLog, schema.dailyReviewLog.highlightText);
          await m.addColumn(schema.dailyReviewLog, schema.dailyReviewLog.improveText);
          await m.addColumn(schema.dailyReviewLog, schema.dailyReviewLog.tomorrowPlanText);
          // 新表
          await m.createTable(schema.foodCategory);
          await m.createTable(schema.foodLibrary);
          await m.createTable(schema.mealLog);
          await m.createTable(schema.nutritionGoal);
          await m.createTable(schema.exerciseLog);
          await m.createTable(schema.lifeMoment);
          await m.createTable(schema.momentPhoto);
          // 索引
          await m.database.customStatement(
            'CREATE INDEX IF NOT EXISTS idx_meal_user_date ON meal_log(user_id, logged_at)');
          // ……其余索引同理
        },
      ),
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        // 首次创建：seed 系统用户 + 预置品类/食物导入（幂等）
      },
    );
```
> 说明：FK 约束加到既有表（P0-5 的 categoryId/accountId）在 SQLite 需「建新表→迁数据→换名」，Drift 的 `m.alterTable(TableMigration(...))` 支持，按 drift 文档处理。

### 3.3 摊销算法（domain/amortization.dart）

```dart
/// 单日摊销成本：所有覆盖该日的 AMORTIZED 交易，按“金额 ÷ 覆盖天数(含头含尾)”求和。
double dailyAmortizedCost(Iterable<AmortizedTx> txns, DateTime day) {
  final d = DateUtils.dateOnly(day);
  var sum = 0.0;
  for (final t in txns) {
    final start = DateUtils.dateOnly(t.start);
    final end = DateUtils.dateOnly(t.end);
    if (d.isBefore(start) || d.isAfter(end)) continue;
    final coverageDays = end.difference(start).inDays + 1; // 含两端
    if (coverageDays < 1) continue;                        // 守卫
    sum += t.amount / coverageDays;
  }
  return sum;
}
```
- 区间**含头含尾**（`inDays + 1`）。
- 边界必测：单日（start==end→coverageDays=1）、闰月、跨月、day 落在端点、day 在区间外。
- `amortizedCostInRange(txns, from, to)` = 对 [from,to] 每日累加（或用重叠天数解析式，二者结果需一致，测试校验）。

### 3.4 TDEE 算法（domain/tdee_calculator.dart）

```dart
// BMR (Mifflin-St Jeor)
//   男:  10*kg + 6.25*cm - 5*age + 5
//   女:  10*kg + 6.25*cm - 5*age - 161
//   OTHER: 取男女均值
// 活动系数: SEDENTARY 1.2 / LIGHT 1.375 / MODERATE 1.55 / ACTIVE 1.725 / VERY_ACTIVE 1.9
// 目标系数: CUT 0.8 / MAINTAIN 1.0 / BULK 1.1
// 宏量默认: 蛋白 = kg * 1.6 ; 脂肪 = 热量*0.25/9 ; 碳水 = (热量 - 蛋白*4 - 脂肪*9)/4
//
// age 由 birthDate 与当天计算。任一必需字段(gender/身高/体重/birthDate)缺失 → 返回 null。
```
- 输出四项目标（热量/蛋白/脂肪/碳水），返回不可变结果对象。
- 必测：男/女/OTHER、各活动/目标系数、缺字段降级、极端值不产生负碳水（钳制 ≥ 0）。

### 3.5 EventBus 新事件

```dart
// ── Health → Pet ──
class ExerciseLoggedEvent {
  const ExerciseLoggedEvent({
    required this.exerciseName,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.loggedAt,
  });
  final String exerciseName;
  final int durationMinutes;
  final double caloriesBurned;
  final DateTime loggedAt;
}
```

### 3.6 Repository 接口签名（示例：Finance）

```dart
abstract interface class FinanceRepository {
  // 读（流）
  Stream<List<PaymentAccount>> watchAccounts();
  Stream<List<FinancialTransactionData>> watchTransactions();
  Stream<List<ExpenseCategory>> watchCategories();
  // 写
  Future<void> addTransaction({
    required String flowType,
    required double amount,
    required String categoryId,
    required String accountId,
    String? remark,
    DateTime? loggedAt,
    String expenseNature = 'SPOT',
    DateTime? amortizeStart,
    DateTime? amortizeEnd,
    String? sourceSubscriptionId,
  });
  Future<void> deleteTransaction(String id);
  Future<void> addAccount(...);
  // ……
}
```
- `HealthRepository` / `DailyRepository` 依同样约定（`watchXxx` 流 + `addXxx/updateXxx/deleteXxx`）。
- 事务写包 `db.transaction`；余额增量更新用 SQL 表达式。

---

## 4. 验收清单

> 提 PR 前逐条自检；Code Review 逐条核对。任一不过则打回。

**通用（每个 PR）**
- [ ] presentation 层无 `db.`/`Companion`/裸查询
- [ ] 读用 `.watch()` 流；无手动 `_fetchAll`/`invalidate`/死乐观回滚
- [ ] `flutter analyze` 零新增告警；无未说明 `// ignore:`
- [ ] 新增/改动逻辑有测试；`flutter test` 全绿
- [ ] 无硬编码密钥；无字典第二真相

**涉及 schema**
- [ ] `schemaVersion` 已增；用 `stepByStep`；有迁移测试
- [ ] v2 旧库升级后**数据不丢**（迁移数据保留测通过）
- [ ] 新表/新列已注册、已导出、有必要索引
- [ ] `beforeOpen` 开 FK；跨表引用有 `.references`

**涉及计算（domain）**
- [ ] 纯函数、无 Flutter/Drift 依赖
- [ ] 表驱动单测覆盖边界（闰月/单日/缺字段/极端值）

**涉及历史数据**
- [ ] 金额/营养/消耗为**冻结快照**，不随引用表变化

---

## 5. 风险与注意事项

1. **加既有表的 FK（P0-5）**：SQLite 不能直接 `ALTER ADD FOREIGN KEY`，需 `TableMigration` 重建表。务必先清洗孤儿数据，且在迁移测试里验证数据保留。
2. **迁移不可逆**：`stepByStep` 只前进。发版前用真实 v2 库演练升级。
3. **照片文件与 DB 一致性**：删 `LifeMoment` 时同步删磁盘照片文件（或标记待清理），避免孤儿文件；DB 只存路径不存二进制。
4. **Web 端加密缺口**：`WebDatabase` 无 SQLCipher。若近期不支持 Web 正式数据，建议明确「Web 仅开发/演示、不落敏感数据」，并在代码与本文档标注。
5. **幂等**：订阅自动入账（P1-4）、食物库导入（P2-1）、午夜结算（P5-2）都必须幂等，重复执行不重复写。
6. **时区/日期边界**：日聚合、摊销跨日一律用「本地日 dateOnly」口径，统一封装，避免各处 `DateTime` 直接比较出错。
7. **不要改动已锁定决策**（蓝图决策记录）；如需变更，先提出评审。

---

*本文档为执行基准。工程师交付后，将对照 §4 验收清单逐条 Code Review。*
