import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/analytics/presentation/pages/calendar_matrix_page.dart';
import '../../features/analytics/presentation/pages/daily_efficiency_page.dart';
import '../../features/analytics/presentation/pages/finance_deep_page.dart';
import '../../features/analytics/presentation/pages/habit_heatmap_page.dart';
import '../../features/analytics/presentation/pages/insight_detail_page.dart';
import '../../features/analytics/presentation/pages/report_page.dart';
import '../../features/daily/presentation/pages/daily_page.dart';
import '../../features/finance/presentation/pages/finance_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/pet_panel_page.dart';
import '../../features/home/presentation/pages/room_edit_page.dart';
import '../../features/profile/presentation/pages/add_document_page.dart';
import '../../features/profile/presentation/pages/add_interaction_page.dart';
import '../../features/profile/presentation/pages/add_memorial_page.dart';
import '../../features/profile/presentation/pages/documents_page.dart';
import '../../features/profile/presentation/pages/memorials_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/relationships_page.dart';
import '../../features/profile/presentation/widgets/biometric_gate.dart';
import '../theme/app_theme.dart';
import '../../features/finance/presentation/pages/accounts_page.dart';
import '../../features/finance/presentation/pages/monthly_spending_page.dart';
import '../../features/finance/presentation/pages/today_expenses_page.dart';
import '../../features/finance/presentation/pages/asset_list_page.dart';
import '../../features/finance/presentation/pages/add_asset_page.dart';
import '../../features/finance/presentation/pages/subscription_page.dart';
import '../../features/finance/presentation/pages/add_subscription_page.dart';
import '../../features/finance/presentation/providers/finance_providers.dart';
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
  static const monthlySpending = '/finance/monthly-spending';
  static const accounts = '/finance/accounts';
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
  static const report = '/analytics/report';

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
            _buildRealRoute('room-edit', () => const RoomEditPage()),
          ]),
          _buildBranch(AppRoutes.finance, [
            _buildRealRoute('today-expenses', () => const TodayExpensesPage()),
            _buildRealRoute('monthly-spending', () => const MonthlySpendingPage()),
            _buildRealRoute('accounts', () => const AccountsPage()),
            _buildRealRoute('assets', () => const AssetListPage()),
            _buildRealRoute('subscriptions', () => const SubscriptionPage()),
            _buildTransactionDrawer('add-transaction'),
            GoRoute(
              path: 'add-asset',
              pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                child: AddAssetPage(editAsset: state.extra as AssetItem?),
                transitionsBuilder: _slideFromRight,
                transitionDuration: const Duration(milliseconds: 300),
              ),
            ),
            GoRoute(
              path: 'add-subscription',
              pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                child: AddSubscriptionPage(editSub: state.extra as SubscriptionItem?),
                transitionsBuilder: _slideFromRight,
                transitionDuration: const Duration(milliseconds: 300),
              ),
            ),
            _buildRoute('budget-settings', '预算设置'),
          ]),
          _buildBranch(AppRoutes.analytics, [
            _buildRealRoute('insights', () => const InsightDetailPage()),
            _buildRealRoute('calendar', () => const CalendarMatrixPage()),
            _buildRealRoute('finance-deep', () => const FinanceDeepPage()),
            _buildRealRoute('daily-deep', () => const DailyEfficiencyPage()),
            _buildRoute('category-ledger', '分类流水'),
            _buildRealRoute('habit-heatmap', () => const HabitHeatmapPage()),
            _buildRealRoute('report', () => const ReportPage()),
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
            GoRoute(
              path: 'documents',
              pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                child: const BiometricGate(child: DocumentsPage()),
                transitionsBuilder: _slideFromRight,
                transitionDuration: const Duration(milliseconds: 300),
              ),
              routes: [
                _buildRealRoute('add', () => const AddDocumentPage()),
              ],
            ),
            GoRoute(
              path: 'memorials',
              pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                child: const MemorialsPage(),
                transitionsBuilder: _slideFromRight,
                transitionDuration: const Duration(milliseconds: 300),
              ),
              routes: [
                _buildRealRoute('add', () => const AddMemorialPage()),
              ],
            ),
            GoRoute(
              path: 'relationships',
              pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                child: const RelationshipsPage(),
                transitionsBuilder: _slideFromRight,
                transitionDuration: const Duration(milliseconds: 300),
              ),
              routes: [
                _buildRealRoute('add-interaction', () => const AddInteractionPage()),
              ],
            ),
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
      child: QuadrantTodoPage(
        initialQuadrant: state.extra is QuadrantType ? state.extra as QuadrantType : null,
      ),
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
