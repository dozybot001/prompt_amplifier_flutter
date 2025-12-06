import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'state.dart';
import 'app_strings.dart';

// 外部调用的弹窗包装器 (桌面端使用)
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: const SettingsContent(isDialog: true),
      ),
    );
  }
}

// 外部调用的底部弹窗包装器 (移动端使用)
class SettingsBottomSheet extends StatelessWidget {
  const SettingsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 处理键盘遮挡和底部安全区
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部拖拽条
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SettingsContent(isDialog: true), // 复用内容组件
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// 核心设置内容 (可复用：移动端全屏页面 / 桌面端弹窗 / BottomSheet)
class SettingsContent extends ConsumerStatefulWidget {
  final bool isDialog;
  const SettingsContent({super.key, this.isDialog = false});

  @override
  ConsumerState<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends ConsumerState<SettingsContent> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _apiKeyController.text = settings.apiKey;
    _baseUrlController.text = settings.baseUrl;
    _modelController.text = settings.modelName;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标题栏
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.get('settingsTitle', lang),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            // 如果是弹窗模式，显示关闭按钮；如果是 BottomSheet，通常不需要，或者也可以保留
            if (widget.isDialog)
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
          ],
        ),
        const SizedBox(height: 20),

        // 1. 语言选择
        Text(AppStrings.get('language', lang), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'zh', label: Text('中文')),
            ButtonSegment(value: 'en', label: Text('English')),
          ],
          selected: {lang},
          onSelectionChanged: (Set<String> newSelection) {
            ref.read(settingsProvider.notifier).saveSettings(language: newSelection.first);
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStateProperty.all(EdgeInsets.zero),
          ),
        ),
        const SizedBox(height: 16),

        // 2. API Key
        _buildInput(_apiKeyController, 'API Key', AppStrings.get('apiKeyHint', lang), Icons.key, obscure: true),
        const SizedBox(height: 12),

        // 3. Base URL
        _buildInput(_baseUrlController, 'Base URL', AppStrings.get('baseUrlHint', lang), Icons.link),
        const SizedBox(height: 12),

        // 4. Model
        _buildInput(_modelController, 'Model', AppStrings.get('modelHint', lang), Icons.smart_toy),
        const SizedBox(height: 24),

        // 5. 保存按钮
        FilledButton.icon(
          onPressed: () {
            ref.read(settingsProvider.notifier).saveSettings(
              apiKey: _apiKeyController.text,
              baseUrl: _baseUrlController.text,
              modelName: _modelController.text,
            );

            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppStrings.get('saveSuccess', lang),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                backgroundColor: const Color(0xFF303030),
                behavior: SnackBarBehavior.floating,
                width: 250,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                duration: const Duration(seconds: 2),
              ),
            );

            if (widget.isDialog) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.check),
          label: Text(AppStrings.get('save', lang)),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildInput(TextEditingController controller, String label, String hint, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(icon, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}