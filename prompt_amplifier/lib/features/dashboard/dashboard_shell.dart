import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const DashboardShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    // 简单的断点判断：宽度 > 600 为桌面/平板布局
    final bool isDesktop = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      body: Row(
        children: [
          // 1. 桌面端：左侧侧边栏
          if (isDesktop)
            NavigationRail(
              extended: MediaQuery.of(context).size.width > 900, // 屏幕超宽时展开文字
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.edit_outlined), selectedIcon: Icon(Icons.edit), label: Text('Editor')),
                NavigationRailDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: Text('Templates')),
                NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
              ],
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _goBranch,
              // 侧边栏样式微调
              labelType: MediaQuery.of(context).size.width > 900
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
            ),

          // 2. 垂直分割线 (仅桌面端显示)
          if (isDesktop)
            const VerticalDivider(thickness: 1, width: 1),

          // 3. 核心内容区域
          Expanded(child: navigationShell),
        ],
      ),

      // 4. 移动端：底部导航栏
      bottomNavigationBar: isDesktop
          ? null // 桌面端不显示底部栏
          : NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_outlined), selectedIcon: Icon(Icons.edit), label: 'Editor'),
          NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: 'Templates'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  // 切换分支的逻辑
  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}