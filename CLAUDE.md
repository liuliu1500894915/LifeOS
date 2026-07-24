# CLAUDE.md

> 本文件每次会话自动加载，是本仓库的**必读须知**。改动架构/规范时同步更新此文件。
> 详细设计与执行细节见 [`docs/`](docs/)，勿在此文件堆细节 —— 保持高信号、精炼。

## 项目

**Life OS（人生操作系统）** —— 本地优先、隐私为先的全维人生管理 App（Flutter，移动端为主）。
模块：宠物养成 + 每日/习惯/待办/复盘 + 财务记账 + 健康饮食/运动 + 档案/人脉 + 数据分析。

- 产品/架构原始文档（根目录）：`Life OS（人生操作系统）产品需求文档 (PRD).md`、`Life OS 技术架构与开发设计文档 v1.0.md`
- **进行中的重构 + 新功能**：见 [`docs/LifeOS-重构与新功能蓝图.md`](docs/LifeOS-重构与新功能蓝图.md)（设计）与 [`docs/LifeOS-开发执行计划.md`](docs/LifeOS-开发执行计划.md)（工程师执行版，含开发规范/任务/验收）。**动手前先读执行计划。**

## 常用命令

```bash
flutter pub get                                             # 装依赖
flutter run                                                 # 跑 App
flutter analyze                                             # 静态检查（PR 必须零新增告警）
flutter test                                                # 全部测试（PR 必须全绿）
flutter test test/finance_db_test.dart                     # 跑单个测试文件
dart run build_runner build --delete-conflicting-outputs   # 代码生成（drift/freezed/json/riverpod）
dart run build_runner watch --delete-conflicting-outputs   # 生成-监听模式

# Drift 迁移工具链（改 schema 时用）
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/
dart run drift_dev schema steps drift_schemas/ lib/core/database/schema_versions.dart
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
```

> 生成文件（`*.g.dart`、`*.freezed.dart`、`schema_versions.dart`）**只重新生成、不手改、不手动合并冲突**。冲突时重跑 build_runner。

## 技术栈

Flutter · Riverpod 2 · Drift 2.25（SQLite + SQLCipher 加密）· go_router（底部 tab StatefulShell）· event_bus（跨模块）· workmanager（后台/午夜结算）· fl_chart · rive · ML Kit。

## 架构（强制遵守）

**Feature-first + 清晰分层**，每个 feature 三层，禁止层间越界：

```
lib/
├─ core/          跨模块基础设施
│   ├─ database/  Drift：app_database.dart(单库,26+表)、tables/、dao/、迁移、连接(native加密/web)
│   ├─ crypto/    SQLCipher 加密配置
│   ├─ event_bus/ 跨模块事件（events.dart 按「源→目标」分组）
│   ├─ workers/   workmanager 后台任务（午夜结算等，跑在独立 isolate）
│   ├─ router/ theme/ widgets/ utils/
├─ features/<模块>/           (finance / daily / home / profile / analytics / health…)
│   ├─ data/{dao,repositories}/   Drift 查询集中于此
│   ├─ domain/                    纯 Dart 计算，无 Flutter/Drift 依赖，可独立单测
│   └─ presentation/{providers,pages,widgets}/
```

**铁律**：
1. **presentation 禁止直接访问 DB** —— 不出现 `db.select/into`、`Companion`、`databaseProvider`。只调 Repository / domain。
2. **读用 Drift `.watch()` 流** → `StreamProvider`/`AsyncNotifier`。写库后 UI 自动刷新，**禁止**手动 `_fetchAll` 全量重查、**禁止**靠 `ref.invalidate` 维持跨 Provider 同步。
3. **计算逻辑放 `domain/` 纯函数**（TDEE、摊销、营养换算…），带表驱动单测。
4. **字典/品类只存 DB，单一真相** —— 禁止代码里再维护硬编码列表当第二真相。
5. **历史数据冻结快照** —— 交易金额、营养值、运动消耗记录时把计算结果存表，不依赖引用表当前值。

## 数据库规范

- **迁移**：统一 Drift **versioned `stepByStep`**，禁止「`createAll` + 手写 `onUpgrade` 补表」混合模式。每次改 schema：`schemaVersion` +1、`drift_dev schema dump` 快照、补迁移测试、旧库升级不丢数据。`drift_schemas/` 已有 v1–v7 快照（v3 健康摄入/消耗五表 / v4 交易表 FK / v5 摊销四列 / v6 生活瞬间两表 / v7 复盘结构化三列；迁移均 stepByStep，P0-2 完成）。**下一个改 schema 的任务从 v8 起**（守门人按版本号串行合）。⚠️ **重新生成 `schema_versions.dart` / `test/generated_migrations/*` 后，需手动给 `schema_versions.dart` 及每个 `schema_v*.dart` 补 `tables/app_defaults.dart` 的 import** —— 生成代码引用 `AppDefaults.*` 列默认常量，但 drift schema dump 不会自动加 import，否则编译报 `Undefined name 'AppDefaults'`。
- **外键**：跨表引用必须 `.references()`；`PRAGMA foreign_keys = ON` 放在 **`beforeOpen`**（不放 `setup`）。
- **索引**：按列过滤/排序的查询列必须建索引；禁止「全表 `.get()` 后 Dart `.where` 过滤」。
- **命名**：Table 类 `PascalCase` 单数（`MealLog`）；列 getter `camelCase`（Drift 自动映射 snake_case）；主键 `xxxId`。新表要注册进 `@DriftDatabase`、导出进 `tables/tables.dart`。

