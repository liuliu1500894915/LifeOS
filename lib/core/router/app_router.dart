import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/daily/presentation/pages/daily_page.dart';
import '../../features/finance/presentation/pages/finance_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/pet_panel_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../theme/app_theme.dart';
import '../../features/finance/presentation/pages/today_expenses_page.dart';
import '../../features/finance/presentation/pages/asset_list_page.dart';
import '../../features/finance/presentation/pages/add_asset_page.dart';
import '../../features/finance/presentation/pages/subscription_page.dart';
import '../../features/finance/presentation/pages/add_subscription_page.dart';
import '../../features/finance/presentation/widgets/transaction_drawer.dart';
import '../../features/daily/presentation/pages/quadrant_todo_page.dart';
import '../../features/daily/presentation/providers/daily_providers.dart';
import '../../features/daily/presentation/pages/habit_detail_page.dart';
import '../../features/daily/presentation/pages/flag_timeline_page.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, this.title = ''});
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Text('$title', style: const TextStyle(fontSize: 18)),
        ),
      );
}

// ── Route paths ──

class AppRoutes {
  AppRoutes._();

  static const home = '/home';
  static const finance = '/finance';
  static const analytics = '/analytics';
  static const daily = '/daily';
  static const profile = '/profile';

  static const _tabRoots = [home, finance, analytics, daily, profile];

  // Home
  static const petPanel = '/home/pet-panel';
  static const roomEdit = '/home/room-edit';
  static const feed = '/home/feed';
  static const drink = '/home/drink';
  static const exercise = '/home/exercise';
  static const rest = '/home/rest';

  // Finance
  static const todayExpenses = '/finance/today-expenses';
  static const assets = '/finance/assets';
  static const subscriptions = '/finance/subscriptions';
  static const addTransaction = '/finance/add-transaction';
  static const addAsset = '/finance/add-asset';
  static const addSubscription = '/finance/add-subscription';
  static const budgetSettings = '/finance/budget-settings';

  // Analytics
  static const insights = '/analytics/insights';
  static const calendar = '/analytics/calendar';
  static const financeDeep = '/analytics/finance-deep';
  static const dailyDeep = '/analytics/daily-deep';
  static const categoryLedger = '/analytics/category-ledger';
  static const habitHeatmap = '/analytics/habit-heatmap';

  // Daily
  static const quadrantTodo = '/daily/quadrant-todo';
  static const todoEdit = '/daily/todo-edit';
  static const habitDetail = '/daily/habit-detail';
  static const flagTimeline = '/daily/flag-timeline';
  static const reviewLog = '/daily/review-log';
  static const reviewEditor = '/daily/review-editor';

  // Profile
  static const profileEdit = '/profile/edit';
  static const documents = '/profile/documents';
  static const addDocument = '/profile/add-document';
  static const memorials = '/profile/memorials';
  static const addMemorial = '/profile/add-memorial';
  static const relationships = '/profile/relationships';
  static const addInteraction = '/profile/add-interaction';

  static int indexForLocation(String location) {
    final segment = Uri.parse(location).pathSegments.isNotEmpty
        ? '/${Uri.parse(location).pathSegments.first}'
        : home;
    return _tabRoots.indexOf(segment).clamp(0, _tabRoots.length - 1);
  }
}

// ── Shell scaffold with persistent bottom nav ──

class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final idx = AppRoutes.indexForLocation(
      GoRouterState.of(context).uri.toString(),
    );

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) => context.go(AppRoutes._tabRoots[i]),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.pets),
            activeIcon: Icon(Icons.pets, color: ModuleColors.home),
            label: '主页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet, color: ModuleColors.finance),
            label: '财务',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_outlined),
            activeIcon: Icon(Icons.insights, color: ModuleColors.analytics),
            label: '分析',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.today_outlined),
            activeIcon: Icon(Icons.today, color: ModuleColors.daily),
            label: '日常',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person, color: ModuleColors.profile),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

// ── Router factory ──

