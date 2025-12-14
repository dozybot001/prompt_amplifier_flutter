import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_router.dart';
import 'state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 创建一个 ProviderContainer，它就像一个“状态仓库”
  final container = ProviderContainer();

  // 2. 在启动 UI 之前，强制读取并等待设置加载完成
  // 这样当 UI 显示的第一帧，语言和 API Key 就已经是正确的了
  await container.read(settingsProvider.notifier).loadSettings();

  // 3. 启动 App，使用 UncontrolledProviderScope 注入我们要预热好的 container
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 字体回退策略
    const List<String> fontFallbacks = [
      'Microsoft YaHei',
      'PingFang SC',
      'Heiti SC',
      'Noto Sans SC',
    ];

    // Gemini 风格配色 (浅色)
    final ColorScheme geminiLight = ColorScheme.fromSeed(
      seedColor: Colors.blueGrey, // 基准色，但我们会大量覆盖
      brightness: Brightness.light,
      primary: Colors.black, // 主按钮黑色
      onPrimary: Colors.white,
      surface: Colors.white, // 纯白背景
      surfaceContainerHighest: const Color(0xFFF0F4F9), // 输入框/卡片背景 (Gemini 同款浅灰)
      surfaceContainerLow: const Color(0xFFF8F9FA),
      outline: const Color(0xFFE0E3E7), // 边框颜色
    );

    // Gemini 风格配色 (深色)
    final ColorScheme geminiDark = ColorScheme.fromSeed(
      seedColor: Colors.blueGrey,
      brightness: Brightness.dark,
      primary: const Color(0xFFE3E3E3), // 接近白色的灰
      onPrimary: Colors.black,
      surface: const Color(0xFF131314), // Gemini 深色背景
      surfaceContainerHighest: const Color(0xFF1E1F20),
      outline: const Color(0xFF444746),
    );

    return MaterialApp.router(
      title: 'Prompt Amplifier',
      debugShowCheckedModeBanner: false,
      routerConfig: router,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: geminiLight,
        fontFamily: 'Microsoft YaHei',
        fontFamilyFallback: fontFallbacks,
        scaffoldBackgroundColor: geminiLight.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: geminiLight.surface,
          surfaceTintColor: Colors.transparent, // 移除滚动时的变色
        ),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: geminiDark,
        fontFamily: 'Microsoft YaHei',
        fontFamilyFallback: fontFallbacks,
        scaffoldBackgroundColor: geminiDark.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: geminiDark.surface,
          surfaceTintColor: Colors.transparent,
        ),
      ),

      themeMode: ThemeMode.system,
    );
  }
}