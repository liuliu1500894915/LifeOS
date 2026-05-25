# Life OS 技术架构与开发设计文档 v1.0

> 创建日期：2026-05-24 | 状态：设计评审完成，待开发

---

## 1. 技术选型

| 维度 | 选型 | 理由 |
|---|---|---|
| 跨平台框架 | **Flutter** | 自渲染引擎，Canvas/动画能力原生支持，宠物沙盒拖拽缩放需求匹配 |
| 状态管理 | **Riverpod** | 编译安全、跨模块 provider 互监听，匹配模块间总线通信需求 |
| 架构模式 | **简化 Clean Architecture**（3层） | core/data/domain/features 分层，关注点分离 |
| 路由 | **GoRouter** | 支持深度嵌套、路由守卫（Face ID 拦截） |
| 本地数据库 | **drift + SQLCipher** | 类型安全 SQL、响应式查询、AES-256 加密 |
| 事件总线 | **dart_event_bus** | 跨模块一次性触发（纪念日→待办、证件到期→待办） |
| 后台任务 | **workmanager** | 凌晨 Worker 定时结算（Android/iOS 双端） |
| 宠物动画 | **Rive** | 2.5D 骨骼动画，Flutter 一流支持 |
| 端侧 AI | **google_mlkit** | 食物识别（Image Labeling）+ 证件 OCR（Text Recognition） |
| 生物识别 | **local_auth** | Face ID / 指纹二次验证 |
| 图表 | **fl_chart** | 柱状图/折线图/热力图 |
| 日历组件 | **table_calendar** | 账单日历热力图 |

---

## 2. 项目骨架与目录结构

```
life_os/
├── lib/
│   ├── core/                        # 基础设施层
│   │   ├── database/                # drift 数据库实例 + DAO
│   │   │   ├── app_database.dart
│   │   │   ├── app_database.g.dart
│   │   │   └── dao/
│   │   ├── crypto/                  # AES-256 加密工具
│   │   ├── router/                  # GoRouter 路由配置
│   │   │   └── app_router.dart
│   │   ├── theme/                   # 全局主题/色系
│   │   │   └── app_theme.dart
│   │   ├── event_bus/               # dart_event_bus 事件定义
│   │   │   ├── events.dart
│   │   │   └── bus.dart
│   │   ├── workers/                 # workmanager 后台任务
│   │   │   └── midnight_worker.dart
│   │   ├── utils/                   # 工具函数
│   │   └── widgets/                 # 通用组件
│   │       ├── bottom_sheet.dart
│   │       ├── status_capsule.dart
│   │       ├── number_keyboard.dart
│   │       └── scroll_picker.dart
│   │
│   ├── data/                        # 数据层
│   │   ├── models/                  # drift 表对应的数据模型
│   │   ├── repositories/            # 数据仓库实现
│   │   └── services/                # 跨模块服务
│   │       ├── cross_module_bus.dart
│   │       └── midnight_settlement.dart
│   │
│   ├── domain/                      # 业务逻辑层
│   │   ├── calculators/             # 算法引擎
│   │   │   ├── bmr_calculator.dart
│   │   │   ├── met_calculator.dart
│   │   │   ├── adc_calculator.dart
│   │   │   ├── pearson_correlation.dart
│   │   │   └── ma7_calculator.dart
│   │   ├── state_machines/          # 状态机
│   │   │   └── pet_status_fsm.dart
│   │   └── use_cases/               # 核心业务用例
│   │
│   └── features/                    # 功能模块层（5 大 Tab）
│       ├── home/                    # [主页🐾]
│       │   ├── presentation/
│       │   │   ├── pages/
│       │   │   ├── widgets/
│       │   │   └── providers/
│       │   ├── data/repositories/
│       │   └── domain/models/
│       ├── finance/                 # [财务💰]
│       ├── analytics/               # [分析📊]
│       ├── daily/                   # [日常📆]
│       └── profile/                 # [我的👤]
```

---

## 3. 数据库设计（26 张表）

### 模块一：宠物与主页系统（4 张表）

