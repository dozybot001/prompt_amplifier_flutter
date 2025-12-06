import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'state.dart';
import 'app_strings.dart';
import 'settings_dialog.dart';

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
  final GlobalKey _bottomLoaderKey = GlobalKey(); // 新增：用于定位底部加载条

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
          alignment: 0.0, // 0.0 = 顶部对齐, 1.0 = 底部对齐
        );
      } else {
        // 如果 Key 还没渲染出来（例如在列表极底部），尝试直接滚到底
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

  void _showGeminiToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF303030),
        behavior: SnackBarBehavior.floating,
        width: 340, // 稍微加宽以容纳长错误信息
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 3),
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
                    _buildInputArea(theme, lang, state, notifier),
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
                          );
                        },
                      ),

                      // 修改：给 Loading 加上 Key，并确保它在列表下方
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
                      _buildResultArea(theme, lang, state.resultText!),
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

  // === 拆分出的 UI 组件 ===

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
            onPressed: _showSettings,
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
            onPressed: () => _handleReset(notifier),
            style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppStrings.get('settingsTooltip', lang),
            onPressed: _showSettings,
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

  Widget _buildInputArea(ThemeData theme, String lang, EditorState state, EditorNotifier notifier) {
    return Container(
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(28)),
      padding: const EdgeInsets.fromLTRB(24, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              decoration: InputDecoration(hintText: AppStrings.get('inputHint', lang), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 12)),
              style: const TextStyle(fontSize: 18),
              onSubmitted: (_) => _handleSend(notifier),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: state.isLoading ? null : () => _handleSend(notifier),
            icon: state.isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : const Icon(Icons.arrow_upward_rounded, size: 28),
            style: IconButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary, padding: const EdgeInsets.all(12), minimumSize: const Size(56, 56)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String lang, EditorState state, EditorNotifier notifier, ThemeData theme, bool isMobile) {
    final bool isDisabled = state.isLoading;

    final Widget generateButton = FilledButton.icon(
      onPressed: isDisabled ? null : () => _handleSynthesize(notifier),
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
              // 触发生成，并立即滚动到底部的 Loader
              final future = notifier.generateMoreDimensions(_inputController.text);

              // 延迟一小段时间等待 UI 渲染出 Loader，然后滚动
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

  Widget _buildLoadingPlaceholder(ThemeData theme, String text, {Key? key}) {
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
          Text(text, style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.w500)),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildResultArea(ThemeData theme, String lang, String resultText) {
    return Container(
      margin: const EdgeInsets.only(bottom: 48),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.get('finalPromptTitle', lang), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SelectableText(resultText, style: const TextStyle(fontSize: 16, height: 1.6, fontFamily: 'Microsoft YaHei')),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.98, 0.98));
  }
}

class WizardOptionCard extends StatefulWidget {
  final WizardDimension step;
  final EditorNotifier notifier;
  final String lang;
  final ThemeData theme;

  const WizardOptionCard({super.key, required this.step, required this.notifier, required this.lang, required this.theme});

  @override
  State<WizardOptionCard> createState() => _WizardOptionCardState();
}

class _WizardOptionCardState extends State<WizardOptionCard> {
  late TextEditingController _customInputController;

  @override
  void initState() {
    super.initState();
    _customInputController = TextEditingController(text: widget.step.selected);
  }

  @override
  void didUpdateWidget(covariant WizardOptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.step.selected == null || widget.step.selected!.isEmpty) {
      if (_customInputController.text.isNotEmpty) _customInputController.clear();
    }
  }

  @override
  void dispose() {
    _customInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final step = widget.step;
    final bool isCustomInput = step.selected != null && step.selected!.isNotEmpty && !step.options.contains(step.selected);

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(step.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.outline),
                  tooltip: AppStrings.get('deleteDimension', widget.lang),
                  onPressed: () => widget.notifier.removeDimension(step),
                  visualDensity: VisualDensity.compact,
                )
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: step.options.map((opt) {
                final isSelected = step.selected == opt;
                return FilterChip(
                  label: Text(opt),
                  selected: isSelected,
                  onSelected: (_) {
                    _customInputController.clear();
                    widget.notifier.selectWizardOption(step, opt);
                  },
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  selectedColor: theme.colorScheme.surfaceContainerHighest,
                  labelStyle: TextStyle(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline, width: isSelected ? 1.5 : 1)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _customInputController,
              onChanged: (val) => widget.notifier.selectWizardOption(step, val),
              decoration: InputDecoration(
                hintText: AppStrings.get('customOptionHint', widget.lang),
                hintStyle: TextStyle(color: theme.colorScheme.outline),
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: isCustomInput ? OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1)) : null,
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}