/// Tab page factories keyed by route path.
final _tabPages = <String, Widget Function()>{
  AppRoutes.home: () => const HomePage(),
  AppRoutes.finance: () => const FinancePage(),
  AppRoutes.analytics: () => const AnalyticsPage(),
  AppRoutes.daily: () => const DailyPage(),
  AppRoutes.profile: () => const ProfilePage(),
};

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(child: navigationShell),
        branches: [
          _buildBranch(AppRoutes.home, [
            _buildRealRoute('pet-panel', () => const PetPanelPage()),
            _buildRoute('room-edit', '装修模式'),
          ]),
          _buildBranch(AppRoutes.finance, [
            _buildRealRoute('today-expenses', () => const TodayExpensesPage()),
            _buildRealRoute('assets', () => const AssetListPage()),
            _buildRealRoute('subscriptions', () => const SubscriptionPage()),
            _buildTransactionDrawer('add-transaction'),
            _buildRealRoute('add-asset', () => const AddAssetPage()),
            _buildRealRoute('add-subscription', () => const AddSubscriptionPage()),
            _buildRoute('budget-settings', '预算设置'),
          ]),
          _buildBranch(AppRoutes.analytics, [
            _buildRoute('insights', '洞察因果'),
            _buildRoute('calendar', '日历账单'),
            _buildRoute('finance-deep', '财务深度分析'),
            _buildRoute('daily-deep', '日常效率分析'),
            _buildRoute('category-ledger', '分类流水'),
            _buildRoute('habit-heatmap', '习惯热力图'),
          ]),
          _buildBranch(AppRoutes.daily, [
            _buildQuadrantTodoRoute(),
            _buildRealRoute('habit-detail', () => const HabitDetailPage()),
            _buildRealRoute('flag-timeline', () => const FlagTimelinePage()),
            _buildRoute('review-log', '复盘日志库'),
            _buildRoute('review-editor', '复盘编辑'),
          ]),
          _buildBranch(AppRoutes.profile, [
            _buildRoute('edit', '编辑档案'),
            _buildNestedRoute('documents', '证件资产库', [
              _buildRoute('add', '添加证件'),
            ]),
            _buildNestedRoute('memorials', '纪念日', [
              _buildRoute('add', '新增纪念日'),
            ]),
            _buildNestedRoute('relationships', '人际关系', [
              _buildRoute('add-interaction', '新增交往日志'),
            ]),
          ]),
        ],
      ),
    ],
  );
}

StatefulShellBranch _buildBranch(String path, List<GoRoute> subRoutes) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) => _tabPages[path]!(),
        routes: subRoutes,
      ),
    ],
  );
}

/// L2 pages: slide in from the right.
/// Page builders keyed by path for non-placeholder routes.

GoRoute _buildQuadrantTodoRoute() {
  return GoRoute(
    path: 'quadrant-todo',
    pageBuilder: (context, state) => CustomTransitionPage(
      key: state.pageKey,
      child: QuadrantTodoPage(initialQuadrant: state.extra as QuadrantType?),
      transitionsBuilder: _slideFromRight,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
}

GoRoute _buildRealRoute(String path, Widget Function() builder) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => CustomTransitionPage(
      key: state.pageKey,
      child: builder(),
      transitionsBuilder: _slideFromRight,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
}

GoRoute _buildTransactionDrawer(String path) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => CustomTransitionPage(
      key: state.pageKey,
      fullscreenDialog: true,
      child: const TransactionDrawer(),
      transitionsBuilder: _slideFromBottom,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
}

GoRoute _buildRoute(String path, String title) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => CustomTransitionPage(
      key: state.pageKey,
      child: PlaceholderPage(title: title),
      transitionsBuilder: _slideFromRight,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
}


GoRoute _buildNestedRoute(String path, String title, List<GoRoute> children) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => CustomTransitionPage(
      key: state.pageKey,
      child: PlaceholderPage(title: title),
      transitionsBuilder: _slideFromRight,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    routes: children,
  );
}

Widget _slideFromRight(BuildContext context, Animation<double> animation,
    Animation<double> secondaryAnimation, Widget child) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    )),
    child: FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(animation),
      child: child,
    ),
  );
}

Widget _slideFromBottom(BuildContext context, Animation<double> animation,
    Animation<double> secondaryAnimation, Widget child) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    )),
    child: child,
  );
}