#### pet_status_core（已有-PRD定义）
```sql
CREATE TABLE pet_status_core (
    pet_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    pet_name VARCHAR(50) DEFAULT '小生活',
    species_type TEXT CHECK(species_type IN ('CAT', 'DOG', 'RABBIT', 'DRAGON')),
    growth_stage TEXT CHECK(growth_stage IN ('EGG', 'BABY', 'TEEN', 'ADULT', 'LEGEND')),
    hydration_points INTEGER DEFAULT 100,
    body_shape_points INTEGER DEFAULT 0,
    energy_points INTEGER DEFAULT 100,
    mood_points INTEGER DEFAULT 100,
    overall_status_level TEXT DEFAULT 'NORMAL',
    accumulated_days INTEGER DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### pet_action_quick_log（已有-PRD定义）
```sql
CREATE TABLE pet_action_quick_log (
    log_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    action_type TEXT CHECK(action_type IN ('FEED', 'DRINK', 'SPORT', 'REST')),
    value_numeric REAL NOT NULL,
    sub_category VARCHAR(100),
    subjective_score INTEGER DEFAULT 0,
    associated_cost DECIMAL(10,2) DEFAULT 0.00,
    remark TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### room_furniture_placement（新增）
```sql
CREATE TABLE room_furniture_placement (
    placement_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    asset_id VARCHAR(36),
    pos_x REAL NOT NULL DEFAULT 0,
    pos_y REAL NOT NULL DEFAULT 0,
    scale REAL NOT NULL DEFAULT 1.0,
    z_index INTEGER DEFAULT 0,
    is_visible INTEGER DEFAULT 1,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### user_profile（新增）
```sql
CREATE TABLE user_profile (
    user_id VARCHAR(36) PRIMARY KEY,
    display_name VARCHAR(50),
    motto VARCHAR(200),
    avatar_path VARCHAR(255),
    gender TEXT CHECK(gender IN ('MALE', 'FEMALE', 'OTHER')),
    height_cm REAL,
    weight_kg REAL,
    birth_date DATE,
    blood_type VARCHAR(5),
    emergency_contact VARCHAR(50),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### weight_history（新增-体重变化曲线）
```sql
CREATE TABLE weight_history (
    record_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    weight_kg REAL NOT NULL,
    recorded_date DATE NOT NULL,
    photo_path VARCHAR(255),
    note VARCHAR(200),
    UNIQUE(user_id, recorded_date)
);
```

### 模块二：财务管理系统（6 张表）

#### financial_transaction（已有-PRD定义）
```sql
CREATE TABLE financial_transaction (
    transaction_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    flow_type TEXT CHECK(flow_type IN ('INCOME', 'EXPENSE', 'TRANSFER')),
    amount DECIMAL(12,2) NOT NULL,
    category_id VARCHAR(50) NOT NULL,
    account_id VARCHAR(50) NOT NULL,
    remark VARCHAR(150),
    logged_at TIMESTAMP NOT NULL
);
```

#### asset_inventory（已有-PRD定义）
```sql
CREATE TABLE asset_inventory (
    asset_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    asset_name VARCHAR(100) NOT NULL,
    purchase_price DECIMAL(12,2) NOT NULL,
    purchase_date DATE NOT NULL,
    icon_id VARCHAR(50) NOT NULL,
    project_to_room INTEGER DEFAULT 1
);
```

#### payment_accounts（新增）
```sql
CREATE TABLE payment_accounts (
    account_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    account_name VARCHAR(50) NOT NULL,
    account_type TEXT CHECK(account_type IN ('CASH', 'DEBIT', 'CREDIT', 'INVESTMENT')),
    is_liability INTEGER DEFAULT 0,
    balance DECIMAL(12,2) DEFAULT 0,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### subscription_services（新增）
```sql
CREATE TABLE subscription_services (
    subscription_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    service_name VARCHAR(100) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    billing_cycle TEXT CHECK(billing_cycle IN ('MONTHLY', 'QUARTERLY', 'YEARLY')),
    next_billing_date DATE NOT NULL,
    account_id VARCHAR(36),
    alert_enabled INTEGER DEFAULT 1,
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### budget_settings（新增）
```sql
CREATE TABLE budget_settings (
    budget_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    category_id VARCHAR(50) NOT NULL,
    month_key VARCHAR(7) NOT NULL,
    budget_amount DECIMAL(10,2) NOT NULL,
    reserved_amount DECIMAL(10,2) DEFAULT 0,
    UNIQUE(user_id, category_id, month_key)
);
```

#### asset_value_snapshots（新增）
```sql
CREATE TABLE asset_value_snapshots (
    snapshot_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    snapshot_date DATE NOT NULL,
    total_asset_value DECIMAL(12,2) DEFAULT 0,
    total_liability_value DECIMAL(12,2) DEFAULT 0,
    net_worth DECIMAL(12,2) DEFAULT 0,
    UNIQUE(user_id, snapshot_date)
);
```

### 模块三：日常与时间系统（6 张表）

#### todo_execution_list（已有-PRD定义）
```sql
CREATE TABLE todo_execution_list (
    todo_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    title VARCHAR(150) NOT NULL,
    priority_quadrant TEXT CHECK(priority_quadrant IN ('A', 'B', 'C', 'D')),
    target_date DATE NOT NULL,
    reminder_clock TIMESTAMP,
    is_completed INTEGER DEFAULT 0,
    delay_count INTEGER DEFAULT 0,
    associated_flag_id VARCHAR(36),
    completed_at TIMESTAMP
);
```

#### habit_definitions（新增）
```sql
CREATE TABLE habit_definitions (
    habit_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    habit_name VARCHAR(100) NOT NULL,
    habit_icon VARCHAR(10),
    target_type TEXT CHECK(target_type IN ('BOOLEAN', 'NUMERIC')),
    target_value REAL,
    target_unit VARCHAR(20),
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### habit_check_log（新增）
```sql
CREATE TABLE habit_check_log (
    log_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    habit_id VARCHAR(36) NOT NULL,
    check_date DATE NOT NULL,
    achieved_value REAL,
    is_frozen INTEGER DEFAULT 0,
    UNIQUE(habit_id, check_date)
);
```

#### flag_goals（新增）
```sql
CREATE TABLE flag_goals (
    flag_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    target_value REAL,
    current_value REAL DEFAULT 0,
    unit VARCHAR(20),
    deadline DATE,
    is_completed INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### flag_milestones（新增）
```sql
CREATE TABLE flag_milestones (
    milestone_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    flag_id VARCHAR(36) NOT NULL,
    title VARCHAR(150) NOT NULL,
    target_value REAL,
    is_reached INTEGER DEFAULT 0,
    reached_at TIMESTAMP
);
```

#### daily_review_log（已有-PRD定义）
```sql
CREATE TABLE daily_review_log (
    review_date DATE NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    mood_tag TEXT NOT NULL,
    insights_content TEXT,
    summary_snapshot_json TEXT NOT NULL,
    PRIMARY KEY (review_date, user_id)
);
```

### 模块四：个人档案系统（4 张表）

#### secure_documents_vault（已有-PRD定义）
```sql
CREATE TABLE secure_documents_vault (
    doc_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    doc_type TEXT CHECK(doc_type IN ('PASSPORT', 'ID_CARD', 'DRIVER_LICENSE', 'OTHER')),
    encrypted_number_blob BLOB NOT NULL,
    expiry_date DATE NOT NULL,
    alert_offset_days INTEGER DEFAULT 30,
    requires_face_id_secondary INTEGER DEFAULT 1,
    local_only_island_flag INTEGER DEFAULT 1,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### memorial_days（新增）
```sql
CREATE TABLE memorial_days (
    memorial_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    name VARCHAR(100) NOT NULL,
    calendar_type TEXT CHECK(calendar_type IN ('SOLAR', 'LUNAR')),
    month_value INTEGER NOT NULL,
    day_value INTEGER NOT NULL,
    advance_days_todo INTEGER DEFAULT 7,
    gift_budget_amount DECIMAL(10,2),
    gift_budget_lock_days INTEGER DEFAULT 15,
    is_active INTEGER DEFAULT 1
);
```

#### relationship_network（新增）
```sql
CREATE TABLE relationship_network (
    contact_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    name VARCHAR(50) NOT NULL,
    relation_type VARCHAR(30),
    last_interaction_date DATE,
    crisis_threshold_days INTEGER DEFAULT 14,
    warmth_score INTEGER DEFAULT 100,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### relationship_interaction_log（新增）
```sql
CREATE TABLE relationship_interaction_log (
    interaction_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    contact_id VARCHAR(36) NOT NULL,
    interaction_date DATE NOT NULL,
    content TEXT,
    warmth_reset_value INTEGER
);
```

### 模块五：分析系统（3 张表）

#### analytical_insights（已有-PRD定义）
```sql
CREATE TABLE analytical_insights (
    insight_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    insight_type TEXT NOT NULL,
    correlation_coefficient REAL NOT NULL,
    insight_title TEXT NOT NULL,
    summary_markdown TEXT NOT NULL,
    json_chart_data TEXT NOT NULL,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### daily_aggregation_cache（新增）
```sql
CREATE TABLE daily_aggregation_cache (
    cache_date DATE NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    total_expense DECIMAL(10,2) DEFAULT 0,
    total_income DECIMAL(10,2) DEFAULT 0,
    transaction_count INTEGER DEFAULT 0,
    todo_completed_count INTEGER DEFAULT 0,
    todo_delayed_count INTEGER DEFAULT 0,
    total_calorie_intake REAL DEFAULT 0,
    total_calorie_consumed REAL DEFAULT 0,
    sleep_hours REAL,
    mood_label VARCHAR(10),
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (cache_date, user_id)
);
```

#### background_worker_log（新增）
```sql
CREATE TABLE background_worker_log (
    worker_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    worker_type TEXT CHECK(worker_type IN (
        'MIDNIGHT_ROLLOVER', 'ADC_UPDATE', 'CORRELATION_ENGINE',
        'SUBSCRIPTION_CHECK', 'NET_WORTH_SNAPSHOT', 'MEMORIAL_BUS', 'RELATIONSHIP_DECAY'
    )),
    executed_at TIMESTAMP NOT NULL,
    target_date DATE NOT NULL,
    status TEXT CHECK(status IN ('SUCCESS', 'FAILED')),
    UNIQUE(worker_type, target_date)
);
```

### 系统表（1 张）

#### user_accounts（新增-多用户切换）
```sql
CREATE TABLE user_accounts (
    user_id VARCHAR(36) PRIMARY KEY,
    display_name VARCHAR(50) NOT NULL,
    avatar_path VARCHAR(255),
    pin_code_hash VARCHAR(128),
    is_active INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 表数量统计

| 模块 | 已有(PRD) | 新增 | 小计 |
|---|---|---|---|
| 宠物与主页 | 2 | 3 | 5 |
| 财务管理 | 2 | 4 | 6 |
| 日常与时间 | 2 | 4 | 6 |
| 个人档案 | 1 | 3 | 4 |
| 分析系统 | 1 | 2 | 3 |
| 系统 | 0 | 1 | 1 |
| **总计** | **8** | **17** | **25** |

### ER 关系简图

```
user_accounts ——< 所有业务表 >—— user_accounts
    │
    ├── user_profile (1:1)
    ├── weight_history (1:N)
    ├── pet_status_core (1:1)
    ├── pet_action_quick_log (1:N)
    ├── room_furniture_placement (1:N) —— asset_inventory (N:1)
    ├── financial_transaction (1:N)
    ├── payment_accounts (1:N)
    ├── asset_inventory (1:N)
    ├── subscription_services (1:N) —— payment_accounts (N:1)
    ├── budget_settings (1:N)
    ├── asset_value_snapshots (1:N)
    ├── todo_execution_list (1:N) —— flag_goals (N:1)
    ├── habit_definitions (1:N)
    ├── habit_check_log (1:N) —— habit_definitions (N:1)
    ├── flag_goals (1:N)
    ├── flag_milestones (1:N) —— flag_goals (N:1)
    ├── daily_review_log (1:N)
    ├── secure_documents_vault (1:N)
    ├── memorial_days (1:N)
    ├── relationship_network (1:N)
    ├── relationship_interaction_log (1:N) —— relationship_network (N:1)
    ├── analytical_insights (1:N)
    ├── daily_aggregation_cache (1:N)
    └── background_worker_log (1:N)
```

---

## 4. 数据流与跨模块通信

### 通信方案

采用 **EventBus（dart_event_bus）+ Riverpod 响应式** 双模式：

| 模式 | 适用场景 | 技术 |
|---|---|---|
| 事件总线 | 一次性触发（纪念日→待办、证件到期→提醒、预算爆舱→宠物） | dart_event_bus |
| 响应式 | 数据实时观察（宠物状态聚合、净资产计算、当日摘要） | Riverpod Provider |

### 6 条核心跨模块链路

| 链路 | 触发方 | 接收方 | 通信内容 |
|---|---|---|---|
| ① 纪念日→日常+财务 | `[我的👤]` 纪念日到期前 | `[日常📆]` A象限 + `[财务💰]` 预算 | 自动生成采购待办 + 锁死礼物预留金 |
| ② 证件过期→日常 | `[我的👤]` 证件剩余45天 | `[日常📆]` A象限 | 自动生成续期待办 |
| ③ 饮水分流→财务 | `[主页🐾]` 含糖饮料记录 | `[财务💰]` 流水表 | 饮料开销静默写入支出 |
| ④ 预算爆舱→宠物 | `[财务💰]` 分类超支100% | `[主页🐾]` 宠物状态 | 触发宠物伤心动效 + 碎裂存钱罐 |
| ⑤ 任务延期→宠物 | `[日常📆]` A象限未完成 | `[主页🐾]` 宠物心情 | 凌晨扣减15点心情 |
| ⑥ 分析→宠物 | `[分析📊]` 因果引擎结果 | `[主页🐾]` 宠物状态 | 生成生活洞察卡片 |

### 事件类型定义

```dart
// 纪念日→待办
class MemorialTodoEvent {
  final String memorialId;
  final String title;
  final DateTime targetDate;
}

// 纪念日→预算锁定
class MemorialBudgetLockEvent {
  final String memorialId;
  final double lockAmount;
  final String monthKey;
}

// 证件到期→待办
class DocumentExpiryEvent {
  final String docId;
  final String docType;
  final DateTime expiryDate;
}

// 预算爆舱→宠物
class BudgetExceededEvent {
  final String categoryId;
  final double budgetAmount;
  final double actualAmount;
}

// 凌晨统一结算
class MidnightSettlementEvent {
  final DateTime targetDate;
}

// 订阅自动扣费
class SubscriptionBillingEvent {
  final String subscriptionId;
  final double amount;
  final String accountId;
}
```

### 凌晨 Worker 执行时序

```
00:00:00  workmanager 触发 MidnightSettlementEvent
    │
00:00:01  Step 1: Todo Rollover
          ├─ 所有 is_completed=0 的任务 target_date = TOMORROW
          ├─ delay_count += 1
          └─ A象限且 delay_count≥3 → 扣减宠物心情 15 点
    │
00:00:03  Step 2: Pet Status Settlement
          ├─ 计算 MA7（7日移动平均能量净结余）
          ├─ 更新 body_shape_points（+10 / 0 / -10）
          ├─ 综合评定 overall_status_level（5级状态）
          └─ 若全属性<20 且连续3天 → 危急状态
    │
00:00:05  Step 3: ADC Update
          └─ 遍历所有固定资产，重新计算每日均摊成本
    │
00:00:07  Step 4: Net Worth Snapshot
          └─ 拍摄当日净资产快照，写入 asset_value_snapshots
    │
00:00:09  Step 5: Relationship Decay
          └─ 遍历联系人，last_interaction > 14天 → 热度衰减
    │
00:00:11  Step 6: Subscription Check
          └─ 检查今日到期订阅，自动写入支出流水
    │
00:00:13  Step 7: Correlation Engine
          ├─ 提取21天 sleep_log 与次日支出数组
          ├─ 计算皮尔逊相关系数 r
          └─ |r| ≥ 0.65 → 生成洞察卡片
    │
00:00:15  Step 8: Daily Aggregation Cache
          ├─ 汇总当日全模块数据
          ├─ 写入 daily_aggregation_cache
          └─ 写入 background_worker_log 标记完成
```

### 防重复执行机制

`background_worker_log` 表 + `UNIQUE(worker_type, target_date)` 约束保证每个任务同一天不重复执行。

---

## 5. 路由设计

### GoRouter 三级页面栈

| 页面层级 | 导航栏 | 返回键/右滑 | 交互规范 |
|---|---|---|---|
| 一级（Tab首页） | 常驻高亮 | 挂起应用至后台 | 横向滑动切换，无白屏 |
| 二级（工作台） | 常驻高亮 | 出栈销毁，右滑返回 | 保持滚动位置记忆 |
| 三级（原子输入/沙盒） | 完全隐藏 | 拦截返回，表单脏数据弹窗确认 | 全屏右滑或BottomSheet |

### 路由守卫

- **Face ID 守卫**：进入 `[我的👤] → 证件资产库` 二级页面前，GoRouter redirect 强制拉起 local_auth 验证
- **用户切换守卫**：未选择活跃用户时重定向到用户选择页

---

## 6. 核心算法引擎

### BMR（基础代谢率）

- **男性**：`BMR = 66.47 + 13.75 × Weight_kg + 5.00 × Height_cm - 6.75 × Age`
- **女性**：`BMR = 655.1 + 9.56 × Weight_kg + 1.85 × Height_cm - 4.68 × Age`

### 当日能量净结余

```
E_Δ = E_food(投喂热量) + E_drink(饮料热量) - E_exercise(运动消耗) - BMR
```

其中饮料热量：`E_drink = Volume_ml × 0.45 kcal/ml`（仅含糖饮料）

### 7日滑动窗口（MA7）

```
MA7 = Σ(E_Δ(t-0) + E_Δ(t-1) + ... + E_Δ(t-6)) / 7
```

判定逻辑：
- `MA7 > +200 kcal` → 宠物体形值 +10（圆润）
- `-200 ≤ MA7 ≤ +200` → 体形值回归 0（标准）
- `MA7 < -300 kcal` → 体形值 -10（消瘦）

### ADC（每日均摊持有成本）

```
ADC = 购入价格 / ((当前日期 - 购入日期) + 1)
```

每日凌晨更新，伴随绿色下降箭头，给用户"持有越久越划算"的正向激励。

### MET 运动消耗

```
消耗(kcal) = MET × 体重(kg) × (运动时长(min) / 60)
```

### 皮尔逊相关系数

```
r = Σ(Xi - X̄)(Yi - Ȳ) / √(Σ(Xi - X̄)² × Σ(Yi - Ȳ)²)
```

当 |r| ≥ 0.65 时生成跨模块洞察卡片。

---

## 7. 开发排期（19 周）

### Phase 0：基础设施搭建（第 1-2 周）

**Week 1：项目脚手架**
- Flutter 项目初始化、Git 仓库、CI/CD
- 目录结构创建（core/data/domain/features）
- 安装所有依赖包
- SQLCipher + drift 数据库实例配置

**Week 2：核心基建**
- 全局主题系统（5 模块色系 + 字体规范）
- GoRouter 路由骨架（5 Tab + 三级页面栈）
- EventBus 事件定义 + 订阅机制
- workmanager 后台任务注册框架
- 通用组件库

### Phase 1：UI 骨架与宠物基础（第 3-5 周）

**Week 3：五大 Tab 布局**
- 底部导航栏 + Tab 切换动画
- 5 个 Tab 一级页面框架搭建

**Week 4-5：设计与动效**
- Rive 宠物 2.5D 模型导入 + 骨骼绑定
- 闲置/状态切换动效
- 路由切换动效
- 空状态/加载态/错误态组件

### Phase 2：Sprint 1 — 核心数据闭环（第 6-9 周）

**Week 6：财务管理**
- 极速记账抽屉（数字键盘 + 九宫格 + 双击保存）
- 今日花费明细页
- 固定资产库 + ADC 算法
- 订阅管理 + T-3 预警
- 净资产看板

**Week 7：日常行动**
- 四象限待办工作台 + 长按拖拽
- 任务高级加工面板
- 闪电收件箱
- 习惯打卡 + 连击
- Flag 目标 + 里程碑

**Week 8：主页快捷操作**
- 🍖 投喂抽屉（拍照 + 文本搜索）
- 💧 喝水抽屉（纯水/饮料分流）
- 🏃 运动抽屉（MET 计算）
- 🛌 休息抽屉（睡眠登记）
- 今日动态快照组件

**Week 9：数据联通**
- 主页动作→pet_status_core 更新
- 含糖饮料→financial_transaction 联动
- 全模块 CRUD 集成测试

### Phase 3：Sprint 2 — 状态机与沙盒（第 10-13 周）

**Week 10：宠物状态机**
- 四维体征计算引擎
- 5 级状态判断逻辑
- 状态胶囊仪表盘 + 7 日走势
- 体形形变算法

**Week 11：凌晨 Worker**
- Todo Rollover
- Pet Status 结算
- ADC 更新 + 净资产快照
- Subscription 自动扣费
- 关系温度衰减
- workmanager 注册 + 防重执行

**Week 12-13：房间沙盒**
- Canvas 沙盒场景
- 家具模型渲染
- 拖拽 + 缩放 + 图层
- 装修模式 + 坐标持久化
- 宠物骨骼动画集成
- 幸福/病态特效

### Phase 4：Sprint 3 — 智能中枢与隐私金库（第 14-16 周）

**Week 14：分析中枢**
- 财务收支深度分析页 + 柱状图
- 预算爆舱检测 + 情感化阻断
- 日常效率分析页
- 365 天热力图

**Week 15：跨模块智能**
- 皮尔逊相关系数引擎
- Insight 卡片生成器
- 因果明细页 + 双轴走势图
- 日历账单回溯矩阵
- 周/月综合报告

**Week 16：隐私金库**
- Face ID 路由拦截器
- 安全证件库 + AES-256
- OCR 扫描面板
- 纪念日倒计时板
- 跨模块总线（纪念日联动）
- 人际关系网 + 温度计

### Phase 5：集成联调与压测（第 17-18 周）

**Week 17：全模块集成**
- 端到端流程测试
- 跨模块数据一致性验证
- 离线模式测试
- 低端设备性能测试（≥45fps）

**Week 18：打磨**
- 性能优化
- 异常场景覆盖
- Widget 桌面小组件（今日快照）
- 多用户切换完整测试
- 全量测试报告

### Phase 6：正式发版（第 19 周）

- App Store Connect 提审
- Google Play Console 上架
- 免责与合规声明
- 应用商店素材
- v1.0 正式发布

---

## 8. 设计决策记录

| 决策 | 结论 | 日期 |
|---|---|---|
| 跨平台框架 | Flutter | 2026-05-24 |
| 状态管理 | Riverpod | 2026-05-24 |
| 架构 | 简化 Clean Architecture（3层） | 2026-05-24 |
| 路由 | GoRouter | 2026-05-24 |
| 数据库 | drift + SQLCipher | 2026-05-24 |
| 事件总线 | dart_event_bus | 2026-05-24 |
| 后台任务 | workmanager | 2026-05-24 |
| Emoji 存储 | 直接存 TEXT | 2026-05-24 |
| 体重记录 | 独立 weight_history 表 | 2026-05-24 |
| 多用户 | user_accounts 表 + PIN 码切换 | 2026-05-24 |

---

> **文档变更记录**
> - `v1.0 (2026-05-24)`：初始版本，技术架构、数据库设计、数据流设计、开发排期全部定稿。
