import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/editor_state.dart';

class PromptPreviewArea extends ConsumerWidget {
  const PromptPreviewArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听 Provider，只要数据一变，这里就会自动重绘
    final promptData = ref.watch(editorProvider);
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3), // 稍微给点背景色区分
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('实时预览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: '复制 Prompt',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: promptData.displayContent));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板')),
                  );
                },
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                promptData.displayContent,
                style: const TextStyle(
                  fontFamily: 'Roboto', // 或者是你的等宽字体
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 真正的功能按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: promptData.isLoading
                  ? null // 加载时禁用按钮
                  : () async {
                try {
                  await ref.read(editorProvider.notifier).amplify();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('放大成功！🚀')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('失败: ${e.toString().replaceAll("Exception:", "")}'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              // 根据状态显示不同图标
              icon: promptData.isLoading
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
              )
                  : const Icon(Icons.auto_awesome),
              label: Text(promptData.isLoading ? '正在施法...' : 'AI 放大 (Amplify)'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}