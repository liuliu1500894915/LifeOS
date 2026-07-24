import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/database/system_bootstrap.dart';
import 'features/daily/presentation/providers/daily_providers.dart';
import 'features/health/data/health_bootstrap.dart';

class LifeOSApp extends ConsumerWidget {
  const LifeOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(memorialTodoBridgeProvider);
    // 启动时一次性确保系统用户存在(取代散落在各 Provider 的 _ensureSystemUser)。
    ref.watch(systemBootstrapProvider);
    // 首启幂等导入打包食物库 + 预置品类（P2-1）。
    ref.watch(foodLibraryBootstrapProvider);

    return MaterialApp.router(
      title: 'Life OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: createAppRouter(),
    );
  }
}
