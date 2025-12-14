import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'state.dart';
import 'app_strings.dart';
import 'settings_dialog.dart';
import 'widgets/input_area.dart';
import 'widgets/result_area.dart';
import 'widgets/wizard_card.dart';
import 'widgets/history_drawer.dart';
import 'dart:async' as java_async;


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  final GlobalKey _wizardListKey = GlobalKey();
  final GlobalKey _resultAreaKey = GlobalKey();
  final GlobalKey _bottomLoaderKey = GlobalKey();

  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final isScrolled = _scrollController.offset > 50;
      if (isScrolled != _isScrolled) {
        setState(() => _isScrolled = isScrolled);
      }
    }
  }

  void _scrollToKey(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutQuart,
          alignment: 0.0,
        );
      } else {
        if (_scrollController.hasClients && key == _bottomLoaderKey) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutQuart,
          );
        }
      }
    });
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeOutQuart);
    }
  }

  // 优化后的 Toast：宽大、长驻、可关闭
  void _showGeminiToast(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 10, 
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF323232), // 深灰色背景
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 10), // 显示10秒
        action: SnackBarAction(
          label: '关闭',
          textColor: Colors.blueAccent,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _handleSend(EditorNotifier notifier) async {
    if (_inputController.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    try {
      final future = notifier.analyzeInstruction(_inputController.text);
      Future.delayed(const Duration(milliseconds: 100), () => _scrollToKey(_wizardListKey));
      await future;
    } catch (e) {
      _showGeminiToast(e.toString());
    }
  }

  Future<void> _handleSynthesize(EditorNotifier notifier) async {
    try {
      final future = notifier.synthesizeFinalResult(_inputController.text);
      Future.delayed(const Duration(milliseconds: 100), () => _scrollToKey(_resultAreaKey));
      await future;
    } catch (e) {
      _showGeminiToast(e.toString());
    }
  }

  void _handleReset(EditorNotifier notifier) {
    notifier.reset();
    _inputController.clear();
    _scrollToTop();
  }

  void _showSettings() {
    final bool isMobile = MediaQuery.of(context).size.width < 640;
    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => const SettingsBottomSheet(),
      );
    } else {
      showDialog(
        context: context,
        barrierColor: Colors.transparent,
        builder: (context) => const Stack(
          children: [
            Positioned(top: 60, right: 20, child: SettingsDialog()),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorProvider);
    final notifier = ref.read(editorProvider.notifier);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;

    final bool isMobile = MediaQuery.of(context).size.width < 640;
    final bool hasWizard = state.wizardSteps != null;
    final bool isAnalyzing = state.loadingAction == LoadingAction.analyzing;
    final bool isGeneratingMore = state.loadingAction == LoadingAction.generatingMore;
    final bool isSynthesizing = state.loadingAction == LoadingAction.synthesizing;
    final bool hasResult = state.resultText != null;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      drawer: HistoryDrawer(
        onRestore: (prompt) {
           // 恢复逻辑：直接把 prompt 显示到结果区，或者复制
           // 这里简单的处理是：直接更新 State 的 resultText
           // 但 EditorState 是 immutable 的，我们需要在 Notifier 里加一个方法
           // 或者暂时仅仅是复制到剪贴板，或者更新 UI 显示
           // 建议在 EditorNotifier 加一个 restoreResult 方法
           ref.read(editorProvider.notifier).restoreResult(prompt);
           // 滚动到底部
           Future.delayed(const Duration(milliseconds: 300), () => _scrollToKey(_resultAreaKey));
        }
      ),
      bottomNavigationBar: isMobile ? _buildMobileBottomBar(state, theme, lang) : null,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(theme, lang, state, notifier, isMobile),

          SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                      height: (hasWizard || isAnalyzing) ? 40 : MediaQuery.of(context).size.height * 0.25,
                    ),
                    if (!hasWizard && !isAnalyzing) _buildStaticHeader(theme, lang),
                    const SizedBox(height: 32),
                    
                    InputArea(
                      controller: _inputController, 
                      isLoading: state.isLoading, 
                      lang: lang, 
                      onSend: () => _handleSend(notifier)
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Center(
              child: Container(
                key: _wizardListKey,
                constraints: const BoxConstraints(maxWidth: 800),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    if (isAnalyzing)
                      _buildLoadingPlaceholder(theme, AppStrings.get('analyzing', lang)),

                    if (hasWizard) ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.wizardSteps!.length,
                        itemBuilder: (context, index) {
                          return WizardOptionCard(
                            key: ValueKey(state.wizardSteps![index].title),
                            step: state.wizardSteps![index],
                            notifier: notifier,
                            lang: lang,
                            theme: theme,
                          )
                          // ✅ 新增：交错动画，每个卡片延迟 100ms 出现
                          .animate()
                          .fadeIn(duration: 600.ms, delay: (100 * index).ms)
                          .slideX(begin: 0.2, end: 0, curve: Curves.easeOutQuad); 
                        },
                      ),

                      if (isGeneratingMore)
                        _buildLoadingPlaceholder(theme, AppStrings.get('loadingDimensions', lang), key: _bottomLoaderKey),

                      _buildActionButtons(context, lang, state, notifier, theme, isMobile),
                    ],
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Center(
              child: Container(
                key: _resultAreaKey,
                constraints: const BoxConstraints(maxWidth: 800),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    if (isSynthesizing)
                      _buildLoadingPlaceholder(theme, AppStrings.get('synthesizing', lang)),

                    if (hasResult)
                      ResultArea(resultText: state.resultText!, lang: lang),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // === 局部 UI 组件 ===

  BottomAppBar _buildMobileBottomBar(EditorState state, ThemeData theme, String lang) {
    return BottomAppBar(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: state.resultText != null ? () {
                Clipboard.setData(ClipboardData(text: state.resultText!));
                _showGeminiToast(AppStrings.get('copySuccess', lang));
              } : null,
              icon: const Icon(Icons.copy_all_rounded, size: 22),
              label: Text(AppStrings.get('copy', lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
          ),
          const SizedBox(width: 16),
          IconButton.outlined(
            icon: const Icon(Icons.settings_outlined, size: 26),
            tooltip: AppStrings.get('settingsTooltip', lang),
            onPressed: () {
               // 移动端也添加拦截逻辑
               if (state.isLoading) {
                _showGeminiToast("正在输出中，请稍后点击设置");
                return;
              }
              _showSettings();
            },
            style: IconButton.styleFrom(fixedSize: const Size(56, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: BorderSide(color: theme.colorScheme.outline)),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(ThemeData theme, String lang, EditorState state, EditorNotifier notifier, bool isMobile) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: theme.colorScheme.surface.withValues(alpha: _isScrolled ? 0.9 : 0.0),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 24,
      title: Text(AppStrings.get('appTitle', lang), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, letterSpacing: -0.5)),
      centerTitle: false,
      actions: [
        if (!isMobile) ...[
          IconButton(
            icon: Icon(Icons.copy_all_rounded, color: state.resultText != null ? theme.colorScheme.primary : theme.colorScheme.outline),
            tooltip: AppStrings.get('copy', lang),
            onPressed: state.resultText != null ? () {
              Clipboard.setData(ClipboardData(text: state.resultText!));
              _showGeminiToast(AppStrings.get('copySuccess', lang));
            } : null,
            style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppStrings.get('reset', lang),
            onPressed: () {
              if (state.isLoading) {
                _showGeminiToast("正在输出中，请稍后点击重置");
                return;
              }
              _handleReset(notifier);
            },
            style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
          ),
          const SizedBox(width: 8),

          // ... 
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '历史记录',
            onPressed: () {
               if (state.isLoading) return; // 拦截
               Scaffold.of(context).openDrawer(); // 打开抽屉
            },
            style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
          ),
          const SizedBox(width: 8),
          // ... 设置按钮
          
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppStrings.get('settingsTooltip', lang),
            onPressed: () {
              if (state.isLoading) {
                _showGeminiToast("正在输出中，请稍后点击设置");
                return;
              }
              _showSettings();
            },
            style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
          ),
          const SizedBox(width: 24),
        ]
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: AnimatedOpacity(
          opacity: _isScrolled ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
        ),
      ),
    );
  }

  Widget _buildStaticHeader(ThemeData theme, String lang) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(colors: [theme.colorScheme.primary, Colors.blueGrey]).createShader(bounds),
          child: Text(AppStrings.get('appSubtitle', lang), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5), textAlign: TextAlign.center),
        ).animate().fadeIn().slideY(begin: 0.2, end: 0),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, String lang, EditorState state, EditorNotifier notifier, ThemeData theme, bool isMobile) {
    // 状态定义
    final bool isAnalyzing = state.loadingAction == LoadingAction.analyzing;
    final bool isGeneratingMore = state.loadingAction == LoadingAction.generatingMore;
    final bool isSynthesizing = state.loadingAction == LoadingAction.synthesizing;
    
    // 修复点：明确定义 isDisabled，用于禁用辅助按钮
    final bool isDisabled = state.isLoading;

    // 按钮逻辑：合成中显示停止，否则显示生成
    final Widget generateButton = isSynthesizing
        ? FilledButton.icon(
            onPressed: () => notifier.stopGeneration(),
            icon: const SizedBox(
              width: 20, 
              height: 20, 
              child: CircularProgressIndicator(
                color: Colors.white, 
                strokeWidth: 2,
              ),
            ),
            label: const Text("强制停止"), 
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              minimumSize: isMobile ? const Size.fromHeight(56) : null,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          )
        : FilledButton.icon(
            onPressed: (isAnalyzing || isGeneratingMore) ? null : () => _handleSynthesize(notifier),
            icon: const Icon(Icons.auto_awesome),
            label: Text(AppStrings.get('generatePrompt', lang)),
            style: FilledButton.styleFrom(
              minimumSize: isMobile ? const Size.fromHeight(56) : null,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          );

    final Widget actionRow = Row(
      mainAxisAlignment: isMobile ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
      children: [
        TextButton.icon(
          // 使用 isDisabled 禁用按钮
          onPressed: isDisabled ? null : () => notifier.addCustomDimension(),
          icon: const Icon(Icons.edit_note),
          label: Text(AppStrings.get('addCustomField', lang)),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
        ),
        if (!isMobile) const Spacer(),
        if (isMobile) const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: isDisabled ? null : () async {
            try {
              final future = notifier.generateMoreDimensions(_inputController.text);
              Future.delayed(const Duration(milliseconds: 100), () => _scrollToKey(_bottomLoaderKey));
              await future;
            } catch (e) {
              if (mounted) _showGeminiToast(e.toString());
            }
          },
          icon: const Icon(Icons.add),
          label: Text(AppStrings.get('moreOptions', lang)),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), textStyle: const TextStyle(fontSize: 16)),
        ),
        if (!isMobile) const SizedBox(width: 16),
        if (!isMobile) generateButton,
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          actionRow,
          if (isMobile) const SizedBox(height: 16),
          if (isMobile) generateButton,
        ],
      ),
    );
  }

  // 修改 _buildLoadingPlaceholder 方法
  Widget _buildLoadingPlaceholder(ThemeData theme, String text, {Key? key}) {
    // 如果是分析阶段，使用循环文字；其他阶段保持静态
    final bool isAnalyzing = text.contains("分析"); // 简单判断

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 16),
          // ✅ 修改这里
          isAnalyzing 
            ? CyclingLoadingText(baseText: text)
            : Text(text, style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.w500)),
        ],
      ),
    ).animate().fadeIn();
  }
}

// lib/home_screen.dart (添加到文件最底部)

class CyclingLoadingText extends StatefulWidget {
  final String baseText;
  const CyclingLoadingText({super.key, required this.baseText});

  @override
  State<CyclingLoadingText> createState() => _CyclingLoadingTextState();
}

class _CyclingLoadingTextState extends State<CyclingLoadingText> {
  int _index = 0;
  // 模拟 AI 思考的步骤文案
  final List<String> _steps = [
    "正在拆解原始指令...",
    "识别关键决策变量...",
    "设计互斥选项...",
    "构建思维链架构...",
    "优化选项维度...",
  ];
  late final java_async.Timer _timer; // 注意引入 import 'dart:async' as java_async;

  @override
  void initState() {
    super.initState();
    // 每 1.5 秒切换一次文案
    _timer = java_async.Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          _index = (_index + 1) % _steps.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Text(
        "$_index. ${_steps[_index]}", // 显示序号增加真实感
        key: ValueKey<int>(_index),
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary, 
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
    );
  }
}