## 安全

- 加密 key **禁止硬编码**，走 `flutter_secure_storage`（首启随机生成）。`PRAGMA key` 参数化。
- 不在日志打印 key / PIN / 证件号等敏感值。发版前清 `debugPrint`。

## 测试 & Lint

- `domain/` 计算逻辑必须表驱动单测（覆盖边界：闰月/单日/空值/极端值），目标 ≥90%。
- DAO/Repository 用 `NativeDatabase.memory()` 测 CRUD/事务/FK。schema 变更必须补迁移测试。
- 遵循 `flutter_lints`。`// ignore:` 必须同行写明理由，否则不合并。

## 已知问题（重构中，勿假设已修复）

- ✅ 加密 key 已移入 `flutter_secure_storage`（`key_store.dart`，P0-1 已完成 2026-07-24）；`encryption_config.dart` 不再含 key。
- 🔴 Web 端（`database_connection_web.dart`）**无加密**（SQLCipher 不支持 Web）。
- 🟠 全 App 单一硬编码系统用户 `user-001`（schema 是多用户，实现是单用户）。
- 🟠 `finance` 模块重构进度：✅ P0-3（Repository/DAO）、✅ P0-4（读取走 Repository 的 `.watch()` 流，`finance_providers.dart` 现为流式范式**范例**，可参照）；🔴 P0-5 仍待办——交易表 `categoryId`/`accountId` 仍是裸 text **无 FK**、分类名仍走 `categoryForId` 硬编码（`category_seeds.dart`）而非 DB 单一真相。

## 反面模式清单（勿重蹈）

| ❌ 现存于代码 | ✅ 正确 |
|---|---|
| presentation 里 `db.select/into` | Repository/DAO |
| 硬编码字典 + DB 表两套真相 | 只存 DB |
| 写库后 `_fetchAll` + `invalidate` | `.watch()` 流 |
| `prev`→出错还原的死代码 | 删除或写真乐观更新 |
| 全表 get 后 Dart 过滤 | WHERE + 索引 |
| 每次 build/mutation 调 `_ensureSystemUser` | 启动时一次 |
| `createAll` + 手写 onUpgrade | versioned stepByStep |

## 多人协作

**⚠️ 一个终端/agent = 一个 git worktree = 一个分支，绝不共用同一个工作目录。** 曾有三个 Claude Code 终端同时在主目录 `/Users/liu/Desktop/LifeOS` 跑不同任务，导致：① 共享文件（`app_database.g.dart`、`schema_versions.dart`、`tables.dart`）被相互覆盖（非 git 冲突，是"后写覆盖先写"）；② 多个 `build_runner` 争用同一个 `.dart_tool/build` 锁 → 卡死。开并行任务前先隔离：
```bash
git worktree add ../lifeos-<任务> -b feat/<任务> origin/main   # 各自目录、各自分支、各自 .dart_tool
# 各终端 cd 进各自 worktree 目录再干活；同一目录绝不并发跑两个 build_runner
```

**分工按「竖切」（一人包干一条功能线的 data+domain+presentation），不按「层」切** —— 减少多人改同一批文件。并行结构：P0 地基先合进 main（门禁）→ 之后财务/摄入/消耗/每日 4 条线并行 → P5 联动收口。纯函数任务（TDEE、摊销算法）可提前抢跑。

**Git 流程**：main 保护分支，1 任务 = 1 分支 = 1 PR。
```bash
git switch -c feat/<模块>-<任务> origin/main
# Conventional Commits (feat:/fix:/refactor:/test:)
git fetch && git rebase origin/main    # 提 PR 前 rebase 保持线性
flutter analyze && flutter test        # 本地全绿才推
```
PR 描述带任务 ID + 逐条勾验收清单；review + CI 绿后 **squash merge**；合完他人 `git pull --rebase`。

**Schema 改动是最大冲突源，专门定规矩**：
1. 每个改 schema 的任务分**独立版本号**（v3、v4…），只写自己的 `fromNtoN+1` 步 + 追加自己版本快照，按版本号顺序合并。
2. 设一名**迁移守门人**统一 review 所有 schema PR、控制合并顺序、跑 drift 工具链。
3. 生成文件冲突 → 重跑 build_runner，不手动合。
4. **改动要小/append-only 的共享文件**（提交前先 rebase）：`app_database.dart`、`tables/tables.dart`、`event_bus/events.dart`、`tables/app_defaults.dart`、`pubspec.yaml`。

任务看板与详细分工见 [`docs/LifeOS-开发执行计划.md`](docs/LifeOS-开发执行计划.md)。

## 交互约定

- 面向用户的文案、注释、commit 说明用中文（与现有代码一致）。
- 改动已锁定的设计决策前先确认（见蓝图「决策记录」），不自行新增数据结构。
