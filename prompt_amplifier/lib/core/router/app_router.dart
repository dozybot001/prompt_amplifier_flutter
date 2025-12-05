import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// 引入刚才创建的页面
import '../../features/dashboard/dashboard_shell.dart';
import '../../features/editor/editor_screen.dart';
import '../../features/templates/templates_screen.dart';
import '../../features/settings/settings_screen.dart';

// 用于获取全局 NavigatorKey (处理弹窗等)
final _rootNavigatorKey = GlobalKey<NavigatorState>();

// 创建 Riverpod Provider 供外部调用
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/editor', // 默认打开编辑器
    routes: [
      // StatefulShellRoute 保持页面状态
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return DashboardShell(navigationShell: navigationShell);
        },
        branches: [
          // 分支 1: 编辑器
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/editor',
                builder: (context, state) => const EditorScreen(),
              ),
            ],
          ),
          // 分支 2: 模板
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/templates',
                builder: (context, state) => const TemplatesScreen(),
              ),
            ],
          ),
          // 分支 3: 设置
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});